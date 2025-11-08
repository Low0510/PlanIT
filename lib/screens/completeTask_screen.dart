import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/screens/task_details_screen.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:collection/collection.dart';

class CompletedTasksScreen extends StatefulWidget {
  @override
  State<CompletedTasksScreen> createState() => _CompletedTasksScreenState();
}

class _CompletedTasksScreenState extends State<CompletedTasksScreen>
    with SingleTickerProviderStateMixin {
  final ScheduleService _scheduleService = ScheduleService();
  bool _showCompletedTasks = true;
  late AnimationController _animationController;

  bool _showTimelineView = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/background.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // Gradient overlay for transparency effect
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.1), // More transparent at top
                  Colors.white.withOpacity(0.7), // More opaque at bottom
                ],
              ),
            ),
          ),
          // Content
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(),
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                sliver: _determineContentView(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180.0,
      floating: false,
      pinned: true,
      stretch: true,
      backgroundColor: Colors.brown.shade300,
      actions: [
        // Simplified toggle button with only two states
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.brown.shade400,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24, width: 1),
            ),
            child: Tooltip(
              message: _showTimelineView
                  ? 'Show Today\'s Accomplishments'
                  : 'Show Timeline View',
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showTimelineView = !_showTimelineView;
                    // Toggle between Today and Timeline views
                    _showCompletedTasks = !_showTimelineView;
                    if (_showCompletedTasks) {
                      _animationController.forward();
                    } else {
                      _animationController.reverse();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        _showTimelineView ? Icons.today : Icons.timeline,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 6),
                      Text(
                        _showTimelineView ? 'Today' : 'Timeline',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          _showTimelineView ? 'Task Timeline' : 'Accomplished Today',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
            ],
          ),
        ),
        centerTitle: true,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.brown.shade300.withOpacity(0.4),
                Colors.amber.shade200.withOpacity(0.3),
              ],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Decorative elements
              _buildDecorativeCircles(),

              // Main icon
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Icon(
                    _showTimelineView ? Icons.timeline : Icons.emoji_events,
                    key: ValueKey<String>(
                        _showTimelineView ? 'timeline' : 'today'),
                    size: 70,
                    color: Colors.amber.shade300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _determineContentView() {
    // Show timeline view only when viewing all completed tasks AND timeline toggle is on
    if (!_showCompletedTasks && _showTimelineView) {
      return _buildTaskTimelineView();
    } else {
      return _buildTasksList();
    }
  }

  Widget _buildDecorativeCircles() {
    return Stack(
      children: [
        Positioned(
          right: -40,
          top: -40,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          left: -60,
          bottom: -60,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),
        // Add subtle pattern
        ...List.generate(10, (index) {
          return Positioned(
            left: (index * 40.0) % MediaQuery.of(context).size.width,
            top: (index * 25.0) % 200,
            child: Opacity(
              opacity: 0.05,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTasksList() {
    return StreamBuilder<List<Task>>(
      stream: _showCompletedTasks
          ? _scheduleService.getCompletedSchedulesForToday()
          : _scheduleService.getSchedulesByCompletionStatus(isCompleted: true),
      builder: (context, AsyncSnapshot<List<Task>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80.0),
                child: CircularProgressIndicator(color: Colors.indigo.shade700),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline,
                        size: 60, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading tasks',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final List<Task> completedTasks = snapshot.data ?? [];

        if (completedTasks.isEmpty) {
          return SliverToBoxAdapter(child: _buildEmptyState());
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final task = completedTasks[index];
              return _buildTaskItem(
                  context, task, index, completedTasks.length);
            },
            childCount: completedTasks.length,
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lotties/empty_task_completed.json',
              height: 300,
            ),
            const SizedBox(height: 24),
            Text(
              _showCompletedTasks
                  ? 'No tasks completed today'
                  : 'No completed tasks found',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              _showCompletedTasks
                  ? 'Your accomplishments will appear here'
                  : 'Complete tasks to see them here',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.add_task),
              label: Text('Add a new task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(
      BuildContext context, Task task, int index, int totalTasks) {
    final completedAt = task.completedAt;
    final dueTime = task.time;
    final createdAt = task.createdAt;
    final category = task.category ?? 'Uncategorized';
    final priority = task.priority ?? 'Normal';

    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeIndicator(createdAt!),
          const SizedBox(width: 8),
          Expanded(
            child: TimelineTile(
              alignment: TimelineAlign.manual,
              lineXY: 0.1,
              isFirst: index == 0,
              isLast: index == totalTasks - 1,
              indicatorStyle: IndicatorStyle(
                width: 30,
                color: _getCategoryColor(category),
                padding: const EdgeInsets.all(6),
                iconStyle: IconStyle(
                  color: Colors.white,
                  iconData: _getCategoryIcon(category),
                  fontSize: 16,
                ),
              ),
              beforeLineStyle: LineStyle(
                color: Colors.grey.shade300,
                thickness: 2,
              ),
              endChild: _buildTaskCard(
                  context, task, completedAt!, dueTime, category, priority),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeIndicator(DateTime completedAt) {
    return Container(
      width: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('HH:mm').format(completedAt),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade700,
            ),
          ),
          Text(
            DateFormat('MMM d').format(completedAt),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task, DateTime completedAt,
      DateTime dueTime, String category, String priority) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsScreen(task: task),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 0, top: 8, bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.05),
                Colors.white.withOpacity(0.15),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: _getPriorityColor(priority),
                width: 4,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        task.title ?? 'Untitled Task',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade800,
                        ),
                        // maxLines: 1,
                        // overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildInfoText('Due Time', dueTime, isCompleted: false),
                    _buildInfoText(
                      'Completed',
                      completedAt,
                      isCompleted: true,
                      dueTime: dueTime,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoText(String label, DateTime dateTime,
      {bool isCompleted = false, DateTime? dueTime}) {
    Color textColor = Colors.grey.shade800;
    IconData? icon;

    if (isCompleted && dueTime != null) {
      final bool isLate = dateTime.isAfter(dueTime);
      textColor = isLate ? Colors.red.shade700 : Colors.green.shade700;
      icon = isLate ? Icons.timer_off : Icons.check_circle;
    }

    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: textColor),
          SizedBox(width: 4),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text(
              DateFormat('MMM d, HH:mm').format(dateTime),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
            ),
          ],
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue.shade700;
      case 'personal':
        return Colors.green.shade600;
      case 'health':
        return Colors.red.shade600;
      case 'education':
        return Colors.orange.shade600;
      case 'entertainment':
        return Colors.purple.shade500;
      default:
        return Colors.blueGrey.shade600;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work;
      case 'personal':
        return Icons.person;
      case 'health':
        return Icons.favorite;
      case 'education':
        return Icons.school;
      case 'entertainment':
        return Icons.movie;
      default:
        return Icons.category;
    }
  }

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

  Widget _buildTaskTimelineView() {
    return StreamBuilder<List<Task>>(
      stream: _scheduleService.getAllCompletedTasks(),
      builder: (context, AsyncSnapshot<List<Task>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80.0),
                child: CircularProgressIndicator(color: Colors.indigo.shade700),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 80.0),
                child: Column(
                  children: [
                    Icon(Icons.error_outline,
                        size: 60, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading tasks',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final List<Task> completedTasks = snapshot.data ?? [];

        if (completedTasks.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyStateForTimeline('your journey',
                isSelectedDate: false),
          );
        }

        // Group tasks by date
        final groupedTasks = groupBy(completedTasks,
            (Task task) => DateFormat('yyyy-MM-dd').format(task.completedAt!));

        // Sort dates in descending order (newest first)
        final sortedDates = groupedTasks.keys.toList()
          ..sort((a, b) => b.compareTo(a));

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final dateKey = sortedDates[index];
              final tasksForDate = groupedTasks[dateKey]!;
              final date = DateTime.parse(dateKey);

              return _buildDateSection(date, tasksForDate);
            },
            childCount: sortedDates.length,
          ),
        );
      },
    );
  }

  Widget _buildDateSection(DateTime date, List<Task> tasks) {
    final isToday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;

    final isYesterday = date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day - 1;

    String dateHeader;
    if (isToday) {
      dateHeader = 'Today';
    } else if (isYesterday) {
      dateHeader = 'Yesterday';
    } else {
      dateHeader = DateFormat('EEEE, MMMM d, yyyy').format(date);
    }

    // Calculate completion percentage
    final totalTasks = tasks.length;
    final onTimeCompletions = tasks
        .where((task) =>
            task.completedAt != null &&
            task.time != null &&
            !task.completedAt!.isAfter(task.time!))
        .length;

    final completionPercentage =
        totalTasks > 0 ? (onTimeCompletions / totalTasks * 100).round() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isToday ? Colors.indigo.shade700 : Colors.indigo.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dateHeader,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isToday ? Colors.white : Colors.indigo.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 2,
                  color: Colors.grey.shade300,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(
                  '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(left: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          _getCompletionColor(completionPercentage),
                      child: Text(
                        '$completionPercentage%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getCompletionMessage(completionPercentage),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...tasks
                    .map((task) => _buildTaskCardTimeline(context, task))
                    .toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getCompletionMessage(int percentage) {
    if (percentage >= 90)
      return 'Excellent! Almost all tasks completed on time.';
    if (percentage >= 75) return 'Great job! Most tasks completed on time.';
    if (percentage >= 50) return 'Good effort! Half or more tasks on time.';
    if (percentage >= 25) return 'Room for improvement on timely completion.';
    return 'Focus on completing tasks before deadlines.';
  }

  Color _getCompletionColor(int percentage) {
    if (percentage >= 90) return Colors.green.shade700;
    if (percentage >= 75) return Colors.green.shade500;
    if (percentage >= 50) return Colors.amber.shade600;
    if (percentage >= 25) return Colors.orange.shade700;
    return Colors.red.shade600;
  }

  Widget _buildTaskCardTimeline(BuildContext context, Task task) {
    final category = task.category ?? 'Uncategorized';
    final priority = task.priority ?? 'Normal';
    final isLate = task.completedAt != null &&
        task.time != null &&
        task.completedAt!.isAfter(task.time!);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailsScreen(task: task),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: _getPriorityColor(priority),
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    size: 20,
                    color: _getCategoryColor(category),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              task.title ?? 'Untitled Task',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                isLate ? Icons.timer_off : Icons.check_circle,
                                size: 14,
                                color: isLate
                                    ? Colors.red.shade700
                                    : Colors.green.shade700,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                DateFormat('HH:mm').format(task.completedAt!),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isLate
                                      ? Colors.red.shade700
                                      : Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  _getCategoryColor(category).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _getCategoryColor(category),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  _getPriorityColor(priority).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              priority,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _getPriorityColor(priority),
                              ),
                            ),
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
      ),
    );
  }

  Widget _buildEmptyStateForTimeline(String dateText,
      {required bool isSelectedDate}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/lotties/empty_task_completed.json',
              height: 300,
            ),
            const SizedBox(height: 24),
            Text(
              isSelectedDate
                  ? 'No completed tasks on this day'
                  : 'No completed tasks yet',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Text(
              isSelectedDate
                  ? 'Completed tasks will appear here'
                  : 'Start completing tasks to track $dateText',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.add_task),
              label: const Text('Add a new task'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo.shade700,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
