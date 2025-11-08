import 'dart:math';
import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:lottie/lottie.dart';
import 'package:planit_schedule_manager/screens/project50_screen.dart';
import 'package:planit_schedule_manager/screens/add_schedule_screen.dart';
import 'package:planit_schedule_manager/services/google_calendar_service.dart';
import 'package:planit_schedule_manager/widgets/tasks_display_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/screens/task_details_screen.dart';
import 'package:intl/intl.dart';

enum CalendarViewMode {
  timeline,
  monthly,
  monthlyWithDetails,
  weekly,
}

class CalendarScreen extends StatefulWidget {
  @override
  _CalendarScreenState createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with TickerProviderStateMixin {
  final ScheduleService _scheduleService = ScheduleService();
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<Task> _selectedDayTasks = [];
  Map<DateTime, List<Task>> _eventsMap = {};
  late TabController _tabController;
  CalendarViewMode _calendarViewMode = CalendarViewMode.monthly;

  // Animation controller for the dropdown panel
  late AnimationController _dropdownController;
  late Animation<double> _dropdownAnimation;
  bool _isDropdownVisible = false;

  ScrollController? _horizontalTimelineScrollController;
  bool _hasHoriScrolledToCurrentTime = false;

  ScrollController? _verticalTimelineScrollController;
  bool _hasVerScrolledToCurrentTime = false;

  final GoogleCalendarService _googleCalendarService = GoogleCalendarService();
  List<calendar.Event> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _tabController = TabController(length: 2, vsync: this);
    // _handleSignIn();
    // _fetchEvents();
    _loadCalendarViewPreference();
    _loadAllTasks();

    _horizontalTimelineScrollController = ScrollController();
    _verticalTimelineScrollController = ScrollController();

    _dropdownController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _dropdownAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _dropdownController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _dropdownController.dispose();
    _horizontalTimelineScrollController!.dispose();
    _verticalTimelineScrollController!.dispose();

    super.dispose();
  }

  // Toggle dropdown visibility
  void _toggleDropdown() {
    if (_isDropdownVisible) {
      _dropdownController.reverse().then((value) {
        setState(() {
          _isDropdownVisible = false;
        });
      });
    } else {
      setState(() {
        _isDropdownVisible = true;
      });
      _dropdownController.forward();
    }
  }

  // Change calendar view mode and close dropdown
  void _changeCalendarViewMode(CalendarViewMode mode) {
    _dropdownController.reverse().then((value) {
      setState(() {
        _calendarViewMode = mode;
        _selectedDay = DateTime.now();
        _isDropdownVisible = false;
      });
      _saveCalendarViewPreference();
    });
  }

  Future<void> _loadAllTasks() async {
    final tasksStream = _scheduleService.getSchedules();
    tasksStream.listen((tasks) {
      setState(() {
        _eventsMap = _groupTasksByDay(tasks);
        _loadTasksForSelectedDay();
      });
    });
  }

  Map<DateTime, List<Task>> _groupTasksByDay(List<Task> tasks) {
    Map<DateTime, List<Task>> eventsMap = {};
    for (var task in tasks) {
      final day = DateTime(task.time.year, task.time.month, task.time.day);
      if (!eventsMap.containsKey(day)) {
        eventsMap[day] = [];
      }
      eventsMap[day]!.add(task);
    }
    return eventsMap;
  }

  Future<void> _loadTasksForSelectedDay() async {
    if (_selectedDay != null) {
      final tasks = await _scheduleService.getSchedulesForDate(_selectedDay!);
      setState(() {
        _selectedDayTasks = tasks;
      });
    }
  }

  Future<void> _fetchEvents() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final events = await _googleCalendarService.getEvents(
        startTime: DateTime(now.year, now.month, 1),
        endTime: DateTime(now.year, now.month + 3, 0),
      );

      setState(() => _events = events);

      // Get existing tasks and group them by day
      final tasksStream = _scheduleService.getSchedules();
      List<Task> existingTasks = await tasksStream.first;
      final Map<DateTime, List<Task>> tasksByDay =
          _groupTasksByDay(existingTasks);

      int addedCount = 0;

      // Process each Google Calendar event
      for (var event in events) {
        final eventTime = event.start?.dateTime ?? DateTime.now();
        final eventDay =
            DateTime(eventTime.year, eventTime.month, eventTime.day);

        // Get tasks for the event's day (or empty list if none)
        final tasksForDay = tasksByDay[eventDay] ?? [];

        // Check for duplicates only within the same day
        bool isDuplicate =
            tasksForDay.any((task) => _isEventDuplicate(task, event));

        if (!isDuplicate) {
          // Add to database if not a duplicate
          await _scheduleService.addSchedule(
            title: event.summary ?? 'Untitled Event',
            category: 'Google Calendar',
            url: event.htmlLink ?? '',
            placeURL: event.location ?? '',
            time: eventTime,
            subtasks: [],
            priority: 'Medium',
            isRepeated: false,
            repeatInterval: '',
            repeatedIntervalTime: 0,
          );
          addedCount++;
        }
      }

      // Show success message with count of added events
      if (addedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Synced $addedCount new events from Google Calendar')),
        );
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error fetching events: $e')),
      // );
    }
    setState(() => _isLoading = false);
  }

// More comprehensive duplicate checking method
  bool _isEventDuplicate(Task existingTask, calendar.Event googleEvent) {
    // Check multiple criteria to determine if an event is a duplicate
    return
        // Exact match on title and time
        existingTask.title == (googleEvent.summary ?? 'Untitled Event') &&
                _isSameDateTime(existingTask.time,
                    googleEvent.start?.dateTime ?? DateTime.now()) ||

            // Optional: Check for very close time matches (within 15 minutes)
            existingTask.title == (googleEvent.summary ?? 'Untitled Event') &&
                _isTimeSimilar(existingTask.time,
                    googleEvent.start?.dateTime ?? DateTime.now(),
                    toleranceMinutes: 15) ||

            // Optional: Check for exact location match if applicable
            (googleEvent.location != null &&
                existingTask.placeURL == googleEvent.location);
  }

// Enhanced time comparison with tolerance
  bool _isTimeSimilar(DateTime a, DateTime b, {int toleranceMinutes = 15}) {
    return a.difference(b).abs() <= Duration(minutes: toleranceMinutes);
  }

  // Helper method to compare DateTime objects ignoring milliseconds and microseconds
  bool _isSameDateTime(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day &&
        a.hour == b.hour &&
        a.minute == b.minute;
  }

  Future<void> _handleSignIn() async {
    setState(() => _isLoading = true);
    try {
      bool success = await _googleCalendarService.signIn();
      if (success) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Signed in successfully')),
        // );
        _fetchEvents();
        _loadAllTasks();
      } else {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Sign-in failed')),
        // );
        print('Sign in Failed');
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
      print('Error: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveCalendarViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('calendar_view_mode', _calendarViewMode.index);
  }

  // Load calendar view mode preference
  Future<void> _loadCalendarViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getInt('calendar_view_mode');

    if (savedMode != null && savedMode < CalendarViewMode.values.length) {
      setState(() {
        _calendarViewMode = CalendarViewMode.values[savedMode];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isDropdownVisible) {
          setState(() {
            _isDropdownVisible = false;
            _dropdownController.reverse();
          });
        }
      },
      child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent, // Make AppBar transparent
            elevation: 0, // Remove shadow
            flexibleSpace: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: 10, sigmaY: 10), // Frosted glass effect
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        Colors.white.withOpacity(0.2), // Subtle white overlay
                    border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withOpacity(0.3), width: 1.0),
                    ),
                  ),
                ),
              ),
            ),
            title: Row(
              children: [
                Image.asset(
                  'assets/images/tree.png', // Adding tree icon to title
                  height: 24,
                  width: 24,
                ),
                SizedBox(width: 8),
                Text(
                  "PlanIT Calendar",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800, // Nature-themed text color
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3.0,
                        color: Colors.black.withOpacity(0.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            iconTheme: IconThemeData(
              color:
                  Colors.green.shade700, // Match icon color to the nature theme
            ),
            actions: [
              IconButton(
                onPressed: () {
                  _handleSignIn();
                },
                icon: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _googleCalendarService.isSignedIn
                            ? Colors.green
                            : Colors.grey,
                        width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3.0),
                    child: ClipOval(
                      child: Image.asset('assets/images/google_signin.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: _getCalendarViewIcon(),
                tooltip: 'Change View',
                onPressed: _toggleDropdown,
              ),
              IconButton(
                icon: Icon(Icons.search),
                onPressed: () {
                  showSearch(
                    context: context,
                    delegate: TaskSearchDelegate(_eventsMap),
                  );
                },
              ),
            ],
          ),
          body: Stack(
            children: [
              // Background image
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/background.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Semi-transparent overlay
              Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white.withOpacity(0.5),
              ),
              // Content container
              Container(
                width: double.infinity,
                height: double.infinity,
                child: Stack(
                  children: [
                    _buildCalendarView(),
                    // Animated dropdown panel
                    AnimatedBuilder(
                      animation: _dropdownAnimation,
                      builder: (context, child) {
                        return _isDropdownVisible
                            ? _buildViewModeDropdown()
                            : SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ],
          )),
    );
  }

  Widget _buildViewModeDropdown() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(_dropdownController),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(15),
            bottomRight: Radius.circular(15),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: 10, sigmaY: 10), // Match app bar's blur effect
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white
                    .withOpacity(0.2), // Match app bar's background color
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8.0,
                    spreadRadius: 0.0,
                    offset: Offset(0.0, 2.0),
                  ),
                ],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(15),
                  bottomRight: Radius.circular(15),
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.0,
                ),
              ),
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildViewModeOption(
                        icon: Icons.timeline,
                        title: 'Timeline',
                        isSelected:
                            _calendarViewMode == CalendarViewMode.timeline,
                        onTap: () =>
                            _changeCalendarViewMode(CalendarViewMode.timeline),
                      ),
                      _buildViewModeOption(
                        icon: Icons.list_alt,
                        title: 'List',
                        isSelected:
                            _calendarViewMode == CalendarViewMode.monthly,
                        onTap: () =>
                            _changeCalendarViewMode(CalendarViewMode.monthly),
                      ),
                      _buildViewModeOption(
                        icon: Icons.calendar_month,
                        title: 'Month',
                        isSelected: _calendarViewMode ==
                            CalendarViewMode.monthlyWithDetails,
                        onTap: () => _changeCalendarViewMode(
                            CalendarViewMode.monthlyWithDetails),
                      ),
                      _buildViewModeOption(
                        icon: Icons.view_week,
                        title: 'Week',
                        isSelected:
                            _calendarViewMode == CalendarViewMode.weekly,
                        onTap: () =>
                            _changeCalendarViewMode(CalendarViewMode.weekly),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to build individual view mode option
  Widget _buildViewModeOption({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.green.shade800.withOpacity(
                  0.2) // Nature-themed selection color (more subtle)
              : Colors.green.shade50.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.green.shade700
                : Colors.green.shade700.withOpacity(0.5),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Colors.green.shade700
                  : Colors.green.shade900.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.green.shade700
                    : Colors.green.shade900.withOpacity(0.8),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to get the appropriate icon for current view mode
  Icon _getCalendarViewIcon() {
    switch (_calendarViewMode) {
      case CalendarViewMode.timeline:
        return Icon(Icons.timeline);
      case CalendarViewMode.monthly:
        return Icon(Icons.list_alt);
      case CalendarViewMode.monthlyWithDetails:
        return Icon(Icons.calendar_month);
      case CalendarViewMode.weekly:
        return Icon(Icons.view_week);
    }
  }

  Widget _buildCalendarView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        switch (_calendarViewMode) {
          case CalendarViewMode.timeline:
            return SizedBox.expand(
              child: _buildTimelineCalendar(),
            );
          case CalendarViewMode.monthly:
            return Column(
              children: [
                _buildCalendar(),
                Expanded(child: _buildTaskList()),
                SizedBox(
                  height: 60,
                ),
              ],
            );
          case CalendarViewMode.monthlyWithDetails:
            return SizedBox.expand(
              child: _buildMonthlyCalendar(),
            );
          case CalendarViewMode.weekly:
            return SizedBox.expand(
              child: _buildHorizontalTimelineCalendar(),
            );
        }
      },
    );
  }

  // Get the start of the current week
  DateTime get _currentWeekStart {
    final now = DateTime.now();
    return now.subtract(Duration(days: now.weekday - 1));
  }

  void _showAddPanel() {
    AddSchedulePanel.show(
      context,
      (title, category, url, placeURL, time, subtasks, priority, isRepeated,
          repeatInterval, repeatedIntervalTime, files) async {
        try {
          print("Selected Day:" + _selectedDay.toString());
          // Add the schedule using your service
          await _scheduleService.addSchedule(
            title: title,
            category: category,
            url: url,
            placeURL: placeURL,
            time: time,
            subtasks: subtasks,
            priority: priority,
            isRepeated: isRepeated,
            repeatInterval: repeatInterval,
            repeatedIntervalTime: repeatedIntervalTime,
            files: files,
          );
        } catch (e) {
          print(e.toString());
        }
      },
      initialDate: _selectedDay,
    );
  }

  Widget _buildCalendar() {
    return Stack(
      children: [
        Container(
          height: 400,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              color: Colors.white.withOpacity(0.5),
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  // Calendar Header with Gradient
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      // gradient: LinearGradient(
                      //   colors: [
                      //     Theme.of(context).primaryColor.withOpacity(0.1),
                      //     Colors.transparent,
                      //   ],
                      //   begin: Alignment.topCenter,
                      //   end: Alignment.bottomCenter,
                      // ),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      rowHeight: 42,
                      daysOfWeekHeight: 20,
                      calendarFormat: CalendarFormat.month,
                      eventLoader: (day) {
                        final dayWithoutTime =
                            DateTime(day.year, day.month, day.day);
                        return _eventsMap[dayWithoutTime] ?? [];
                      },
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        if (!isSameDay(_selectedDay, selectedDay)) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          _loadTasksForSelectedDay();
                        }
                      },
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: Colors.blue.shade700,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 4,
                        markersAlignment: Alignment.bottomCenter,
                        markersAutoAligned: true,
                        weekendTextStyle: TextStyle(color: Colors.red.shade300),
                      ),
                      headerStyle: HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                          fontSize: 20.0,
                          fontWeight: FontWeight.bold,
                        ),
                        leftChevronIcon: Icon(Icons.chevron_left, size: 28),
                        rightChevronIcon: Icon(Icons.chevron_right, size: 28),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Theme.of(context)
                                  .primaryColor
                                  .withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        // Custom day builder to add gesture detection
                        defaultBuilder: (context, day, focusedDay) {
                          return GestureDetector(
                            onLongPress: () {
                              if (isSameDay(_selectedDay, day)) {
                                _showAddPanel();
                              } else {
                                // First select the day, then show panel
                                setState(() {
                                  _selectedDay = day;
                                  _focusedDay = day;
                                });
                                _loadTasksForSelectedDay();
                                _showAddPanel();
                              }
                            },
                            child: Center(
                              child: Text(
                                '${day.day}',
                                style: isSameDay(day, DateTime.now())
                                    ? TextStyle(fontWeight: FontWeight.bold)
                                    : null,
                              ),
                            ),
                          );
                        },
                        selectedBuilder: (context, day, focusedDay) {
                          return GestureDetector(
                            onLongPress: () {
                              _showAddPanel();
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        todayBuilder: (context, day, focusedDay) {
                          return GestureDetector(
                            onLongPress: () {
                              if (isSameDay(_selectedDay, day)) {
                                _showAddPanel();
                              } else {
                                setState(() {
                                  _selectedDay = day;
                                  _focusedDay = day;
                                });
                                _loadTasksForSelectedDay();
                                _showAddPanel();
                              }
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Decorative Image
        Positioned(
          bottom: 2,
          right: 2,
          child: IgnorePointer(
            child: Image.asset(
              'assets/images/tree.png',
              width: 240,
              height: 240,
              opacity: AlwaysStoppedAnimation(0.25),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCalendar() {
    final today = DateTime.now();
    final currentHour = today.hour; // Get the current hour
    final weekStart = _selectedDay != null
        ? DateTime(_selectedDay!.year, _selectedDay!.month,
            _selectedDay!.day - _selectedDay!.weekday + 1)
        : _currentWeekStart;

    // Create a ScrollController for the timeline

    // Use post-frame callback to scroll to the current time after the widget is built
    if (!_hasVerScrolledToCurrentTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Calculate scroll position based on current hour
        // Each hour slot is approximately 70px tall
        final scrollPosition = currentHour * 70.0;

        // Scroll to the position with some offset to center it in the viewport
        _verticalTimelineScrollController!.animateTo(
          scrollPosition -
              150, // Subtract some pixels to position the current time in the visible area
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _hasVerScrolledToCurrentTime = true;
      });
    }

    // Get tasks for the visible week
    Map<DateTime, List<dynamic>> weekTasks = {};
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayWithoutTime = DateTime(day.year, day.month, day.day);
      weekTasks[dayWithoutTime] = _eventsMap[dayWithoutTime] ?? [];
    }

    // Find the maximum number of tasks in a day for heatmap scaling
    int maxTaskCount = 0;
    weekTasks.forEach((day, tasks) {
      if (tasks.length > maxTaskCount) {
        maxTaskCount = tasks.length;
      }
    });

    // Create a getter for color intensity based on task count
    Color getHeatmapColor(int taskCount) {
      if (taskCount == 0) return Colors.transparent;

      // Use a more distinct color gradient from light green (free) to deep red (busy)
      final double intensity =
          taskCount / (maxTaskCount > 0 ? maxTaskCount : 1);

      if (intensity < 0.25) {
        return Colors.green[100]!;
      } else if (intensity < 0.5) {
        return Colors.yellow[300]!;
      } else if (intensity < 0.75) {
        return Colors.orange[700]!;
      } else {
        return Colors.red[400]!;
      }
    }

    IconData getTaskDensityIcon(int taskCount) {
      if (taskCount == 0) return Icons.check_circle_outline;

      final double intensity =
          taskCount / (maxTaskCount > 0 ? maxTaskCount : 1);

      if (intensity < 0.25) {
        return Icons.sentiment_very_satisfied; // Very free
      } else if (intensity < 0.5) {
        return Icons.sentiment_satisfied; // Somewhat busy
      } else if (intensity < 0.75) {
        return Icons.sentiment_neutral; // Busy
      } else {
        return Icons.sentiment_very_dissatisfied; // Very busy
      }
    }

    return Column(
      children: [
        // Week selector with arrows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDay = weekStart.subtract(Duration(days: 7));
                    _loadTasksForSelectedDay();
                  });
                },
              ),
              GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  _selectedDay = DateTime(now.year, now.month, now.day);
                  _loadTasksForSelectedDay();
                },
                child: Text(
                  '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekStart.add(Duration(days: 6)))}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedDay = weekStart.add(Duration(days: 7));
                    _loadTasksForSelectedDay();
                  });
                },
              ),
            ],
          ),
        ),

        // Color legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                  Colors.green[100]!, Icons.sentiment_very_satisfied, "Free"),
              SizedBox(width: 8),
              _buildLegendItem(
                  Colors.yellow[200]!, Icons.sentiment_satisfied, "Light"),
              SizedBox(width: 8),
              _buildLegendItem(
                  Colors.orange[300]!, Icons.sentiment_neutral, "Busy"),
              SizedBox(width: 8),
              _buildLegendItem(Colors.red[400]!,
                  Icons.sentiment_very_dissatisfied, "Packed"),
            ],
          ),
        ),

        // Enhanced weekday headers with heatmap
        Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
          ),
          child: Row(
            children: List.generate(7, (dayIndex) {
              final day = weekStart.add(Duration(days: dayIndex));
              final dayWithoutTime = DateTime(day.year, day.month, day.day);
              final taskCount = weekTasks[dayWithoutTime]?.length ?? 0;

              final isToday = day.year == today.year &&
                  day.month == today.month &&
                  day.day == today.day;
              final isSelected = _selectedDay != null &&
                  day.year == _selectedDay!.year &&
                  day.month == _selectedDay!.month &&
                  day.day == _selectedDay!.day;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDay = day;
                      _loadTasksForSelectedDay();
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).primaryColor.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(
                          DateFormat('E')
                              .format(day), // Full weekday abbreviation
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            // Heatmap background
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: getHeatmapColor(taskCount),
                              ),
                            ),
                            // Day number circle
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? Theme.of(context).primaryColor
                                    : isToday
                                        ? Colors.grey[100]
                                        : Colors.transparent,
                                border: isToday && !isSelected
                                    ? Border.all(
                                        color: Theme.of(context).primaryColor,
                                        width: 2)
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : null,
                                    fontWeight: isToday || isSelected
                                        ? FontWeight.bold
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Task count with icon
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              getTaskDensityIcon(taskCount),
                              size: 14,
                              color: taskCount > 0
                                  ? getHeatmapColor(taskCount)
                                  : Colors.grey[400],
                            ),
                            SizedBox(width: 2),
                            Text(
                              '$taskCount',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        // Timeline View (24 hours)
        Expanded(
          child: ListView.builder(
            controller:
                _verticalTimelineScrollController, // Add the controller here
            padding: EdgeInsets.symmetric(vertical: 8),
            itemCount: 24, // Full 24 hour slots
            itemBuilder: (context, index) {
              final hour = index; // Starting from 12 AM (0)
              final timeLabel = hour == 0
                  ? '12 AM'
                  : hour < 12
                      ? '$hour AM'
                      : hour == 12
                          ? '12 PM'
                          : '${hour - 12} PM';

              // Get tasks for this hour
              final tasksAtHour = _selectedDayTasks.where((task) {
                final taskTime = task.time;
                return taskTime != null && taskTime.hour == hour;
              }).toList();

              // Check if this is the current hour
              final isCurrentHour = hour == currentHour;

              // Create a DateTime for this hour slot on the selected day
              final slotDateTime = DateTime(
                _selectedDay?.year ?? DateTime.now().year,
                _selectedDay?.month ?? DateTime.now().month,
                _selectedDay?.day ?? DateTime.now().day,
                hour,
                0,
              );

              // Determine if this is today and current hour for highlighting
              final isSelectedDayToday = _selectedDay != null &&
                  _selectedDay!.year == today.year &&
                  _selectedDay!.month == today.month &&
                  _selectedDay!.day == today.day;
              final highlightCurrentHour = isSelectedDayToday && isCurrentHour;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time indicator with current time highlight
                  SizedBox(
                    width: 60,
                    child: Padding(
                      padding: EdgeInsets.only(right: 8, top: 10),
                      child: Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCurrentHour || hour == 0 || hour == 12
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isCurrentHour
                              ? Theme.of(context).primaryColor
                              : Colors.grey[700],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ),
                  // Time slot with line - highlighted for current hour
                  Container(
                    width: 20,
                    height: 70,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 9,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 2,
                            color: isCurrentHour
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.7)
                                : Colors.grey[300],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 10,
                          child: Container(
                            width: 8,
                            height: 2,
                            color: isCurrentHour
                                ? Theme.of(context).primaryColor
                                : Colors.grey[400],
                          ),
                        ),
                        // Current time indicator dot
                        if (isCurrentHour)
                          Positioned(
                            left: 5,
                            top: 10,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Theme.of(context).primaryColor,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Task slots
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          // Background for time slot
                          Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: highlightCurrentHour
                                  ? Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.05)
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(
                                  color: highlightCurrentHour
                                      ? Theme.of(context)
                                          .primaryColor
                                          .withOpacity(0.3)
                                      : Colors.grey[200]!,
                                ),
                              ),
                            ),
                          ),
                          // Empty slot or tasks
                          if (tasksAtHour.isEmpty)
                            // DragTarget for empty slots
                            DragTarget<Map<String, dynamic>>(
                              builder: (context, candidateData, rejectedData) {
                                return Container(
                                  height: 50,
                                  margin: EdgeInsets.only(top: 10, bottom: 10),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        // Create a time for the add panel
                                        final taskDate =
                                            _selectedDay ?? DateTime.now();
                                        final taskTime = DateTime(
                                            taskDate.year,
                                            taskDate.month,
                                            taskDate.day,
                                            hour,
                                            0);
                                        _selectedDay = taskTime;
                                      });
                                      _showAddPanel();
                                    },
                                    splashColor: Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: EdgeInsets.all(8),
                                      child: DottedBorder(
                                        borderType: BorderType.RRect,
                                        radius: Radius.circular(4),
                                        dashPattern: [4, 4],
                                        color: candidateData.isNotEmpty
                                            ? Theme.of(context).primaryColor
                                            : highlightCurrentHour
                                                ? Theme.of(context)
                                                    .primaryColor
                                                    .withOpacity(0.5)
                                                : Colors.grey[400]!,
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                candidateData.isNotEmpty
                                                    ? Icons.add_task
                                                    : Icons.add_circle_outline,
                                                size: 16,
                                                color: candidateData.isNotEmpty
                                                    ? Theme.of(context)
                                                        .primaryColor
                                                    : highlightCurrentHour
                                                        ? Theme.of(context)
                                                            .primaryColor
                                                        : Colors.grey[500],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                candidateData.isNotEmpty
                                                    ? "Drop to Add Here"
                                                    : "Add Task",
                                                style: TextStyle(
                                                  color: candidateData
                                                          .isNotEmpty
                                                      ? Theme.of(context)
                                                          .primaryColor
                                                      : highlightCurrentHour
                                                          ? Theme.of(context)
                                                              .primaryColor
                                                          : Colors.grey[500],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onAccept: (dragData) async {
                                // When a task is dropped in an empty slot
                                final taskId = dragData['id'];
                                final newDateTime = DateTime(
                                  slotDateTime.year,
                                  slotDateTime.month,
                                  slotDateTime.day,
                                  slotDateTime.hour,
                                  0,
                                );

                                try {
                                  // Update the task time
                                  await _scheduleService.updateTaskTime(
                                    taskId: taskId,
                                    newDateTime: newDateTime,
                                  );

                                  // Refresh the tasks
                                  setState(() {
                                    _loadTasksForSelectedDay();
                                  });

                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Task moved to $timeLabel'),
                                      duration: Duration(seconds: 2),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } catch (e) {
                                  // Show error message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to move task: $e'),
                                      duration: Duration(seconds: 2),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            )
                          else
                            // Column of draggable tasks
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: tasksAtHour.map((task) {
                                // Determine category color
                                Color categoryColor = task.category == 'Work'
                                    ? Colors.blue
                                    : task.category == 'Personal'
                                        ? Colors.green
                                        : Colors.orange;

                                Color priorityColor = task.priority == "High"
                                    ? Colors.red
                                    : task.priority == "Medium"
                                        ? Colors.orange
                                        : Colors.green;

                                // Create a draggable task item
                                return LongPressDraggable<Map<String, dynamic>>(
                                  // Data that will be passed when the task is dropped
                                  data: {
                                    'id': task.id,
                                    'title': task.title,
                                    'category': task.category,
                                    'priority': task.priority,
                                    'originalTime': task.time,
                                  },
                                  // What to display while dragging
                                  feedback: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: MediaQuery.of(context).size.width *
                                          0.8,
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: priorityColor.withOpacity(0.1),
                                        border: Border(
                                          left: BorderSide(
                                            color: priorityColor,
                                            width: 4,
                                          ),
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.access_time,
                                                size: 12,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                _formatTime(task.time),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Visual feedback during drag
                                  childWhenDragging: Opacity(
                                    opacity: 0.5,
                                    child: _buildTaskItem(
                                        task, priorityColor, categoryColor),
                                  ),
                                  // Original widget
                                  child: DragTarget<Map<String, dynamic>>(
                                    builder:
                                        (context, candidateData, rejectedData) {
                                      return _buildTaskItem(
                                        task,
                                        priorityColor,
                                        categoryColor,
                                        isTargeted: candidateData.isNotEmpty,
                                      );
                                    },
                                    onAccept: (dragData) async {
                                      // Only process if this is a different task
                                      if (dragData['id'] != task.id) {
                                        final taskId = dragData['id'];
                                        // Use the same time as this task
                                        final newDateTime = task.time;

                                        try {
                                          // Update the task time
                                          await _scheduleService.updateTaskTime(
                                            taskId: taskId,
                                            newDateTime: newDateTime,
                                          );

                                          // Refresh the tasks
                                          setState(() {
                                            _loadTasksForSelectedDay();
                                          });

                                          // Show success message
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Task moved to ${_formatTime(newDateTime)}'),
                                              duration: Duration(seconds: 2),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                        } catch (e) {
                                          // Show error message
                                          // ScaffoldMessenger.of(context).showSnackBar(
                                          //   SnackBar(
                                          //     content: Text('Failed to move task: $e'),
                                          //     duration: Duration(seconds: 2),
                                          //     backgroundColor: Colors.red,
                                          //   ),
                                          // );
                                        }
                                      }
                                    },
                                  ),
                                  onDragStarted: () {
                                    // Haptic feedback when drag starts
                                    HapticFeedback.heavyImpact();
                                  },
                                  onDragEnd: (details) {
                                    HapticFeedback.heavyImpact();
                                    // Handle case when the drag ends outside a valid target
                                    if (!details.wasAccepted) {
                                      // Optionally show a message
                                      // ScaffoldMessenger.of(context)
                                      //     .showSnackBar(
                                      //   SnackBar(
                                      //     content:
                                      //         Text('Drop in a valid time slot'),
                                      //     duration: Duration(seconds: 1),
                                      //   ),
                                      // );
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        SizedBox(
          height: 50,
        ),
      ],
    );
  }

  Widget _buildHorizontalTimelineCalendar() {
    final today = DateTime.now();
    final currentHour = today.hour; // Get the current hour
    final weekStart = _selectedDay != null
        ? DateTime(_selectedDay!.year, _selectedDay!.month,
            _selectedDay!.day - _selectedDay!.weekday + 1)
        : _currentWeekStart;

    // Create a ScrollController

    // Use post-frame callback to scroll to the current time after the widget is built
    if (!_hasHoriScrolledToCurrentTime) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Calculate scroll position based on current hour
        // Each hour slot is 80px tall, so multiply by current hour
        final scrollPosition = currentHour * 80.0;

        // Scroll to the position with some offset to center it in the viewport
        _horizontalTimelineScrollController!.animateTo(
          scrollPosition -
              120, // Subtract some pixels to position the current time in the visible area
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _hasHoriScrolledToCurrentTime = true;
      });
    }

    // Get tasks for the visible week
    Map<DateTime, List<dynamic>> weekTasks = {};
    for (int i = 0; i < 7; i++) {
      final day = weekStart.add(Duration(days: i));
      final dayWithoutTime = DateTime(day.year, day.month, day.day);
      weekTasks[dayWithoutTime] = _eventsMap[dayWithoutTime] ?? [];
    }

    // Find the maximum number of tasks in a day for heatmap scaling
    int maxTaskCount = 0;
    weekTasks.forEach((day, tasks) {
      if (tasks.length > maxTaskCount) {
        maxTaskCount = tasks.length;
      }
    });

    // Create a getter for color intensity based on task count
    Color getHeatmapColor(int taskCount) {
      if (taskCount == 0) return Colors.transparent;

      final double intensity =
          taskCount / (maxTaskCount > 0 ? maxTaskCount : 1);

      if (intensity < 0.25) {
        return Colors.green[100]!;
      } else if (intensity < 0.5) {
        return Colors.yellow[300]!;
      } else if (intensity < 0.75) {
        return Colors.orange[700]!;
      } else {
        return Colors.red[400]!;
      }
    }

    // Function to highlight the current time slot
    bool isCurrentTimeSlot(int hour) {
      return hour == currentHour;
    }

    return Column(
      children: [
        // Week selector with arrows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left),
                onPressed: () {
                  setState(() {
                    _selectedDay = weekStart.subtract(Duration(days: 7));
                    _loadTasksForSelectedDay();
                  });
                },
              ),
              GestureDetector(
                onTap: () {
                  final now = DateTime.now();
                  _selectedDay = DateTime(now.year, now.month, now.day);
                  _loadTasksForSelectedDay();
                },
                child: Text(
                  '${DateFormat('MMM d').format(weekStart)} - ${DateFormat('MMM d').format(weekStart.add(Duration(days: 6)))}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right),
                onPressed: () {
                  setState(() {
                    _selectedDay = weekStart.add(Duration(days: 7));
                    _loadTasksForSelectedDay();
                  });
                },
              ),
            ],
          ),
        ),

        // Color legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                  Colors.green[100]!, Icons.sentiment_very_satisfied, "Free"),
              SizedBox(width: 8),
              _buildLegendItem(
                  Colors.yellow[200]!, Icons.sentiment_satisfied, "Light"),
              SizedBox(width: 8),
              _buildLegendItem(
                  Colors.orange[300]!, Icons.sentiment_neutral, "Busy"),
              SizedBox(width: 8),
              _buildLegendItem(Colors.red[400]!,
                  Icons.sentiment_very_dissatisfied, "Packed"),
            ],
          ),
        ),

        // Day headers at the top (fixed position)
        Container(
          height: 80,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            color:
                Colors.white.withOpacity(0.5), // Ensure headers have background
          ),
          child: Row(
            children: [
              // Empty space for time column
              SizedBox(width: 50),
              // Day headers
              Expanded(
                child: Row(
                  children: List.generate(7, (dayIndex) {
                    final day = weekStart.add(Duration(days: dayIndex));
                    final dayWithoutTime =
                        DateTime(day.year, day.month, day.day);
                    final taskCount = weekTasks[dayWithoutTime]?.length ?? 0;

                    final isToday = day.year == today.year &&
                        day.month == today.month &&
                        day.day == today.day;
                    final isSelected = _selectedDay != null &&
                        day.year == _selectedDay!.year &&
                        day.month == _selectedDay!.month &&
                        day.day == _selectedDay!.day;

                    return Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedDay = day;
                            _loadTasksForSelectedDay();
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.1)
                                : isToday
                                    ? Colors.blue.withOpacity(0.05)
                                    : Colors.transparent,
                            border: Border(
                              left: BorderSide(color: Colors.grey[200]!),
                              right: dayIndex == 6
                                  ? BorderSide(color: Colors.grey[200]!)
                                  : BorderSide.none,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('E').format(day),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isToday
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                              SizedBox(height: 2),
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : isToday
                                          ? Colors.white
                                          : Colors.transparent,
                                  border: isToday && !isSelected
                                      ? Border.all(
                                          color: Theme.of(context).primaryColor,
                                          width: 1.5)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : null,
                                      fontWeight: isToday || isSelected
                                          ? FontWeight.bold
                                          : null,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 2),
                              Container(
                                width: 20,
                                height: 6,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: getHeatmapColor(taskCount),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),

        // Scrollable time slots and tasks
        Expanded(
          child: SingleChildScrollView(
            controller:
                _horizontalTimelineScrollController, // Add controller here
            child: SizedBox(
              // Calculate the height based on the number of hours (24 * 80)
              height: 24 * 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time labels column
                  SizedBox(
                    width: 50,
                    child: Column(
                      children: List.generate(24, (hourIndex) {
                        final hour = hourIndex;
                        final timeLabel = hour == 0
                            ? '12 AM'
                            : hour < 12
                                ? '$hour AM'
                                : hour == 12
                                    ? '12 PM'
                                    : '${hour - 12} PM';

                        // Highlight current hour time label
                        final isCurrentHour = hour == currentHour;

                        return Container(
                          height: 80,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                            color: isCurrentHour
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                          child: Text(
                            timeLabel,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isCurrentHour || hour == 0 || hour == 12
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                              color: isCurrentHour
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[700],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1,
                    color: Colors.grey[300],
                  ),

                  // Days columns
                  Expanded(
                    child: Column(
                      children: List.generate(24, (hourIndex) {
                        final hour = hourIndex;
                        // Define working hours (e.g., 9 AM - 6 PM)
                        final isWorkingHour = hour >= 9 && hour < 18;
                        final isCurrentHour = hour == currentHour;

                        return Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: isCurrentHour
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.transparent,
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          child: Row(
                            children: List.generate(7, (dayIndex) {
                              final day =
                                  weekStart.add(Duration(days: dayIndex));
                              final dayWithoutTime =
                                  DateTime(day.year, day.month, day.day);
                              final isToday = day.year == today.year &&
                                  day.month == today.month &&
                                  day.day == today.day;
                              final isSelected = _selectedDay != null &&
                                  day.year == _selectedDay!.year &&
                                  day.month == _selectedDay!.month &&
                                  day.day == _selectedDay!.day;

                              // Get tasks for this specific hour and day
                              final tasksAtHour =
                                  (weekTasks[dayWithoutTime] ?? [])
                                      .where((task) {
                                final taskTime = task.time;
                                return taskTime != null &&
                                    taskTime.hour == hour;
                              }).toList();

                              // Create a DateTime for this hour slot on the current day
                              final slotDateTime = DateTime(
                                day.year,
                                day.month,
                                day.day,
                                hour,
                                0,
                              );

                              // This highlights the specific slot for current time
                              final isNowSlot = isToday && isCurrentHour;

                              return Expanded(
                                child: DragTarget<Map<String, dynamic>>(
                                  builder:
                                      (context, candidateData, rejectedData) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                              color: Colors.grey[200]!),
                                          right: dayIndex == 6
                                              ? BorderSide(
                                                  color: Colors.grey[200]!)
                                              : BorderSide.none,
                                        ),
                                        color: isNowSlot
                                            ? Colors.blue.withOpacity(0.15)
                                            : isSelected &&
                                                    hour == _selectedDay!.hour
                                                ? Theme.of(context)
                                                    .primaryColor
                                                    .withOpacity(0.1)
                                                : isToday
                                                    ? Colors.blue
                                                        .withOpacity(0.05)
                                                    : Colors.transparent,
                                      ),
                                      child: candidateData.isNotEmpty
                                          ? Center(
                                              child: Icon(
                                                Icons.add_circle,
                                                color: Theme.of(context)
                                                    .primaryColor,
                                                size: 24,
                                              ),
                                            )
                                          : tasksAtHour.isEmpty
                                              ? InkWell(
                                                  onTap: () {
                                                    setState(() {
                                                      _selectedDay =
                                                          slotDateTime;
                                                    });
                                                    _showAddPanel();
                                                  },
                                                  child: Center(
                                                    child: Icon(
                                                      Icons.add,
                                                      color: isNowSlot
                                                          ? Colors.blue
                                                          : Colors.grey[400],
                                                      size: 16,
                                                    ),
                                                  ),
                                                )
                                              : ListView.builder(
                                                  physics:
                                                      NeverScrollableScrollPhysics(),
                                                  itemCount: tasksAtHour.length,
                                                  itemBuilder:
                                                      (context, taskIndex) {
                                                    final task =
                                                        tasksAtHour[taskIndex];

                                                    // Determine category color
                                                    Color priorityColor =
                                                        task.priority == "High"
                                                            ? Colors.red
                                                            : task.priority ==
                                                                    "Medium"
                                                                ? Colors.orange
                                                                : Colors.green;

                                                    return LongPressDraggable<
                                                        Map<String, dynamic>>(
                                                      data: {
                                                        'id': task.id,
                                                        'title': task.title,
                                                        'category':
                                                            task.category,
                                                        'priority':
                                                            task.priority,
                                                        'originalTime':
                                                            task.time,
                                                      },
                                                      feedback: Material(
                                                        elevation: 4.0,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(4),
                                                        child: Container(
                                                          width: 100,
                                                          padding:
                                                              EdgeInsets.all(4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        4),
                                                            border: Border(
                                                              left: BorderSide(
                                                                  color:
                                                                      priorityColor,
                                                                  width: 3),
                                                            ),
                                                          ),
                                                          child: Text(
                                                            task.title,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                      ),
                                                      childWhenDragging:
                                                          Opacity(
                                                        opacity: 0.3,
                                                        child:
                                                            _buildCompactTaskItem(
                                                                task,
                                                                priorityColor),
                                                      ),
                                                      child: GestureDetector(
                                                          onTap: () {
                                                            _showTasksForDate(
                                                                context,
                                                                slotDateTime,
                                                                tasksAtHour
                                                                    .length,
                                                                true);
                                                          },
                                                          child:
                                                              _buildCompactTaskItem(
                                                                  task,
                                                                  priorityColor)),
                                                      onDragStarted: () {
                                                        HapticFeedback
                                                            .heavyImpact();
                                                      },
                                                      onDragEnd: (details) {
                                                        HapticFeedback
                                                            .heavyImpact();
                                                      },
                                                    );
                                                  },
                                                ),
                                    );
                                  },
                                  onAccept: (dragData) async {
                                    // When a task is dropped in a time slot
                                    final taskId = dragData['id'];
                                    final newDateTime = DateTime(
                                      slotDateTime.year,
                                      slotDateTime.month,
                                      slotDateTime.day,
                                      slotDateTime.hour,
                                      0,
                                    );

                                    try {
                                      // Update the task time
                                      await _scheduleService.updateTaskTime(
                                        taskId: taskId,
                                        newDateTime: newDateTime,
                                      );

                                      // Refresh the tasks
                                      setState(() {
                                        _loadTasksForSelectedDay();
                                      });

                                      // Show success message
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Task moved to ${DateFormat('E, MMM d').format(newDateTime)} at ${_formatTime(newDateTime)}'),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    } catch (e) {
                                      // Show error message
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Failed to move task: $e'),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        SizedBox(height: 66),
      ],
    );
  }

// Helper method to build a compact task item for the horizontal calendar
  Widget _buildCompactTaskItem(Task task, Color priorityColor) {
    final isDone = task.done;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 1, horizontal: 2),
      height: 22,
      decoration: BoxDecoration(
        color: isDone ? Colors.grey[100] : Colors.white,
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDone ? 0.05 : 0.1),
            blurRadius: 1,
            offset: Offset(0, 1),
          ),
        ],
        border: Border(
          left: BorderSide(
            color: isDone ? Colors.grey : priorityColor,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            // Optional: Add a checkmark icon for completed tasks
            if (isDone)
              Icon(
                Icons.check,
                size: 10,
                color: Colors.grey[600],
              ),
            SizedBox(width: isDone ? 2 : 0),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  fontSize: 10,
                  color: isDone ? Colors.grey[500] : Colors.black87,
                  decoration:
                      isDone ? TextDecoration.lineThrough : TextDecoration.none,
                  fontWeight: isDone ? FontWeight.normal : FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper method for legend item
  Widget _buildLegendItem(Color color, IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10),
        ),
      ],
    );
  }

// // Helper method to build legend items
//   Widget _buildLegendItem(Color color, IconData icon, String label) {
//     return Row(
//       children: [
//         Icon(icon, size: 14, color: color),
//         SizedBox(width: 2),
//         Text(
//           label,
//           style: TextStyle(fontSize: 10, color: Colors.grey[700]),
//         ),
//       ],
//     );
//   }

// Helper method to build a consistent task item
  Widget _buildTaskItem(task, Color priorityColor, Color categoryColor,
      {bool isTargeted = false}) {
    return GestureDetector(
      onTap: () => _navigateToTaskDetails(task),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(top: 10, bottom: 10, right: 20),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isTargeted
              ? priorityColor.withOpacity(0.3)
              : priorityColor.withOpacity(0.1),
          border: Border(
            left: BorderSide(
              color: priorityColor,
              width: 4,
            ),
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: task.done ? TextDecoration.lineThrough : null,
                      color: task.done ? Colors.grey[600] : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: Colors.grey[600],
                      ),
                      SizedBox(width: 4),
                      Text(
                        _formatTime(task.time),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: categoryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          task.category,
                          style: TextStyle(
                            fontSize: 10,
                            color: categoryColor.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Checkbox(
              value: task.done,
              onChanged: (bool? value) {
                // Update task completion status
                if (value == false) {
                  _scheduleService.updateTaskCompletion(task.id, !task.done);
                }
              },
              shape: CircleBorder(),
              activeColor: priorityColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskList() {
    if (_selectedDayTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Lottie.asset(
              'assets/lotties/empty_tasks.json',
              height: 180,
            ),
            Text(
              'No tasks for ${_formatDate(_focusedDay).toString()}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Group tasks by category for better organization
    final groupedTasks = <String, List<Task>>{};
    for (var task in _selectedDayTasks) {
      if (!groupedTasks.containsKey(task.category)) {
        groupedTasks[task.category] = [];
      }
      groupedTasks[task.category]!.add(task);
    }

    // Sort categories alphabetically
    final sortedCategories = groupedTasks.keys.toList()..sort();

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 16),
      itemCount: sortedCategories.length,
      itemBuilder: (context, categoryIndex) {
        final category = sortedCategories[categoryIndex];
        final categoryTasks = groupedTasks[category]!;

        int _getPriorityValue(String priority) {
          switch (priority.toLowerCase()) {
            // Use toLowerCase for case-insensitivity
            case 'high':
              return 3;
            case 'medium':
              return 2;
            case 'low':
              return 1;
            case 'none':
            default: // Handle 'none' and any unexpected values as lowest
              return 0;
          }
        }

        // Sort tasks by priority and completion status
        categoryTasks.sort((a, b) {
          // 1. Done status: unfinished first
          if (a.done != b.done) {
            return a.done
                ? 1
                : -1; // false (unfinished) comes before true (done)
          }

          // If both tasks are UNFINISHED, apply schedule-specific sorting:
          if (!a.done) {
            // 2. Priority: higher first
            final aPriorityVal = _getPriorityValue(a.priority);
            final bPriorityVal = _getPriorityValue(b.priority);
            if (aPriorityVal != bPriorityVal) {
              return bPriorityVal.compareTo(aPriorityVal);
            }
            // 3. Time: Chronological (earliest first)

            return a.time.compareTo(b.time); // Earliest time comes first
          } else {
            final aPriorityVal = _getPriorityValue(a.priority);
            final bPriorityVal = _getPriorityValue(b.priority);
            if (aPriorityVal != bPriorityVal) {
              return bPriorityVal.compareTo(aPriorityVal);
            }

            return b.time.compareTo(a.time);
          }
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _getCategoryIcon(category),
                  SizedBox(width: 8),
                  Text(
                    category,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${categoryTasks.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ...categoryTasks.map((task) => _buildTaskCard(task)).toList(),
            if (categoryIndex < sortedCategories.length - 1)
              Divider(height: 20, indent: 10, endIndent: 10),
          ],
        );
      },
    );
  }

  Widget _buildTaskCard(Task task) {
    // Get current time to check if task is overdue
    final DateTime now = DateTime.now();
    final bool isOverdue = task.time.isBefore(now) && !task.done;

    Color _getPriorityColor(String priority) {
      switch (priority.toLowerCase()) {
        case 'high':
          return Colors.red.shade600;
        case 'medium':
          return Colors.orange.shade600;
        case 'low':
          return Colors.green.shade600;
        default:
          return Colors.blue.shade600;
      }
    }

    final priorityColor = _getPriorityColor(task.priority);
    final isDone = task.done;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isOverdue ? Colors.red.shade200 : Colors.transparent,
          width: isOverdue ? 1 : 0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToTaskDetails(task),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Status indicator (checkbox or overdue indicator)
                InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    setState(() {
                      if (!task.done) {
                        _scheduleService.updateTaskCompletion(task.id, true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tap for details to unmark as done'),
                            backgroundColor: Colors.grey.shade800,
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      }
                    });
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isDone
                          ? priorityColor.withOpacity(0.9)
                          : isOverdue
                              ? Colors.red.withOpacity(0.08)
                              : Colors.transparent,
                      border: Border.all(
                        color: isDone
                            ? priorityColor
                            : isOverdue
                                ? Colors.red.shade400
                                : Colors.grey.shade400,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: isDone
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : isOverdue
                              ? Icon(
                                  Icons.schedule,
                                  size: 16,
                                  color: Colors.red.shade400,
                                )
                              : null,
                    ),
                  ),
                ),
                SizedBox(width: 12),

                // Priority indicator dot
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isDone ? Colors.grey.shade400 : priorityColor,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),

                // Task content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        // maxLines: 1,
                        // overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isDone ? FontWeight.normal : FontWeight.w600,
                          color: isDone
                              ? Colors.grey.shade500
                              : Colors.grey.shade800,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.access_time,
                            size: 14,
                            color: isOverdue
                                ? Colors.red.shade400
                                : Colors.grey.shade500,
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatTime(task.time),
                            style: TextStyle(
                              fontSize: 13,
                              color: isOverdue
                                  ? Colors.red.shade400
                                  : Colors.grey.shade500,
                              fontWeight: isOverdue
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                          if (isOverdue) ...[
                            SizedBox(width: 4),
                            Text(
                              'Overdue',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.red.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Additional actions or info
                if (!isDone)
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      task.priority.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: priorityColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlyCalendar() {
    // Calculate first day of month based on selected day or current date
    final DateTime selectedDate = _selectedDay ?? DateTime.now();
    final DateTime firstDayOfMonth =
        DateTime(selectedDate.year, selectedDate.month, 1);
    final DateTime lastDayOfMonth =
        DateTime(selectedDate.year, selectedDate.month + 1, 0);

    // Calculate the start day (may be from previous month) to fill first row
    // If first day of month is not Monday (weekday 1), go back to find preceding Monday
    final DateTime calendarStartDate = DateTime(
        firstDayOfMonth.year,
        firstDayOfMonth.month,
        firstDayOfMonth.day - (firstDayOfMonth.weekday - 1));

    // Get the number of weeks to display (at most 6)
    final int weeksToDisplay =
        ((lastDayOfMonth.day - lastDayOfMonth.weekday + 7) / 7).ceil();

    // Find maximum task count for heat map intensity
    int maxTaskCount = 0;
    _eventsMap.forEach((day, tasks) {
      if (tasks.length > maxTaskCount) {
        maxTaskCount = tasks.length;
      }
    });

    // Helper function to get heatmap color based on task count
    Color getHeatMapColor(int taskCount) {
      if (taskCount == 0) return Colors.transparent;

      final double intensity =
          taskCount / (maxTaskCount > 0 ? maxTaskCount : 1);

      if (intensity < 0.25) {
        return Colors.green[100]!;
      } else if (intensity < 0.5) {
        return Colors.yellow[300]!;
      } else if (intensity < 0.75) {
        return Colors.orange[700]!;
      } else {
        return Colors.red[400]!;
      }
    }

    return Column(
      children: [
        // Month header with navigation
        Column(
          children: [
            // Minimal month selector with integrated Today button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Month navigation and display
                  Row(
                    children: [
                      // Previous month
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.chevron_left, size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedDay = DateTime(
                                selectedDate.year, selectedDate.month - 1, 1);
                            _loadTasksForSelectedDay();
                          });
                        },
                      ),

                      // Month and year display - tappable
                      GestureDetector(
                        // onTap: () => _showMonthYearPicker(context),
                        child: Text(
                          DateFormat('MMM yyyy').format(selectedDate),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Next month
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.chevron_right, size: 20),
                        onPressed: () {
                          setState(() {
                            _selectedDay = DateTime(
                                selectedDate.year, selectedDate.month + 1, 1);
                            _loadTasksForSelectedDay();
                          });
                        },
                      ),
                    ],
                  ),

                  // Today button - small and minimal
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _selectedDay = DateTime(now.year, now.month, now.day);
                        _loadTasksForSelectedDay();
                      });
                    },
                    child: Text('Today', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Minimal weekday headers
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Row(
                children: List.generate(7, (index) {
                  final weekdayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final isWeekend = index >= 5;

                  return Expanded(
                    child: Container(
                      alignment: Alignment.center,
                      child: Text(
                        weekdayNames[index],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color:
                              isWeekend ? Colors.grey[500] : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Subtle divider
            Divider(
                height: 1, thickness: 0.5, color: Colors.grey.withOpacity(0.2)),
          ],
        ),

        // Calendar grid
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: List.generate(6, (weekIndex) {
              return Row(
                children: List.generate(7, (dayIndex) {
                  final currentDate = calendarStartDate.add(
                    Duration(days: weekIndex * 7 + dayIndex),
                  );

                  final isCurrentMonth =
                      currentDate.month == selectedDate.month;
                  final isToday = currentDate.year == DateTime.now().year &&
                      currentDate.month == DateTime.now().month &&
                      currentDate.day == DateTime.now().day;

                  final isSelected = _selectedDay != null &&
                      currentDate.year == _selectedDay!.year &&
                      currentDate.month == _selectedDay!.month &&
                      currentDate.day == _selectedDay!.day;

                  // Get tasks for this day
                  final dayKey = DateTime(
                      currentDate.year, currentDate.month, currentDate.day);
                  final tasks = _eventsMap[dayKey] ?? [];
                  final taskCount = tasks.length;

                  // Sort tasks by time for ordered display
                  tasks.sort((a, b) => a.time.compareTo(b.time));

                  return Expanded(
                    child: GestureDetector(
                      onLongPress: () {
                        if (isSameDay(_selectedDay, selectedDate)) {
                          _showAddPanel();
                        } else {
                          setState(() {
                            _selectedDay = selectedDate;
                            _focusedDay = selectedDate;
                          });
                          _loadTasksForSelectedDay();
                          _showAddPanel();
                        }
                      },
                      onTap: () {
                        setState(() {
                          _selectedDay = currentDate;
                          _loadTasksForSelectedDay();
                          if (taskCount != 0) {
                            _showTasksForDate(
                                context, _selectedDay!, tasks.length, false);
                          }
                        });
                      },
                      child: AspectRatio(
                        aspectRatio: 0.5,
                        child: Container(
                          decoration: BoxDecoration(
                            color: !isCurrentMonth
                                ? Colors.white.withOpacity(0.5)
                                : isSelected
                                    ? Theme.of(context)
                                        .primaryColor
                                        .withOpacity(0.1)
                                    : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          padding: EdgeInsets.all(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date number with heatmap indicator
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isToday
                                          ? Theme.of(context).primaryColor
                                          : Colors.transparent,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${currentDate.day}',
                                        style: TextStyle(
                                          fontWeight: isToday || isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isToday
                                              ? Colors.white
                                              : isCurrentMonth
                                                  ? Colors.black
                                                  : Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  if (taskCount > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: getHeatMapColor(taskCount),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$taskCount',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: taskCount > maxTaskCount / 2
                                              ? Colors.white
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                ],
                              ),

                              if (isCurrentMonth && tasks.isEmpty)
                                Expanded(
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Opacity(
                                          opacity: 0.5,
                                          child: Image.asset(
                                              'assets/images/task_free${(currentDate.day % 5) + 1}.png',
                                              height: 50),
                                        )
                                      ],
                                    ),
                                  ),
                                ),

                              // Task previews
                              if (isCurrentMonth && tasks.isNotEmpty)
                                Expanded(
                                  child: Scrollbar(
                                    child: ListView.builder(
                                      padding: EdgeInsets.only(top: 2),
                                      physics: BouncingScrollPhysics(),
                                      itemCount: tasks.length,
                                      itemBuilder: (context, index) {
                                        final task = tasks[index];
                                        final isDone = task.done;

                                        // Determine priority color with "None" option
                                        Color priorityColor;
                                        switch (task.priority.toLowerCase()) {
                                          case "high":
                                            priorityColor = Colors.red;
                                            break;
                                          case "medium":
                                            priorityColor = Colors.orange;
                                            break;
                                          case "low":
                                            priorityColor = Colors.green;
                                            break;
                                          case "none":
                                          default:
                                            priorityColor = Colors.grey;
                                            break;
                                        }

                                        return Container(
                                          margin: EdgeInsets.only(bottom: 2),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: isDone
                                                ? Colors.grey[100]
                                                : priorityColor
                                                    .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            border: Border.all(
                                              color: isDone
                                                  ? Colors.grey[300]!
                                                  : priorityColor
                                                      .withOpacity(0.5),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              // Optional checkmark for completed tasks
                                              if (isDone)
                                                Icon(
                                                  Icons.check,
                                                  size: 8,
                                                  color: Colors.grey[500],
                                                ),
                                              SizedBox(width: isDone ? 2 : 0),
                                              Expanded(
                                                child: Text(
                                                  task.title,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: isDone
                                                        ? FontWeight.normal
                                                        : FontWeight.w500,
                                                    color: isDone
                                                        ? Colors.grey[500]
                                                        : Colors.black87,
                                                    decoration: isDone
                                                        ? TextDecoration
                                                            .lineThrough
                                                        : TextDecoration.none,
                                                  ),
                                                ),
                                              ),
                                              // Optional: Show a small indicator of priority if needed
                                              if (!isDone &&
                                                  task.priority != "None")
                                                Container(
                                                  width: 3,
                                                  height: 3,
                                                  margin:
                                                      EdgeInsets.only(left: 2),
                                                  decoration: BoxDecoration(
                                                    color: priorityColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ],
    );
  }

  void _showTasksForDate(BuildContext context, DateTime date, int taskCount,
      bool checkDateTime) async {
    // if (taskCount == 0) {
    //   // Show a message if there are no tasks
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(
    //           'No tasks scheduled for ${DateFormat('MMMM d, yyyy').format(date)}'),
    //       duration: const Duration(seconds: 2),
    //       backgroundColor: Colors.grey,
    //       behavior: SnackBarBehavior.floating,
    //     ),
    //   );
    //   return;
    // }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Task Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                // Loading Indicator
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(height: 24),

                // Loading Text
                const Text(
                  'Loading Tasks',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while we fetch your tasks...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Get tasks for the selected date
    ScheduleService _scheduleService = ScheduleService();
    List<Task> tasks;
    if (!checkDateTime) {
      tasks = await _scheduleService.getSchedulesForDate(date);
    } else {
      tasks = await _scheduleService.getSchedulesForDateTime(date);
    }

    // Close the loading dialog
    Navigator.of(context).pop();

    if (tasks.isEmpty) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text(
      //         'No tasks found for ${DateFormat('MMMM d, yyyy').format(date)}'),
      //     duration: const Duration(seconds: 2),
      //   ),
      // );
      return;
    }

    // Show beautiful modal with tasks
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TasksDisplayModal(
        date: date,
        tasks: tasks,
      ),
    );
  }

  Icon _getCategoryIcon(String? category, {double size = 24}) {
    switch (category?.toLowerCase() ?? 'other') {
      case 'work':
        return Icon(Icons.work_outline_rounded,
            size: size, color: Colors.blue[700]);
      case 'personal':
        return Icon(Icons.person_outline_rounded,
            size: size, color: Colors.purple[700]);
      case 'entertainment':
        return Icon(Icons.sports_esports_rounded,
            size: size, color: Colors.orange[700]);
      case 'health':
        return Icon(Icons.favorite_outline_rounded,
            size: size, color: Colors.green[700]);
      default:
        return Icon(Icons.category_rounded,
            size: size, color: Colors.grey[700]);
    }
  }

  void _navigateToTaskDetails(Task task) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TaskDetailsScreen(task: task),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.scaled,
            child: child,
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class TaskSearchDelegate extends SearchDelegate {
  final Map<DateTime, List<Task>> eventsMap;

  TaskSearchDelegate(this.eventsMap);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    List<Task> allTasks = [];
    eventsMap.values.forEach((tasks) {
      allTasks.addAll(tasks);
    });

    final filteredTasks = allTasks.where((task) {
      return task.title.toLowerCase().contains(query.toLowerCase()) ||
          task.category.toLowerCase().contains(query.toLowerCase());
    }).toList();

    if (filteredTasks.isEmpty) {
      return Center(
        child: Text(
          'No tasks found',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return ListTile(
          title: Text(task.title),
          subtitle: Text(
              '${task.category} • ${task.time.toString().substring(0, 16)}'),
          leading: Container(
            width: 4,
            color: _getPriorityColor(task.priority),
          ),
          onTap: () {
            _navigateToTaskDetails(context, task);
          },
        );
      },
    );
  }

  void _navigateToTaskDetails(BuildContext context, Task task) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            TaskDetailsScreen(task: task),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SharedAxisTransition(
            animation: animation,
            secondaryAnimation: secondaryAnimation,
            transitionType: SharedAxisTransitionType.scaled,
            child: child,
          );
        },
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
