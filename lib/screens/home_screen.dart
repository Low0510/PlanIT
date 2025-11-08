import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_link_previewer/flutter_link_previewer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_places_flutter/model/place_type.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:planit_schedule_manager/const.dart';
import 'package:planit_schedule_manager/models/subtask.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/models/task_file.dart';
import 'package:planit_schedule_manager/screens/add_schedule_screen.dart';
import 'package:planit_schedule_manager/screens/edit_schedule_sreen.dart';
import 'package:planit_schedule_manager/screens/completeTask_screen.dart';
import 'package:planit_schedule_manager/services/file_upload_service.dart';
import 'package:planit_schedule_manager/services/location_service.dart';
import 'package:planit_schedule_manager/utils/repeat_task_parser.dart';
import 'package:planit_schedule_manager/utils/smart_date_parser.dart';
import 'package:planit_schedule_manager/utils/text_cleaner.dart';
import 'package:planit_schedule_manager/widgets/highlighted_title_input.dart';
import 'package:planit_schedule_manager/widgets/in_app_viewer.dart';
import 'package:planit_schedule_manager/widgets/motivation_widget.dart';
import 'package:planit_schedule_manager/widgets/repeat_task_widget.dart';
import 'package:planit_schedule_manager/widgets/taskCard_overlay.dart';
import 'package:planit_schedule_manager/widgets/timline_filter_widget.dart';
import 'package:planit_schedule_manager/widgets/toast.dart';
import 'package:planit_schedule_manager/widgets/wave_progressbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/schedule_service.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:confetti/confetti.dart';
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:animated_emoji/animated_emoji.dart';

class UpwardFloatingButtonLocation extends FloatingActionButtonLocation {
  final double offsetY;

  UpwardFloatingButtonLocation({this.offsetY = -20.0});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        16.0;
    final double fabY = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        16.0 +
        offsetY;
    return Offset(fabX, fabY);
  }
}

class HomeScreen extends StatefulWidget {
  final User user;
  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ScheduleService _scheduleService = ScheduleService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final List<TextEditingController> _subtaskControllers = [];
  final List<FocusNode> _subtaskFocusNodes = [];
  FocusNode _locationFocusNode = FocusNode();

  String? _selectedCategory = 'Other';
  DateTime? _selectedDateTime;
  bool _isRepeatEnabled = false;
  String _selectedPriority = 'Medium';
  String _selectedRepeatInterval = 'Daily';
  int _repeatedIntervalTime = 0;
  late AnimationController _celebrationController;
  late Animation<double> _celebrationAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late ConfettiController _confettiController;

  final Set<int> _selectedWeekdays = <int>{};

  List<File> _selectedFiles = [];
  List<TaskFile> _files = [];
  final FileUploadService _fileUploadService = FileUploadService();

  final selectedCategory = ValueNotifier<String>('All');
  final selectedFilter = ValueNotifier<String>('All');

  late TaskShakeDetector _shakeDetector;

  @override
  void initState() {
    super.initState();
    // _selectedDateTime = DateTime.now().copyWith(hour: 23, minute: 59);
    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _celebrationAnimation = CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeInOut,
    );
    _confettiController =
        ConfettiController(duration: const Duration(milliseconds: 500));

    _titleController.addListener(_parseDateTimeFromTitle);

    _loadFilterPreference();

    _shakeDetector = TaskShakeDetector(onShake: _handleShake);
    _shakeDetector.startListening();
  }

  Future<void> _saveFilterPreference(String filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedFilter', filter);
  }

  // Load filter
  Future<void> _loadFilterPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedFilter.value = prefs.getString('selectedFilter') ?? 'All';
    });
  }

  @override
  void dispose() {
    // Stop and dispose animations
    _celebrationController.stop();
    _celebrationController.dispose();

    _confettiController.stop();
    _confettiController.dispose();

    _celebrationAnimation.removeListener(() {});

    // Dispose other controllers and listeners
    _titleController.removeListener(_parseDateTimeFromTitle);
    _titleController.dispose();
    _urlController.dispose();
    _locationController.dispose();

    _selectedWeekdays.clear();

    for (var controller in _subtaskControllers) {
      controller.dispose();
    }
    for (var focusNode in _subtaskFocusNodes) {
      focusNode.dispose();
    }
    _locationFocusNode.dispose();

    _shakeDetector.stopListening();

    super.dispose();
  }

  void _showCelebrationAnimation() {
    _confettiController.play();
    _celebrationController.forward().then((_) {
      Future.delayed(
          const Duration(seconds: 1), () => _celebrationController.reverse());
    });
  }

  void _handleShake() async {
    try {
      final task = await _scheduleService.getNearestUpcomingTask();
      TaskOverlayManager.showTaskOverlay(context, task, this);
      // if (task != null) {
      //   TaskOverlayManager.showTaskOverlay(context, task);
      // } else {
      //   // Show a message or do something else if no tasks are available
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     SnackBar(content: Text('No upcoming tasks found!')),
      //   );
      // }
    } catch (e) {
      // Handle error
      print('Error getting next task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // Set a transparent AppBar to control the status bar area
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight:
            0, // Zero height since we just want to control the status bar
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark, // For Android (dark icons)
          statusBarBrightness: Brightness.light, // For iOS (dark icons)
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            // Add background image here
            image: DecorationImage(
              image: AssetImage('assets/images/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildScheduleList(),
              _buildCelebrationAnimation(),
              Align(
                alignment: Alignment.centerLeft,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirection: 3.142 / 2,
                  maxBlastForce: 5,
                  minBlastForce: 2,
                  emissionFrequency: 0.05,
                  numberOfParticles: 25,
                  gravity: 0.05,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: GestureDetector(
        onLongPress: () => _handleShake(),
        child: FloatingActionButton(
          backgroundColor: Colors.blue.withOpacity(0.8),
          onPressed: () {
            _showAddPanel();
          },
          child: Icon(Icons.add),
        ),
      ),
      floatingActionButtonLocation: UpwardFloatingButtonLocation(offsetY: -50),
    );
  }

  // ----------------------- Animation Celebrate ----------------------

  // Build the celebration animation From Upward To Downward
  Widget _buildCelebrationAnimation() {
    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) {
        return Positioned(
          top: -150 + (190 * _celebrationAnimation.value),
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.celebration, color: Colors.white, size: 40),
                  SizedBox(height: 8),
                  Text(
                    'Great job!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ----------------------- ADD PANEL ----------------------

  void _parseDateTimeFromTitle() {
    final text = _titleController.text;
    final DateTime? detectedDate = SmartDateParserService.parseText(text);

    if (detectedDate != null && detectedDate != _selectedDateTime) {
      setState(() {
        _selectedDateTime = detectedDate;
        print(_selectedDateTime);
      });
    }
  }

  // Build the Add Panel
  void _showAddPanel() {
    AddSchedulePanel.show(
      context,
      (title, category, url, placeURL, time, subtasks, priority, isRepeated,
          repeatInterval, repeatedIntervalTime, files) async {
        try {
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
    );
  }

  // ----------------------- SCHEDULE LIST DISPLAY ----------------------

  Widget _buildScheduleList() {
    // Define possible categories
    final categories = [
      {'name': 'All', 'icon': Icons.layers_outlined},
      {'name': 'Work', 'icon': Icons.work_outline},
      {'name': 'Personal', 'icon': Icons.person_outline},
      {'name': 'Entertainment', 'icon': Icons.movie_outlined},
      {'name': 'Health', 'icon': Icons.fitness_center_outlined},
      {'name': 'Other', 'icon': Icons.more_horiz_outlined}
    ];

    // Track the current selected category and filter type

    final searchQuery = ValueNotifier<String>('');
    final searchController = TextEditingController();
    final isFilterExpanded = ValueNotifier<bool>(false);

    final filterOptions = ['All', 'Overdue', 'Today', 'Coming Soon'];
    // Define the specific filters for the swipe gesture
    final List<String> _swipeableStatusFilters = [
      'All',
      'Coming Soon',
      'Today',
      'Overdue'
    ];

    final Color primaryColor = Color(0xFFC19A6B); // Warm tan/brown
    final Color secondaryColor = Color(0xFFE6CCB2); // Light beige
    final Color accentColor = Color(0xFFAF805F); // Darker warm brown
    final Color textColor = Color(0xFF5C4033); // Deep brown for text
    final Color bgColor = Color(0xFFF7F0E6); // Very light beige background
    final Color cardColor =
        Colors.white.withOpacity(0.8); // Almost white for cards

    Timer? _debounceTimer;

    Color getCategoryColor(String category) {
      switch (category) {
        case 'Work':
          return Colors.blue.shade500;
        case 'Personal':
          return Colors.purple.shade500;
        case 'Entertainment':
          return Colors.orange.shade500;
        case 'Health':
          return Colors.green.shade500;
        case 'Other':
          return Colors.grey.shade500;
        default: // 'All'
          return Colors.blue.shade500;
      }
    }

    Color getHeaderCategoryColor(
        String category, Color primaryColor, Color accentColor) {
      switch (category) {
        case 'Work':
          return Color(0xFFD4A76A); // Warm golden brown
        case 'Personal':
          return Color(0xFFB08968); // Rosy brown
        case 'Entertainment':
          return Color(0xFFE6AD6E); // Light amber
        case 'Health':
          return Color(0xFF9C7F61); // Olive brown
        case 'Other':
          return Color(0xFFA39081); // Taupe
        default: // 'All'
          return primaryColor;
      }
    }

    // Compact version of quick action button
    Widget _buildCompactQuickActionButton(String text, IconData icon,
        Color primaryColor, Color textColor, VoidCallback onTap) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 14, // Smaller icon
                    color: primaryColor,
                  ),
                  SizedBox(width: 6),
                  Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12, // Smaller text
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Helper method to cycle through filters
    void _cycleFilter({required bool isSwipeRight}) {
      final currentFilterValue = selectedFilter.value;
      int currentIndex = _swipeableStatusFilters.indexOf(currentFilterValue);

      if (currentIndex == -1) {
        if (isSwipeRight) {
          selectedFilter.value = _swipeableStatusFilters.first;
        } else {
          selectedFilter.value = _swipeableStatusFilters.last;
        }
      } else {
        // Cycle through the _swipeableStatusFilters
        if (isSwipeRight) {
          currentIndex = (currentIndex + 1) % _swipeableStatusFilters.length;
          HapticFeedback.mediumImpact();
        } else {
          currentIndex = (currentIndex - 1 + _swipeableStatusFilters.length) %
              _swipeableStatusFilters.length;
          HapticFeedback.mediumImpact();
        }
        selectedFilter.value = _swipeableStatusFilters[currentIndex];
      }
      _saveFilterPreference(selectedFilter.value);
    }

    Widget buildFiltersUI() {
      return ValueListenableBuilder<bool>(
        valueListenable: isFilterExpanded,
        builder: (context, isExpanded, _) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Filter header - now with GestureDetector
                GestureDetector(
                  // MODIFICATION: Added GestureDetector
                  onHorizontalDragEnd: (details) {
                    if (!isExpanded) {
                      // Only allow swipe if not expanded
                      // Determine swipe direction
                      // A common threshold for velocity to detect a swipe
                      const double kSwipeVelocityThreshold = 200.0;

                      if (details.primaryVelocity! > kSwipeVelocityThreshold) {
                        // Swiped Right (previous filter in our desired cycle)
                        _cycleFilter(isSwipeRight: true);
                      } else if (details.primaryVelocity! <
                          -kSwipeVelocityThreshold) {
                        // Swiped Left (next filter in our desired cycle)
                        _cycleFilter(isSwipeRight: false);
                      }
                    }
                  },
                  child: InkWell(
                    onTap: () {
                      isFilterExpanded.value = !isExpanded;
                    },
                    onLongPress: () {
                      // MODIFICATION: Optional: Open on long press too
                      if (!isExpanded) {
                        isFilterExpanded.value = true;
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.12),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(6), // Smaller padding
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      primaryColor.withOpacity(0.9),
                                      accentColor.withOpacity(0.9),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.filter_list_rounded,
                                  color: Colors.white,
                                  size: 16, // Smaller icon
                                ),
                              ),
                              SizedBox(width: 10),
                              ValueListenableBuilder<String>(
                                valueListenable: selectedFilter,
                                builder: (context, currentFilter, _) {
                                  return ValueListenableBuilder<String>(
                                    valueListenable: selectedCategory,
                                    builder: (context, currentCategory, _) {
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Filters",
                                            style: TextStyle(
                                              fontSize: 11, // Smaller text
                                              color: textColor.withOpacity(0.7),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          SizedBox(height: 1),
                                          Text(
                                            "$currentFilter • $currentCategory",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14, // Smaller text
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                          Icon(
                            isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: primaryColor,
                            size: 20, // Smaller icon
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Expandable filter options - simplified with less padding
                AnimatedCrossFade(
                  duration: Duration(milliseconds: 250),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: SizedBox(height: 0),
                  secondChild: Container(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Filter type section - more compact
                        Container(
                          margin: EdgeInsets.only(left: 4, right: 4, bottom: 8),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.08),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.sort_rounded,
                                    size: 14, // Smaller icon
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Filter by Status",
                                    style: TextStyle(
                                      fontSize: 13, // Smaller text
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),

                              // Filter options with more compact design
                              SizedBox(
                                height: 38, // Shorter height
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: filterOptions.map((filter) {
                                    // Use your full filterOptions here
                                    IconData iconData = filter == 'Overdue'
                                        ? Icons.warning_amber_rounded
                                        : filter == 'Today'
                                            ? Icons.today_rounded
                                            : filter == 'Coming Soon'
                                                ? Icons.upcoming_rounded
                                                : Icons
                                                    .layers_rounded; // For 'All'

                                    return Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ValueListenableBuilder<String>(
                                        valueListenable: selectedFilter,
                                        builder: (context, currentFilter, _) {
                                          final isSelected =
                                              currentFilter == filter;
                                          return InkWell(
                                            onTap: () {
                                              selectedFilter.value = filter;
                                              _saveFilterPreference(filter);
                                            },
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: AnimatedContainer(
                                              duration:
                                                  Duration(milliseconds: 200),
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical:
                                                      6), // Smaller padding
                                              decoration: BoxDecoration(
                                                gradient: isSelected
                                                    ? LinearGradient(
                                                        colors: [
                                                          primaryColor,
                                                          accentColor,
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      )
                                                    : null,
                                                color: isSelected
                                                    ? null
                                                    : secondaryColor
                                                        .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: isSelected
                                                    ? [
                                                        BoxShadow(
                                                          color: primaryColor
                                                              .withOpacity(0.2),
                                                          blurRadius: 6,
                                                          offset: Offset(0, 2),
                                                        )
                                                      ]
                                                    : null,
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    iconData,
                                                    size: 16, // Smaller icon
                                                    color: isSelected
                                                        ? Colors.white
                                                        : accentColor,
                                                  ),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    filter,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? Colors.white
                                                          : textColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize:
                                                          12, // Smaller text
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Category section - more compact
                        Container(
                          margin: EdgeInsets.only(left: 4, right: 4, bottom: 8),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.08),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.category_rounded,
                                    size: 14, // Smaller icon
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Filter by Category",
                                    style: TextStyle(
                                      fontSize: 13, // Smaller text
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),

                              // Category options in a wrapped grid with more compact design
                              Wrap(
                                spacing: 8, // Less spacing
                                runSpacing: 8, // Less spacing
                                children: categories.map((category) {
                                  return ValueListenableBuilder(
                                    valueListenable: selectedCategory,
                                    builder:
                                        (context, String currentCategory, _) {
                                      final isSelected =
                                          currentCategory == category['name'];
                                      return InkWell(
                                        onTap: () {
                                          selectedCategory.value =
                                              category['name'] as String;
                                          // _saveCategoryPreference(category['name'] as String); // You might want this
                                        },
                                        borderRadius: BorderRadius.circular(12),
                                        child: AnimatedContainer(
                                          duration: Duration(milliseconds: 200),
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6), // Smaller padding
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? LinearGradient(
                                                    colors: [
                                                      getHeaderCategoryColor(
                                                          category['name']
                                                              as String,
                                                          primaryColor,
                                                          accentColor),
                                                      getHeaderCategoryColor(
                                                              category['name']
                                                                  as String,
                                                              primaryColor,
                                                              accentColor)
                                                          .withOpacity(0.8),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            color: isSelected
                                                ? null
                                                : secondaryColor
                                                    .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color:
                                                          getHeaderCategoryColor(
                                                                  category[
                                                                          'name']
                                                                      as String,
                                                                  primaryColor,
                                                                  accentColor)
                                                              .withOpacity(0.2),
                                                      blurRadius: 6,
                                                      offset: Offset(0, 2),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                category['icon'] as IconData,
                                                size: 14, // Smaller icon
                                                color: isSelected
                                                    ? Colors.white
                                                    : getHeaderCategoryColor(
                                                            category['name']
                                                                as String,
                                                            primaryColor,
                                                            accentColor)
                                                        .withOpacity(0.7),
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                category['name'] as String,
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : textColor,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12, // Smaller text
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        // Quick actions section - more compact
                        Container(
                          margin: EdgeInsets.only(left: 4, right: 4),
                          padding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withOpacity(0.08),
                                blurRadius: 8,
                                spreadRadius: 0,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 14, // Smaller icon
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "Quick Actions",
                                    style: TextStyle(
                                      fontSize: 13, // Smaller text
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),

                              // Quick action buttons - more compact
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildCompactQuickActionButton(
                                    "Reset",
                                    Icons.restart_alt_rounded,
                                    primaryColor,
                                    textColor,
                                    () {
                                      selectedFilter.value = 'All';
                                      selectedCategory.value = 'All';
                                      _saveFilterPreference('All');
                                      // _saveCategoryPreference('All');
                                    },
                                  ),
                                  _buildCompactQuickActionButton(
                                    "Today",
                                    Icons.today_rounded,
                                    primaryColor,
                                    textColor,
                                    () {
                                      selectedFilter.value = 'Today';
                                      selectedCategory.value =
                                          'All'; // Or keep current category?
                                      _saveFilterPreference('Today');
                                      // _saveCategoryPreference('All');
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Separated schedule list part
    Widget buildScheduleList() {
      return ValueListenableBuilder(
        valueListenable: searchQuery,
        builder: (context, String currentSearch, _) {
          return ValueListenableBuilder(
            valueListenable: selectedFilter,
            builder: (context, String currentFilter, _) {
              return ValueListenableBuilder(
                valueListenable: selectedCategory,
                builder: (context, String currentCategory, _) {
                  return StreamBuilder<List<Task>>(
                    stream: _scheduleService.getSchedules(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final schedules = snapshot.data!
                          .where((task) => !task.done)
                          .where((task) {
                        final taskCategory = categories.any(
                                (category) => category['name'] == task.category)
                            ? task.category
                            : 'Other';
                        return (currentCategory == 'All' ||
                                currentCategory == taskCategory) &&
                            (currentSearch.isEmpty ||
                                task.title
                                    .toLowerCase()
                                    .contains(currentSearch.toLowerCase()));
                      }).toList();

                      // Sort and group logic remains the same
                      schedules.sort((a, b) {
                        int mapPriority(String priority) {
                          switch (priority.toLowerCase()) {
                            case 'high':
                              return 1;
                            case 'medium':
                              return 2;
                            case 'low':
                              return 3;
                            default:
                              return 4;
                          }
                        }

                        int priorityComparison = mapPriority(a.priority)
                            .compareTo(mapPriority(b.priority));
                        if (priorityComparison != 0) return priorityComparison;

                        int timeComparison = (a.time).compareTo(b.time);
                        if (timeComparison != 0) return timeComparison;

                        return (a.createdAt!).compareTo(b.createdAt!);
                      });

                      final now = DateTime.now();
                      final today = DateTime(now.year, now.month, now.day);
                      final overdue = schedules
                          .where((s) => s.time.isBefore(today))
                          .toList();
                      final todayDate = DateFormat('dd/MM').format(now);
                      final dayOfWeek = DateFormat('EEEE').format(now);

                      final todaySchedules = schedules.where((s) {
                        final scheduleDate = s.time;
                        return scheduleDate.year == today.year &&
                            scheduleDate.month == today.month &&
                            scheduleDate.day == today.day;
                      }).toList();

                      final future = schedules
                          .where((s) =>
                              s.time.isAfter(today.add(Duration(days: 1))))
                          .where((s) {
                        if (!s.isRepeated) return true;

                        final nearestRepeatedTask = schedules
                            .where((repeat) =>
                                repeat.title == s.title &&
                                repeat.isRepeated &&
                                repeat.repeatInterval == s.repeatInterval &&
                                repeat.time
                                    .isAfter(today.add(Duration(days: 1))))
                            .toList();

                        return nearestRepeatedTask.isNotEmpty &&
                            nearestRepeatedTask.first.time == s.time;
                      }).toList();

                      // Determine if we should show tasks based on filter
                      bool hasOverdueTasks = overdue.isNotEmpty &&
                          (currentFilter == 'All' ||
                              currentFilter == 'Overdue');
                      bool hasTodayTasks = todaySchedules.isNotEmpty &&
                          (currentFilter == 'All' || currentFilter == 'Today');
                      bool hasFutureTasks = future.isNotEmpty &&
                          (currentFilter == 'All' ||
                              currentFilter == 'Coming Soon');

                      // Show empty state only if no tasks match the current filter
                      bool showEmptyState =
                          !hasOverdueTasks && !hasTodayTasks && !hasFutureTasks;

                      final scheduleItems = <Widget>[];

                      if (showEmptyState) {
                        scheduleItems.add(Padding(
                          padding: EdgeInsets.only(top: 100),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Lottie.asset(
                                'assets/lotties/empty_tasks.json',
                                height: 250,
                              ),
                              Text(
                                'No pending schedules!',
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                              SizedBox(
                                height: 40,
                              )
                            ],
                          ),
                        ));
                      } else {
                        // Only add sections that have tasks and match the filter
                        if (hasOverdueTasks) {
                          scheduleItems.add(_buildDividerOverdue('Overdue'));
                          scheduleItems.addAll(
                              overdue.map((s) => _buildScheduleItem(s)));
                        }

                        if (hasTodayTasks) {
                          scheduleItems.add(_buildDividerToday(
                              'Today $todayDate $dayOfWeek'));
                          scheduleItems.addAll(
                              todaySchedules.map((s) => _buildScheduleItem(s)));
                        }

                        if (hasFutureTasks) {
                          scheduleItems.add(_buildDividerFuture('Coming Soon'));
                          scheduleItems
                              .addAll(future.map((s) => _buildScheduleItem(s)));
                        }
                      }

                      // Always add the completed button
                      scheduleItems.add(_buildViewCompletedButton());

                      return AnimationLimiter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: ListView.builder(
                            itemCount: scheduleItems.length,
                            itemBuilder: (BuildContext context, int index) {
                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: scheduleItems[index],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      );
    }

    // Main build method combining both parts
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildFiltersUI(),
          Expanded(
            child: buildScheduleList(),
          ),
        ],
      ),
    );
  }

  // Widget Button View Completed button to Show Completed Tasks
  Widget _buildViewCompletedButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
      child: InkWell(
        onTap: () => _showCompletedTasks(),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'Today Completed',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build the Divider Line
  Widget _buildDividerToday(String title) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate time progression
        final now = DateTime.now();
        final startOfDay = DateTime(now.year, now.month, now.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        // Calculate percentage of day passed
        final totalSecondsInDay = 24 * 60 * 60;
        final secondsPassed = now.difference(startOfDay).inSeconds;
        final dayProgressPercentage = secondsPassed / totalSecondsInDay;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600]),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Stack(
                  children: [
                    // Full line background
                    Divider(thickness: 1, color: Colors.grey[300]),
                    // Progression line
                    FractionallySizedBox(
                      widthFactor: dayProgressPercentage,
                      child: Divider(
                          thickness: 3,
                          color: _getProgressColor(dayProgressPercentage)),
                    ),
                  ],
                ),
              ),
              // Optional: Show percentage text
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '${(dayProgressPercentage * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Helper method to get color based on day progression
  Color _getProgressColor(double progress) {
    if (progress < 0.25) return Colors.green[300]!;
    if (progress < 0.5) return Colors.blue[300]!;
    if (progress < 0.75) return Colors.orange[300]!;
    return Colors.red[300]!;
  }

  Widget _buildDividerOverdue(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.red[600]),
          ),
          SizedBox(width: 8),
          Expanded(child: Divider(thickness: 1, color: Colors.grey[400])),
        ],
      ),
    );
  }

  Widget _buildDividerFuture(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600]),
          ),
          SizedBox(width: 8),
          Expanded(child: Divider(thickness: 1, color: Colors.grey[400])),
        ],
      ),
    );
  }

  // Build the Schedule Item Card With Dismissible
  Widget _buildScheduleItem(Task task) {
    final DateTime now = DateTime.now();
    final DateTime scheduleTime = task.time;

    final bool isToday = now.year == scheduleTime.year &&
        now.month == scheduleTime.month &&
        now.day == scheduleTime.day;
    final bool isOverdue = scheduleTime.isBefore(now);

    final Duration difference = scheduleTime.difference(now);
    final String calculatedHour = (difference.inHours).abs().toString();
    final String calculatedMinutes =
        (difference.inMinutes % 60).abs().toString().padLeft(2, '0');

    String statusText;
    if (isOverdue) {
      statusText = difference.inDays.abs() > 0
          ? '${difference.inDays.abs()}d ${difference.inHours.abs() % 24}h overdue'
          : '${difference.inHours.abs()}h ${difference.inMinutes.abs() % 60}m overdue';
    } else if (isToday) {
      statusText = '${difference.inHours}h ${difference.inMinutes % 60}m left';
    } else {
      statusText = difference.inDays > 0
          ? 'In ${difference.inDays}d ${difference.inHours % 24}h'
          : 'In ${difference.inHours}h ${difference.inMinutes % 60}m';
    }

    // Get priority color (assuming you have a priority field, default to medium)
    final priority = task.priority;
    final Color priorityColor = {
          'high': Colors.red[400]!,
          'medium': Colors.orange[400]!,
          'low': Colors.green[400]!,
        }[priority.toLowerCase()] ??
        Colors.grey[400]!;

    // Define emotion options with their meanings
    final Map<String, String> emotions = {
      '😆': 'Love this task',
      '😍': 'Perfect task fit',
      '🥳': 'Milestone reached',
      '🥴': 'Too much workload',
      '😡': 'Blocked progress',
      '😢': 'Need assistance',
      '😫': 'Urgent help needed',
      '🚀': 'Moving fast',
    };

    final Map<String, AnimatedEmojiData> emojiToAnimated = {
      '😆': AnimatedEmojis.laughing,
      '😍': AnimatedEmojis.heartEyes,
      '🥳': AnimatedEmojis.partyingFace,
      '🥴': AnimatedEmojis.melting,
      '😡': AnimatedEmojis.rage,
      '😢': AnimatedEmojis.cry,
      '😫': AnimatedEmojis.weary,
      '🚀': AnimatedEmojis.rocket,
    };

    void showMotivationDialog(BuildContext context, String emotion) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: MotivationWidget(selectedEmotion: emotion),
          );
        },
      );
    }

    void _showEmotionPicker() {
      String? _currentEmotion = task.emotion;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (BuildContext context) {
          // Get device width to calculate layout
          double screenWidth = MediaQuery.of(context).size.width;

          return Container(
            width: screenWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Stack(
              children: [
                // Background image layer
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.asset(
                      'assets/images/background.png', // Ensure this asset exists
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Semi-transparent overlay layer
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                  ),
                ),
                // Content layer - improved layout
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Handle indicator
                      Container(
                        width: 40,
                        height: 4,
                        margin: EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header text
                      Text(
                        'How do you feel about this task?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      // Emotion grid with better spacing
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4, // 4 emotions per row
                          childAspectRatio:
                              0.7, // Adjusted for potentially taller items due to wrapped text
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: emotions
                            .length, // Make sure 'emotions' is defined and accessible
                        itemBuilder: (context, index) {
                          String emotionKey = emotions.keys.elementAt(index);
                          String emotionText = emotions.values.elementAt(index);
                          bool isSelected = emotionKey == _currentEmotion;

                          return InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              Navigator.pop(context);
                              if (isSelected) {
                                // Presuming _scheduleService and task are accessible
                                _scheduleService.updateTaskEmotion(
                                    task.id, null);
                              } else {
                                _scheduleService.updateTaskEmotion(
                                    task.id, emotionKey);
                                showMotivationDialog(context,
                                    emotionKey); // Ensure showMotivationDialog is defined
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Emotion container with better visual feedback
                                AnimatedContainer(
                                  duration: Duration(milliseconds: 200),
                                  width: 50, // Made smaller
                                  height: 50, // Made smaller
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.blue[100]
                                        : Colors.grey[100],
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey[300]!,
                                      width: isSelected ? 2 : 1,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(12), // Adjusted
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color:
                                                  Colors.blue.withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: Offset(0, 2),
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      emotionKey,
                                      style: TextStyle(
                                        fontSize: isSelected
                                            ? 28
                                            : 24, // Made smaller
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                // Emotion label with better readability and full text
                                Text(
                                  emotionText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? Colors.blue[800]
                                        : Colors.grey[700],
                                  ),
                                  textAlign: TextAlign.center,
                                  // Removed overflow and maxLines to allow text to wrap
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Card(
          elevation: 3,
          // color: Color.fromRGBO(255, 255, 255, 0.6), // Semi-transparent background
          color: Colors.white.withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isOverdue
                  ? Colors.red.withOpacity(0.3)
                  : isToday
                      ? Colors.blue.withOpacity(0.3)
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Dismissible(
              key: Key(task.id),
              background: Container(
                decoration: BoxDecoration(
                  color: Colors.red[400],
                ),
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(left: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete_outline, color: Colors.white, size: 28),
                    SizedBox(height: 4),
                    Text('Delete',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              secondaryBackground: Container(
                decoration: BoxDecoration(
                  color: Colors.green[400],
                ),
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline,
                        color: Colors.white, size: 28),
                    SizedBox(height: 4),
                    Text('Complete',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              direction: DismissDirection.horizontal,
              confirmDismiss: (direction) async {
                final dismissedTask = task;
            
                if (direction == DismissDirection.endToStart) {
                  _scheduleService.updateTaskCompletion(task.id, true);
                  HapticFeedback.heavyImpact();
                  _showCelebrationAnimation();
                  SystemSound.play(SystemSoundType.click);
                  // await _audioPlayer.play(AssetSource('musics/done.mp3'));
            
                  // Show SnackBar with Undo option
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Task marked as done.'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          // Undo the "mark as done" action
                          _scheduleService.updateTaskCompletion(
                              dismissedTask.id, false);
                        },
                      ),
                      backgroundColor: Colors.green[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } else {
                  if (task.groupID == null) {
                    _scheduleService.deleteSchedule(task.id);
                  } else {
                    bool? deleteAll = await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text('Delete Task'),
                            content:
                                Text('Delete All Repeated Tasks / Current Task?'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(false);
                                },
                                child: Text('This Task'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(true);
                                },
                                child: Text('All Tasks'),
                              ),
                            ],
                          );
                        });
                    if (deleteAll == null) {
                      return false; // Cancel dismissal if dialog is cancelled
                    }
            
                    try {
                      if (deleteAll) {
                        // Show a loading dialog while deleting tasks
                        BuildContext dialogContext;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            dialogContext = context;
                            return Dialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Delete icon
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Colors.red[400],
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
            
                                    // Loading indicator
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.red[400]!),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
            
                                    // Text
                                    const Text(
                                      'Deleting Tasks',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Please wait while we delete all repeated tasks...',
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
            
                        // Await the task deletion process
                        await _scheduleService.deleteRepeatedTasks(task.groupID!);
            
                        // Close the loading dialog
                        Navigator.of(context, rootNavigator: true).pop();
            
                        // Show success dialog
                        await showDialog(
                          context: context,
                          barrierDismissible: true,
                          builder: (BuildContext context) {
                            return Dialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Success icon
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_outline,
                                        color: Colors.green,
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
            
                                    // Success text
                                    const Text(
                                      'Success',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'All repeated tasks have been deleted successfully.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
            
                                    // OK button
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                      ),
                                      child: const Text(
                                        'OK',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
            
                        return true;
                      } else {
                        // For single task deletion, show a simpler loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return Dialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Loading indicator
                                    SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.red[400]!),
                                      ),
                                    ),
                                    const SizedBox(height: 20),
            
                                    // Text
                                    const Text(
                                      'Deleting Task',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
            
                        // Delete the single schedule
                        await _scheduleService.deleteSchedule(task.id);
            
                        // Close loading dialog
                        Navigator.of(context, rootNavigator: true).pop();
            
                        return true;
                      }
                    } catch (e) {
                      // Close any open dialogs first
                      Navigator.of(context, rootNavigator: true).pop();
            
                      // Show error dialog
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return Dialog(
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Error icon
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 32,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
            
                                  // Error text
                                  const Text(
                                    'Error',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Failed to delete task: ${e.toString()}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
            
                                  // OK button
                                  ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[400],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(30),
                                      ),
                                    ),
                                    child: const Text(
                                      'OK',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
            
                      return false;
                    }
                  }
            
                  // await _audioPlayer.play(AssetSource('musics/remove.mp3'));
                  HapticFeedback.heavyImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Task deleted!'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          _scheduleService.reAddSchedule(task);
                        },
                      ),
                      backgroundColor: Colors.red[400],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
                return true;
              },
              child: InkWell(
                onTap: () => _showScheduleDetails(task),
                onLongPress: () => _editSchedule(task),
                onDoubleTap: _showEmotionPicker,
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        offset: Offset(0, 2),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        // Emoji at top right with semi-transparency
                        if (task.emotion != null)
                          Positioned(
                            right: 5,
                            top: -5,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              child: Opacity(
                                opacity: 0.8,
                                child: AnimatedEmoji(
                                  emojiToAnimated[task.emotion!] ??
                                      AnimatedEmojis.smile,
                                  size: 42,
                                  errorWidget: Text(
                                    task.emotion!,
                                    style: TextStyle(
                                      // semi-transparent white text
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 30,
                                      shadows: [
                                        Shadow(
                                          color: Colors.white,
                                          blurRadius: 15,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
            
                        // Main content
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Date container with priority indicator
                            Container(
                                width: 55,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: isOverdue
                                      ? Colors.red.withOpacity(0.1)
                                      : (isToday
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isOverdue
                                        ? Colors.red.withOpacity(0.3)
                                        : (isToday
                                            ? Colors.blue.withOpacity(0.3)
                                            : Colors.grey.withOpacity(0.3)),
                                    width: 1.5,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Priority indicator
                                    Positioned(
                                      top: 0,
                                      right: 0,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: priorityColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    // Date display with day of week
                                    Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          // Day of week
                                          Container(
                                            width: 42,
                                            padding:
                                                EdgeInsets.symmetric(vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isOverdue
                                                  ? Colors.red[400]
                                                  : (isToday
                                                      ? Colors.blue[400]
                                                      : Colors.grey[400]),
                                              borderRadius: BorderRadius.only(
                                                topLeft: Radius.circular(8),
                                                topRight: Radius.circular(8),
                                              ),
                                            ),
                                            child: Text(
                                              DateFormat('EEE')
                                                  .format(scheduleTime)
                                                  .toUpperCase(),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          // Day number
                                          Text(
                                            DateFormat('dd').format(scheduleTime),
                                            style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: isOverdue
                                                  ? Colors.red[700]
                                                  : (isToday
                                                      ? Colors.blue[700]
                                                      : Colors.grey[700]),
                                            ),
                                          ),
                                          // Month name
                                          Container(
                                            width: 42,
                                            padding:
                                                EdgeInsets.symmetric(vertical: 1),
                                            decoration: BoxDecoration(
                                              color: isOverdue
                                                  ? Colors.red[50]
                                                  : (isToday
                                                      ? Colors.blue[50]
                                                      : Colors.grey[100]),
                                              borderRadius: BorderRadius.only(
                                                bottomLeft: Radius.circular(6),
                                                bottomRight: Radius.circular(6),
                                              ),
                                            ),
                                            child: Text(
                                              DateFormat('MMM')
                                                  .format(scheduleTime)
                                                  .toUpperCase(),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w500,
                                                color: isOverdue
                                                    ? Colors.red[700]
                                                    : (isToday
                                                        ? Colors.blue[700]
                                                        : Colors.grey[700]),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )),
            
                            SizedBox(width: 12),
            
                            // Content section
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Title row with more spacing
                                  Text(
                                    task.title,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
            
                                  SizedBox(height: 10), // Increased spacing here
            
                                  // Time info row with container
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isOverdue
                                          ? Colors.red.withOpacity(0.08)
                                          : (isToday
                                              ? Colors.blue.withOpacity(0.08)
                                              : Colors.grey.withOpacity(0.08)),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isOverdue
                                              ? Icons.warning_amber_rounded
                                              : Icons.schedule_rounded,
                                          size: 14,
                                          color: isOverdue
                                              ? Colors.red[600]
                                              : Colors.grey[600],
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          DateFormat('HH:mm')
                                              .format(scheduleTime),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: isOverdue
                                                ? Colors.red[600]
                                                : Colors.grey[600],
                                          ),
                                        ),
                                        if (task.isRepeated == true)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(left: 4),
                                            child: Icon(
                                              Icons.repeat,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6),
                                          child: Text(
                                            '•',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            statusText,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isOverdue
                                                  ? Colors.red[600]
                                                  : Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
            
                                  SizedBox(height: 10), // Increased spacing here
            
                                  // Tags row
                                  Row(
                                    children: [
                                      // Priority tag
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: priorityColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.flag_rounded,
                                              size: 12,
                                              color: priorityColor,
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              priority.toUpperCase(),
                                              style: TextStyle(
                                                color: priorityColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
            
                                      SizedBox(width: 6),
            
                                      // Category tag
                                      if (task.category != null)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color:
                                                _getCategoryColor(task.category)
                                                    .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _getCategoryIcon(task.category,
                                                  size: 12),
                                              SizedBox(width: 3),
                                              Text(
                                                task.category ?? 'Other',
                                                style: TextStyle(
                                                  color: _getCategoryColor(
                                                      task.category),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
            
                                      // Emotional tag - only shown if there's space
                                      if (task.emotion != null)
                                        Expanded(
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .emoji_emotions_outlined,
                                                      size: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                    SizedBox(width: 3),
                                                    Text(
                                                      _getEmotionText(
                                                          task.emotion!),
                                                      style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getEmotionText(String emoji) {
    // Map emojis to descriptive text
    final Map<String, String> emotionMap = {
      '😆': 'enjoy',
      '😍': 'love',
      '🥳': 'party',
      '🥴': 'dizzy',
      '😡': 'anger',
      '😢': 'sad',
      '😫': 'urgent',
      '🚀': 'boost'
    };
    return emotionMap[emoji] ?? 'unknown';
  }

  // Helper functions for the new design
  Color _getCategoryColor(String? category) {
    switch (category?.toLowerCase() ?? 'other') {
      case 'work':
        return Colors.blue;
      case 'personal':
        return Colors.purple;
      case 'entertainment':
        return Colors.orange;
      case 'health':
        return Colors.green;
      default:
        return Colors.grey;
    }
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

  // Click on the "View Completed Tasks" to Show Completed Tasks
  void _showCompletedTasks() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CompletedTasksScreen()),
      // FadeRouteBuilder(page: CompletedTasksScreen()),
    );
  }

  void _showScheduleDetails(Task task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        expand: true,
        builder: (_, controller) =>
            _buildScheduleDetailsContent(task, controller),
      ),
    );
  }

  Widget _buildScheduleDetailsContent(Task task, ScrollController controller) {
    final scheduleTime = task.time;
    final isOverdue = scheduleTime.isBefore(DateTime.now());
    final Duration difference = scheduleTime.difference(DateTime.now());
    final isToday = scheduleTime.day == DateTime.now().day;

    final LocationService _locationService = LocationService();
    Position? _currentPosition;
    String? eta;

    TextEditingController subtaskTitleController = TextEditingController();

    var dataLink;

    String getTimeStatus() {
      if (isOverdue) return '${difference.inHours.abs()} hours overdue';
      if (isToday) return 'Today';
      return 'In ${difference.inDays} days';
    }

    Future<String> getETAString(String? placeId) async {
      if (placeId == null) {
        print("Place ID null");
        return "";
      }
      ;

      print("Start getting ETA: $placeId");

      try {
        // Get current position using LocationService
        final position = await _locationService.determinePosition();

        // Format the origin as lat,lng
        String origin = "${position.latitude},${position.longitude}";
        print('Origin $origin');

        // Make API request to Google Directions API
        final response = await http.get(
            Uri.parse('https://maps.googleapis.com/maps/api/directions/json?'
                'origin=$origin'
                '&destination=place_id:$placeId'
                '&mode=driving'
                '&key=$GOOGLE_API'));

        if (response.statusCode == 200) {
          var data = json.decode(response.body);
          if (data['status'] == 'OK') {
            // Extract the duration text
            print(
                "Eta Time:  ${data['routes'][0]['legs'][0]['duration']['text']}");
            return data['routes'][0]['legs'][0]['duration']['text'];
          }
        }
        return "";
      } catch (e) {
        print("Error calculating ETA: $e");
        return "";
      }
    }

    // print(schedule['subtasks']);

    return StatefulBuilder(
      builder: (context, setState) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Stack(children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          // Semi-transparent overlay
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.white.withOpacity(0.5),
            ),
          ),

          Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Section
                        Container(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isOverdue
                                          ? Colors.red[50]
                                          : Colors.blue[50],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      getTimeStatus(),
                                      style: TextStyle(
                                        color: isOverdue
                                            ? Colors.red[700]
                                            : Colors.blue[700],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(Icons.close,
                                        color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Date and Time Section
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 24),
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              // Date Column
                              Expanded(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: isOverdue
                                          ? Colors.red[400]
                                          : Colors.blue[400],
                                      size: 24,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      DateFormat('EEE, MMM dd, yyyy')
                                          .format(scheduleTime),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      'Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: Colors.grey[300],
                              ),
                              // Time Column
                              Expanded(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      color: isOverdue
                                          ? Colors.red[400]
                                          : Colors.blue[400],
                                      size: 24,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      DateFormat('HH:mm').format(scheduleTime),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      'Time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Subtasks Section
                        if (task.subtasks != null) ...[
                          SizedBox(height: 24),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey[200]!),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Icon(Icons.task_alt_rounded,
                                            size: 20, color: Colors.blue[700]),
                                        SizedBox(width: 12),
                                        Text(
                                          'Subtasks',
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Spacer(),
                                        if (task.subtasks.length > 0)
                                          WaveProgressBar(
                                            completed: (task.subtasks)
                                                .where((subtask) =>
                                                    subtask.isDone == true)
                                                .length,
                                            total:
                                                (task.subtasks as List).length,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Divider(height: 1, color: Colors.grey[200]),
                                  // Subtasks List
                                  ReorderableListView.builder(
                                    physics: NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    itemCount: (task.subtasks as List).length,
                                    onReorderStart: (index) {
                                      HapticFeedback.selectionClick();
                                    },
                                    onReorder: (oldIndex, newIndex) {
                                      setState(() {
                                        HapticFeedback.lightImpact();

                                        if (newIndex > oldIndex) {
                                          newIndex -= 1;
                                        }
                                        final item = (task.subtasks as List)
                                            .removeAt(oldIndex);
                                        (task.subtasks as List)
                                            .insert(newIndex, item);

                                        // Update Order Of Subtask
                                        _scheduleService.updateSubtaskOrder(
                                          task.id,
                                          task.subtasks
                                              .map((subtask) => subtask.id)
                                              .toList(),
                                        );
                                      });
                                    },
                                    itemBuilder: (context, index) {
                                      final subtask = (task.subtasks)[index];
                                      final bool isDone = subtask.isDone;

                                      return Material(
                                        key: Key('${subtask.id}'),
                                        color: Colors.transparent,
                                        child: Column(
                                          children: [
                                            if (index != 0)
                                              Divider(
                                                height: 1,
                                                color: Colors.grey[200],
                                              ),
                                            InkWell(
                                              onTap: () {
                                                setState(() {
                                                  subtask.isDone = !isDone;
                                                });
                                                _scheduleService
                                                    .updateSubtaskStatus(
                                                  task.id,
                                                  subtask.id,
                                                  !isDone,
                                                );
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: isDone
                                                      ? Colors.grey[50]
                                                      : Colors.white,
                                                ),
                                                child: Row(
                                                  children: [
                                                    ReorderableDragStartListener(
                                                      index: index,
                                                      child: Padding(
                                                        padding: EdgeInsets
                                                            .symmetric(
                                                                horizontal: 8),
                                                        child: Icon(
                                                          Icons.drag_indicator,
                                                          color:
                                                              Colors.grey[400],
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 12,
                                                      ),
                                                      child: AnimatedContainer(
                                                        duration: Duration(
                                                            milliseconds: 200),
                                                        width: 24,
                                                        height: 24,
                                                        decoration:
                                                            BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                          border: Border.all(
                                                            color: isDone
                                                                ? Colors
                                                                    .green[400]!
                                                                : Colors
                                                                    .grey[400]!,
                                                            width: 2,
                                                          ),
                                                          color: isDone
                                                              ? Colors
                                                                  .green[400]
                                                              : Colors.white,
                                                        ),
                                                        child: isDone
                                                            ? Icon(
                                                                Icons.check,
                                                                size: 16,
                                                                color: Colors
                                                                    .white,
                                                              )
                                                            : null,
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 8,
                                                    ),
                                                    Expanded(
                                                      child:
                                                          AnimatedDefaultTextStyle(
                                                        duration:
                                                            const Duration(
                                                                milliseconds:
                                                                    200),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: isDone
                                                              ? Colors.grey[500]
                                                              : Colors
                                                                  .grey[800],
                                                          decoration: isDone
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : TextDecoration
                                                                  .none,
                                                          fontWeight:
                                                              FontWeight.w400,
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 4),
                                                          child: Text(
                                                            subtask.title,
                                                            textAlign: TextAlign
                                                                .left, // Align text to the left
                                                            style: TextStyle(
                                                                height: 1.2),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    IconButton(
                                                      onPressed: () {
                                                        setState(() {
                                                          (task.subtasks
                                                                  as List)
                                                              .removeAt(index);
                                                          _scheduleService
                                                              .deleteSubtask(
                                                                  task.id,
                                                                  subtask.id);
                                                        });
                                                      },
                                                      icon: Icon(
                                                        Icons.delete,
                                                        color: Colors.red[400],
                                                      ),
                                                      splashColor:
                                                          Colors.grey[200],
                                                      padding:
                                                          EdgeInsets.all(4),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Focus(
                                      onFocusChange: (hasFocus) {
                                        if (hasFocus) {
                                          Future.delayed(
                                              Duration(milliseconds: 300), () {
                                            controller.animateTo(
                                              controller
                                                  .position.maxScrollExtent,
                                              duration:
                                                  Duration(milliseconds: 300),
                                              curve: Curves.easeOut,
                                            );
                                          });
                                        }
                                      },
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller:
                                                  subtaskTitleController,
                                              decoration: InputDecoration(
                                                hintText: 'Add a subtask',
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    borderSide: BorderSide(
                                                      color: Colors.grey[600]!,
                                                    )),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                  horizontal: 18,
                                                  vertical: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(
                                            width: 12,
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () {
                                              if (subtaskTitleController
                                                  .text.isNotEmpty) {
                                                _scheduleService
                                                    .addSubtask(
                                                        task.id,
                                                        subtaskTitleController
                                                            .text)
                                                    .then((newSubtask) {
                                                  setState(() {
                                                    (task.subtasks as List)
                                                        .add(newSubtask);
                                                  });
                                                  subtaskTitleController
                                                      .clear();
                                                }).catchError((error) {
                                                  // Handle error
                                                });
                                              }
                                            },
                                            label: Icon(Icons.add),
                                          )
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Details Section
                        Container(
                          margin: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Details',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[900],
                                ),
                              ),
                              SizedBox(height: 16),

                              // Grid of Quick Info Cards
                              GridView.count(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 1.5,
                                children: [
                                  // Priority Card
                                  _buildInfoCard(
                                    icon: Icons.flag_rounded,
                                    iconColor: _getPriorityColor(task.priority),
                                    bgColor: _getPriorityColor(task.priority)
                                        .withOpacity(0.1),
                                    title: 'Priority',
                                    value: task.priority.toUpperCase(),
                                  ),

                                  // Created Date Card
                                  _buildInfoCard(
                                    icon: Icons.calendar_today_rounded,
                                    iconColor: Colors.indigo[700]!,
                                    bgColor: Colors.indigo[50]!,
                                    title: 'Created',
                                    value: task.createdAt != null
                                        ? DateFormat('MMM dd, yyyy')
                                            .format(task.createdAt!)
                                        : 'Not specified',
                                  ),

                                  // Emotion Card
                                  if (task.emotion != null)
                                    _buildInfoCard(
                                      icon: Icons.mood,
                                      iconColor: Colors.amber[700]!,
                                      bgColor: Colors.amber[50]!,
                                      title: 'Mood',
                                      value: task.emotion!,
                                    ),

                                  // Category Card
                                  _buildInfoCard(
                                    icon: Icons.category_rounded,
                                    iconColor: Colors.blue[700]!,
                                    bgColor: Colors.blue[50]!,
                                    title: 'Category',
                                    value: task.category,
                                  ),
                                ],
                              ),

                              SizedBox(height: 16),

                              // Repetition Section
                              if (task.isRepeated) ...[
                                _buildDetailCard(
                                  title: 'Repetition',
                                  icon: Icons.repeat_rounded,
                                  iconColor: Colors.green[700]!,
                                  bgColor: Colors.green[50]!,
                                  content: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.timer_outlined,
                                            size: 16,
                                            color: Colors.grey[600],
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              // 'Repeats ${task.repeatInterval} (${task.repeatedIntervalTime} times)',
                                              RepeatTaskParser
                                                  .parseRepeatInterval(
                                                      task.repeatInterval,
                                                      task.repeatedIntervalTime!),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                              softWrap: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (task.completedAt != null) ...[
                                        SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.check_circle_outline,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Last completed: ${DateFormat('MMM dd, yyyy').format(task.completedAt!)}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[800],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                SizedBox(height: 12),
                              ],

                              // Location Section with ETA Comparison
                              if (task.placeURL != null &&
                                  task.placeURL.isNotEmpty)
                                _buildDetailCard(
                                  title: 'Location',
                                  icon: Icons.location_on_rounded,
                                  iconColor: Colors.red[700]!,
                                  bgColor: Colors.red[50]!,
                                  content: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: () async {
                                          final uri = Uri.parse(task.placeURL!);
                                          if (await canLaunchUrl(uri)) {
                                            await launchUrl(uri,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                extractPlaceName(task.placeURL),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.blue[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Icon(
                                              Icons.open_in_new,
                                              size: 16,
                                              color: Colors.blue[700],
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      // ETA and time comparison
                                      FutureBuilder<String>(
                                        future: getETAString(
                                            extractPlaceId(task.placeURL)),
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 8.0),
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                          strokeWidth: 2),
                                                ),
                                              ),
                                            );
                                          } else if (snapshot.hasData &&
                                              snapshot.data!.isNotEmpty) {
                                            final etaString = snapshot.data!;

                                            // Improved parsing for travel time
                                            int etaMinutes =
                                                parseEtaString(etaString);

                                            // Calculate ETA time
                                            final now = DateTime.now();
                                            final etaTime = now.add(
                                                Duration(minutes: etaMinutes));

                                            // Compare with task due time
                                            final dueTime = task.time;

                                            // Display ETA information
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.directions_car,
                                                        size: 14,
                                                        color:
                                                            Colors.grey[600]),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Travel time: $etaString',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(Icons.access_time,
                                                        size: 14,
                                                        color:
                                                            Colors.grey[600]),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'ETA: ${DateFormat('h:mm a').format(etaTime)}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Only show comparison if task has a due time
                                                if (dueTime != null) ...[
                                                  SizedBox(height: 8),
                                                  Builder(builder: (context) {
                                                    final difference = dueTime
                                                        .difference(etaTime);
                                                    final differenceInMinutes =
                                                        difference.inMinutes;

                                                    final Color statusColor =
                                                        differenceInMinutes < 0
                                                            ? Colors.red[700]!
                                                            : (differenceInMinutes <
                                                                    30
                                                                ? Colors.orange[
                                                                    700]!
                                                                : Colors.green[
                                                                    700]!);

                                                    final String statusText =
                                                        differenceInMinutes < 0
                                                            ? 'Late'
                                                            : (differenceInMinutes <
                                                                    30
                                                                ? 'Just in time)'
                                                                : 'On time');

                                                    return Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: statusColor
                                                            .withOpacity(0.15),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            differenceInMinutes <
                                                                    0
                                                                ? Icons
                                                                    .warning_rounded
                                                                : (differenceInMinutes < 30
                                                                    ? Icons
                                                                        .timelapse_rounded
                                                                    : Icons
                                                                        .check_circle_rounded),
                                                            size: 14,
                                                            color: statusColor,
                                                          ),
                                                          SizedBox(width: 4),
                                                          Text(
                                                            statusText,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color:
                                                                  statusColor,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                ],
                                              ],
                                            );
                                          } else {
                                            return SizedBox.shrink();
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                              // URL Section (if exists)
                              if (task.url != null && task.url.isNotEmpty) ...[
                                SizedBox(height: 12),
                                _buildDetailCard(
                                  title: 'Related Link',
                                  icon: Icons.link_rounded,
                                  iconColor: Colors.teal[700]!,
                                  bgColor: Colors.teal[50]!,
                                  content: LinkPreview(
                                    text: task.url,
                                    onPreviewDataFetched: (previewData) {
                                      setState(() {
                                        dataLink =
                                            previewData; // Set fetched data
                                      });
                                    },
                                    onLinkPressed: (link) async {
                                      final uri = Uri.parse(link);
                                      try {
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        } else {
                                          throw 'Could not launch $link';
                                        }
                                      } catch (e) {
                                        print('Error launching URL: $e');
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Could not open the link. Please try again later.'),
                                          ),
                                        );
                                      }
                                    },
                                    previewData: dataLink,
                                    width: MediaQuery.of(context).size.width,
                                  ),
                                ),
                              ],
                              if (task.files.isNotEmpty) ...[
                                SizedBox(height: 12),
                                _buildDetailCard(
                                  title: 'Attachments',
                                  icon: Icons.attach_file_rounded,
                                  iconColor: Colors.purple[700]!,
                                  bgColor: Colors.purple[50]!,
                                  content: Column(
                                    children: [
                                      ...task.files
                                          .map((file) => _buildFileCard(file))
                                          .toList(),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Action Buttons

                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _editSchedule(task);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    backgroundColor: Colors.blue[600],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit_outlined, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Edit Schedule',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    _scheduleService.updateTaskCompletion(
                                        task.id, true);
                                    Navigator.pop(context);
                                    _showCelebrationAnimation();
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(vertical: 16),
                                    foregroundColor: Colors.green[700],
                                    side: BorderSide(color: Colors.green[700]!),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline,
                                          size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Completed',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 20,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  // Helper widget for info cards
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(6), // Reduced padding
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          SizedBox(height: 8), // Reduced spacing
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 2), // Reduced spacing
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

// Helper widget for detail cards
  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Widget content,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

// Modified _buildFileCard method
  Widget _buildFileCard(TaskFile file) {
    IconData getFileIcon(String type) {
      switch (type) {
        case 'image':
          return Icons.image_rounded;
        case 'pdf':
          return Icons.picture_as_pdf_rounded;
        case 'document':
          return Icons.description_rounded;
        default:
          return Icons.insert_drive_file_rounded;
      }
    }

    Color getFileColor(String type) {
      switch (type) {
        case 'image':
          return Colors.purple;
        case 'pdf':
          return Colors.red;
        case 'document':
          return Colors.blue;
        default:
          return Colors.grey;
      }
    }

    final Color fileColor = getFileColor(file.type);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: fileColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fileColor.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InAppViewer(
                  url: file.url,
                  type: file.type,
                  title: file.name,
                ),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: fileColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    getFileIcon(file.type),
                    color: fileColor,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Added ${DateFormat.yMMMd().format(file.uploadedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons
                      .open_in_browser_rounded, // Changed icon to indicate in-app opening
                  color: fileColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

// Helper function for priority colors
  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red[700]!;
      case 'medium':
        return Colors.orange[700]!;
      case 'low':
        return Colors.green[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  // Extract the place name from URL
  String extractPlaceName(String url) {
    final RegExp regExp = RegExp(r"(?<=query=)(.*?)(?=&|$)");
    final match = regExp.firstMatch(url);
    if (match != null) {
      return Uri.decodeComponent(match.group(0) ?? 'Unknown Place');
    } else {
      return 'Unknown Place';
    }
  }

  String extractPlaceId(String url) {
    final RegExp regExp = RegExp(r"(?<=place_id=)(.*?)(?=&|$)");
    final match = regExp.firstMatch(url);
    if (match != null) {
      return match.group(0) ?? 'Unknown Place ID';
    } else {
      return 'Unknown Place ID';
    }
  }

  // Parse Google Maps duration strings
  int parseEtaString(String etaString) {
    // Handle empty or null strings
    if (etaString.isEmpty) {
      return 0;
    }

    int totalMinutes = 0;

    // Handle hours
    if (etaString.contains("hour") || etaString.contains("hr")) {
      // Extract hours
      final hourRegex = RegExp(r'(\d+)\s*(?:hour|hr)');
      final hourMatch = hourRegex.firstMatch(etaString);
      if (hourMatch != null) {
        final hours = int.tryParse(hourMatch.group(1) ?? '0') ?? 0;
        totalMinutes += hours * 60;
      }
    }

    // Extract minutes - handling variations like "min", "mins", "minute", "minutes"
    final minuteRegex = RegExp(r'(\d+)\s*(?:min|mins|minute|minutes)');
    final minuteMatch = minuteRegex.firstMatch(etaString);
    if (minuteMatch != null) {
      final minutes = int.tryParse(minuteMatch.group(1) ?? '0') ?? 0;
      totalMinutes += minutes;
    }

    return totalMinutes;
  }

  // ----------------------- EDIT SCHEDULE ----------------------

  void _editSchedule(Task task) {
    _titleController.text = task.title;
    _urlController.text = task.url ?? '';
    _locationController.text = task.placeURL ?? '';
    _selectedCategory = task.category;
    _selectedDateTime = task.time;
    _selectedPriority = task.priority;
    _selectedRepeatInterval = task.repeatInterval;
    _isRepeatEnabled = task.isRepeated;
    _repeatedIntervalTime = task.repeatedIntervalTime ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            // Clear fields when back button is pressed
            _clearFields();
            return true;
          },
          child: EditScheduleSheet(
            taskId: task.id,
            titleController: _titleController,
            urlController: _urlController,
            placeUrlController: _locationController,
            selectedCategory: _selectedCategory!,
            selectedDateTime: _selectedDateTime!,
            priority: _selectedPriority,
            isRepeatEnabled: _isRepeatEnabled,
            selectedRepeatInterval: _selectedRepeatInterval,
            repeatedIntervalTime: _repeatedIntervalTime ?? 0,
            subtasks: task.subtasks ?? [],
            files: task.files ?? [],
            onUpdate: (title, category, url, placeURL, time, priority, isRepeat,
                repeatInterval, repeatedIntervalTime, subtasks, files) async {
              try {
                // Show loading dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return WillPopScope(
                      onWillPop: () async =>
                          false, // Prevent back button dismissal
                      child: Dialog(
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
                              // Schedule Icon
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.schedule_rounded,
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
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.blue),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Loading Text
                              const Text(
                                'Updating Schedule',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Please wait while we save your schedule...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );

                // Perform the update operation
                await _scheduleService.updateSchedule(
                  id: task.id,
                  title: title,
                  category: category,
                  url: url,
                  placeURL: placeURL,
                  time: time,
                  priority: priority,
                  isRepeated: isRepeat,
                  repeatInterval: repeatInterval,
                  repeatedIntervalTime: repeatedIntervalTime,
                  subtasks: subtasks,
                  files: files,
                );

                // Only proceed if the context is still valid
                if (context.mounted) {
                  _clearFields(); // Clear fields after successful update
                  Navigator.pop(context); // Dismiss the loading dialog
                  Navigator.pop(context);
                  SuccessToast.show(context, 'Updated Successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorToast.show(context, 'Failed to update schedule: $e');
                }
              }
            },
          ),
        );
      },
    ).whenComplete(() {
      // Clear fields when bottom sheet is closed by any means
      _clearFields();
    });
  }

  // Helper method to clear all fields
  void _clearFields() {
    _titleController.clear();
    _urlController.clear();
    _locationController.clear();
    setState(() {
      _selectedCategory = 'Other';
      _selectedDateTime = DateTime.now().copyWith(hour: 23, minute: 59);
      _selectedPriority = 'Medium';
      _isRepeatEnabled = false;
      _selectedRepeatInterval = 'Daily';
      _repeatedIntervalTime = 0;
    });
  }

  Future<void> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        setState(() {
          _selectedDateTime =
              DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }
}
