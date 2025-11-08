import 'dart:ui';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/screens/task_details_screen.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';

class EisenhowerMatrixScreen extends StatefulWidget {
  @override
  State<EisenhowerMatrixScreen> createState() => _EisenhowerMatrixScreenState();
}

class _EisenhowerMatrixScreenState extends State<EisenhowerMatrixScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final ScheduleService scheduleService = ScheduleService();

  // Define priority mapping
  final Map<String, String> quadrantToPriority = {
    'URGENT': 'high',
    'IMPORTANT': 'medium',
    'DELEGATE': 'low',
    'ELIMINATE': 'none',
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleDragEnd(Task task, String newQuadrant) async {
    final newPriority = quadrantToPriority[newQuadrant]!;
    if (task.priority != newPriority) {
      await scheduleService.updateTaskPriority(task.id, newPriority);
      HapticFeedback.mediumImpact();

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Task moved to $newQuadrant'),
      //     backgroundColor: Colors.green[400],
      //     behavior: SnackBarBehavior.floating,
      //     shape: RoundedRectangleBorder(
      //       borderRadius: BorderRadius.circular(10),
      //     ),
      //     duration: Duration(seconds: 2),
      //   ),
      // );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // Remove shadow
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: 10, sigmaY: 10), // Frosted glass effect
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1), // Subtle white overlay
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
              "Eisenhower Matrix",
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
          color: Colors.green.shade700, // Match icon color to the nature theme
        ),
        // title: Text(
        //   'Eisenhower Matrix',
        //   style: TextStyle(fontWeight: FontWeight.bold),
        // ),
        actions: [
          IconButton(
            icon: Icon(Icons.insights, color: Colors.green),
            onPressed: () {
              // Show insights/analytics
              _showEisenhowerInfo(context);
            },
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // Add background image here
          image: DecorationImage(
            image: AssetImage('assets/images/background.png'),
            fit: BoxFit.cover,
            // Optional: Add opacity overlay to ensure UI elements remain visible
            // colorFilter: ColorFilter.mode(
            //   Colors.white.withOpacity(0.8),
            //   BlendMode.lighten,
            // ),
          ),
        ),
        child: StreamBuilder<List<Task>>(
          stream: scheduleService.getSchedules(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[900]!),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: TextStyle(color: Colors.blue[900]),
                    ),
                  ],
                ),
              );
            }

            final tasks = snapshot.data ?? [];
            final categorizedTasks = _categorizeTasks(tasks);

            return FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth / 2;
                  final cardHeight = (constraints.maxHeight / 2) - 30;

                  return SingleChildScrollView(
                    child: Wrap(
                      children: [
                        _buildDraggableQuadrant(
                          'URGENT',
                          categorizedTasks["high"] ?? [],
                          Colors.red[100]!,
                          Colors.red[700]!,
                          cardWidth,
                          cardHeight,
                        ),
                        _buildDraggableQuadrant(
                          'IMPORTANT',
                          categorizedTasks["medium"] ?? [],
                          Colors.orange[100]!,
                          Colors.orange[700]!,
                          cardWidth,
                          cardHeight,
                        ),
                        _buildDraggableQuadrant(
                          'DELEGATE',
                          categorizedTasks["low"] ?? [],
                          Colors.green[100]!,
                          Colors.green[700]!,
                          cardWidth,
                          cardHeight,
                        ),
                        _buildDraggableQuadrant(
                          'ELIMINATE',
                          categorizedTasks["none"] ?? [],
                          Colors.grey[100]!,
                          Colors.grey[700]!,
                          cardWidth,
                          cardHeight,
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildQuadrantInfoItem(
    BuildContext context,
    String title,
    String action,
    String description,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 12), // Spacing between items
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        // Use a light shade of the color for background for subtle distinction
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // Align items to the top
        children: [
          // Icon and Action Word
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              SizedBox(height: 6),
              Text(
                action,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(width: 12), // Spacing between icon/action and text

          // Title and Description (Takes remaining space)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // Align text left
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title, // Quadrant Title
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  description, // Full description, allows wrapping
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black54,
                    height: 1.3, // Improve line spacing for readability
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEisenhowerInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
              horizontal: 16, vertical: 24), // Adjust padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    // Use a gradient for a nicer look
                    gradient: LinearGradient(
                      colors: [Colors.blue[700]!, Colors.blue[900]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'The Eisenhower Matrix',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Scrollable Content Area
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Subtitle
                        Text(
                          'Prioritize tasks based on urgency and importance.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.blue[800], // Slightly darker blue
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 20),

                        _buildQuadrantInfoItem(
                          context,
                          'Urgent & Important',
                          'DO NOW',
                          'Handle these tasks immediately. They are critical and time-sensitive.',
                          Colors.red[600]!,
                          Icons.priority_high,
                        ),
                        _buildQuadrantInfoItem(
                          context,
                          'Important, Not Urgent',
                          'SCHEDULE',
                          'Plan dedicated time for these tasks. They contribute to long-term goals.',
                          Colors.orange[700]!,
                          Icons.calendar_today,
                        ),
                        _buildQuadrantInfoItem(
                          context,
                          'Urgent, Not Important',
                          'DELEGATE',
                          'Assign these tasks to others if possible. They need doing but don\'t require your specific skills.',
                          Colors.green[600]!,
                          Icons.people_alt_outlined,
                        ),

                        _buildQuadrantInfoItem(
                          context,
                          'Not Urgent or Important',
                          'ELIMINATE',
                          'Remove these tasks from your list. They are distractions and offer little value.',
                          Colors.grey[600]!, // Slightly darker Grey
                          Icons.delete_sweep_outlined, // Different icon?
                        ),

                        SizedBox(height: 16),
                        // Quote
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Eisenhower: "What is important is seldom urgent and what is urgent is seldom important."',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 13,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer with Close Button
                Padding(
                  padding: EdgeInsets.only(bottom: 16, top: 8),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 35, vertical: 12),
                    ),
                    child: Text('Got it!', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDraggableQuadrant(
    String title,
    List<Task> tasks,
    Color backgroundColor,
    Color textColor,
    double width,
    double height,
  ) {
    bool wasHovering = false;

    // Map quadrant titles to corresponding background images
    final Map<String, String> quadrantBackgroundImages = {
      'ELIMINATE': 'assets/images/plant_eliminate.png',
      'DELEGATE': 'assets/images/plant_delegate.png',
      'IMPORTANT': 'assets/images/plant_important.png',
      'URGENT': 'assets/images/plant_urgent.png',
    };

    return DragTarget<Task>(
      onWillAccept: (task) {
        if (!wasHovering) {
          HapticFeedback.mediumImpact();
          wasHovering = true;
        }
        return task != null && task.priority != quadrantToPriority[title];
      },
      onLeave: (task) {
        wasHovering = false;
      },
      onAccept: (task) {
        _handleDragEnd(task, title);
        wasHovering = false;
        HapticFeedback.mediumImpact();
      },
      builder: (context, candidateData, rejectedData) {
        // Check if there's an active drag operation
        final isHovering = candidateData.isNotEmpty;

        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          width: width,
          height: height,
          child: Card(
            // Make the Card itself fully transparent
            color: Colors.transparent,
            margin: EdgeInsets.all(8),
            elevation: isHovering ? 8 : 4, // Increase elevation when hovering
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: isHovering
                  ? BorderSide(
                      color: textColor.withOpacity(0.5),
                      width: 2,
                    )
                  : BorderSide.none,
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                // Apply semi-transparency to the background
                color: isHovering
                    ? backgroundColor.withOpacity(0.15)
                    : Colors.white.withOpacity(
                        0.7), // Make the container semi-transparent
                image: quadrantBackgroundImages[title] != null
                    ? DecorationImage(
                        image: AssetImage(quadrantBackgroundImages[title]!),
                        alignment: Alignment.bottomRight,
                        fit: BoxFit.none,
                        opacity: 0.3, // Semi-transparent background image
                        scale: 10,
                      )
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQuadrantHeader(
                      title, tasks.length, backgroundColor, textColor),
                  Expanded(
                    child: Stack(
                      children: [
                        tasks.isEmpty
                            ? _buildEmptyState()
                            : SingleChildScrollView(
                                child: Column(
                                  children: tasks.asMap().entries.map((entry) {
                                    return LongPressDraggable<Task>(
                                      data: entry.value,
                                      delay: Duration(milliseconds: 500),
                                      feedback: Material(
                                        elevation: 4,
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.4,
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            entry.value.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.5,
                                        child: TaskItem(
                                          key: ValueKey(entry.value.id),
                                          task: entry.value,
                                          onComplete: () =>
                                              _handleTaskComplete(entry.value),
                                          textColor: textColor,
                                        ),
                                      ),
                                      onDragStarted: () {
                                        HapticFeedback.mediumImpact();
                                      },
                                      child: TaskItem(
                                        key: ValueKey(entry.value.id),
                                        task: entry.value,
                                        onComplete: () =>
                                            _handleTaskComplete(entry.value),
                                        textColor: textColor,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                        // Show drop indicator when hovering
                        if (isHovering)
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: textColor.withOpacity(0.2),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                            ),
                            margin: EdgeInsets.all(8),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuadrantHeader(
      String title, int taskCount, Color backgroundColor, Color textColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [backgroundColor, backgroundColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '$taskCount',
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 32,
            color: Colors.grey.withOpacity(0.5),
          ),
          SizedBox(height: 8),
          Text(
            'No Tasks Here',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(
      List<Task> tasks, Color textColor, String quadrantTitle) {
    return ListView.builder(
      key: PageStorageKey<String>(quadrantTitle),
      padding: EdgeInsets.symmetric(vertical: 4),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        return Draggable<Task>(
          data: tasks[index],
          feedback: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.4,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tasks[index].title,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: TaskItem(
              key: ValueKey(tasks[index].id),
              task: tasks[index],
              onComplete: () => _handleTaskComplete(tasks[index]),
              textColor: textColor,
            ),
          ),
          child: TaskItem(
            key: ValueKey(tasks[index].id),
            task: tasks[index],
            onComplete: () => _handleTaskComplete(tasks[index]),
            textColor: textColor,
          ),
        );
      },
    );
  }

  Future<void> _handleTaskComplete(Task task) async {
    await scheduleService.updateTaskCompletion(task.id, true);
    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task marked as done.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            scheduleService.updateTaskCompletion(task.id, false);
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
  }

  Map<String, List<Task>> _categorizeTasks(List<Task> tasks) {
    final categorized = <String, List<Task>>{
      'high': [],
      'medium': [],
      'low': [],
      'none': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // First pass: filter and process repeated tasks
    final Map<String, Task> nearestRepeatedTasks = {};

    for (final task in tasks) {
      if (task.done) continue;

      final taskDate = task.time;

      // Skip future repeated tasks (except today's)
      if (task.isRepeated && taskDate != null) {
        if (taskDate.isAfter(today)) continue;

        // For repeated tasks, track the nearest one by ID or another unique identifier
        final taskIdentifier = task.id; // Task has an ID field

        if (nearestRepeatedTasks.containsKey(taskIdentifier)) {
          final existingTask = nearestRepeatedTasks[taskIdentifier]!;
          // Keep the nearest one to today (but not in the future)
          if (taskDate.isAfter(existingTask.time!) &&
              !taskDate.isAfter(today)) {
            nearestRepeatedTasks[taskIdentifier] = task;
          }
        } else {
          nearestRepeatedTasks[taskIdentifier] = task;
        }

        continue; // Skip repeated tasks in this first pass
      }

      // Process non-repeated tasks normally
      String priority = task.priority.toLowerCase();
      if (categorized.containsKey(priority)) {
        categorized[priority]!.add(task);
      } else {
        categorized['none']!.add(task);
      }
    }

    // Add the filtered repeated tasks to the appropriate categories
    for (final repeatedTask in nearestRepeatedTasks.values) {
      String priority = repeatedTask.priority.toLowerCase();
      if (categorized.containsKey(priority)) {
        categorized[priority]!.add(repeatedTask);
      } else {
        categorized['none']!.add(repeatedTask);
      }
    }

    return categorized;
  }
}

class TaskItem extends StatefulWidget {
  final Task task;
  final VoidCallback onComplete;
  final Color textColor;

  const TaskItem({
    required this.task,
    required this.onComplete,
    required this.textColor,
    Key? key,
  }) : super(key: key);

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isCompleting = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Interval(0.8, 1.0, curve: Curves.easeOut),
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (_isCompleting) return;

    setState(() {
      _isCompleting = true;
    });

    _animationController.forward();
    await Future.delayed(const Duration(milliseconds: 1200));
    widget.onComplete();
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

  @override
  Widget build(BuildContext context) {
    final isOverdue = widget.task.time?.isBefore(DateTime.now()) ?? false;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: InkWell(
        onTap: () {
          // Open task details
          _navigateToTaskDetails(widget.task);
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _handleComplete,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _isCompleting
                      ? Icon(
                          Icons.check_box,
                          size: 18,
                          color: widget.textColor,
                          key: ValueKey('checked'),
                        )
                      : Icon(
                          Icons.check_box_outline_blank,
                          size: 18,
                          color: Colors.grey[400],
                          key: ValueKey('unchecked'),
                        ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.task.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: isOverdue ? Colors.red[700] : Colors.black87,
                        height: 1.2,
                        decoration:
                            _isCompleting ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.black54,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.task.time != null) ...[
                      SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, HH:mm').format(widget.task.time!),
                        style: TextStyle(
                          fontSize: 10,
                          color: isOverdue ? Colors.red[400] : Colors.grey[600],
                          fontWeight:
                              isOverdue ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
