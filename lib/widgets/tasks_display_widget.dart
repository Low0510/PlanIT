import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/screens/task_details_screen.dart';
import 'package:intl/intl.dart';

class TasksDisplayModal extends StatefulWidget {
  final DateTime date;
  final List<Task> tasks;

  const TasksDisplayModal({
    Key? key,
    required this.date,
    required this.tasks,
  }) : super(key: key);

  @override
  TasksDisplayModalState createState() => TasksDisplayModalState();
}

class TasksDisplayModalState extends State<TasksDisplayModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Animation<double>> _taskAnimations;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600), // Slightly faster animations
    );

    // Create staggered animations for tasks
    _taskAnimations = List.generate(
      widget.tasks.length,
      (index) => Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.08, // Slightly faster staggering
            index * 0.08 + 0.4,
            curve: Curves.easeOutQuart,
          ),
        ),
      ),
    );

    // Start animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getTaskCategoryColor(String category) {
    // More iOS-like colors
    switch (category.toLowerCase()) {
      case 'work':
        return const Color(0xFF007AFF); // iOS blue
      case 'personal':
        return const Color(0xFF5856D6); // iOS purple
      case 'health':
        return const Color(0xFF4CD964); // iOS green
      case 'entertainment':
        return const Color(0xFFFF9500); // iOS orange
      default:
        return const Color(0xFF5AC8FA); // iOS teal blue
    }
  }

  String _getPriorityIcon(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return '●'; // Filled circle instead of emoji
      case 'medium':
        return '◐'; // Half-filled circle
      case 'low':
        return '○'; // Empty circle
      default:
        return '○';
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Color(0xFFFF3B30); // iOS red
      case 'medium':
        return const Color(0xFFFF9500); // iOS orange
      case 'low':
        return const Color(0xFF4CD964); // iOS green
      default:
        return Colors.grey;
    }
  }

  // Get emoji for task emotion - using SF Symbols-like approach
  IconData _getEmotionIcon(String? emotion) {
    if (emotion == null) return Icons.sentiment_neutral_outlined;

    switch (emotion.toLowerCase()) {
      case 'happy':
        return Icons.sentiment_very_satisfied;
      case 'excited':
        return Icons.mood;
      case 'neutral':
        return Icons.sentiment_neutral;
      case 'anxious':
        return Icons.sentiment_dissatisfied;
      case 'stressed':
        return Icons.sentiment_very_dissatisfied;
      default:
        return Icons.sentiment_neutral_outlined;
    }
  }

  Color _getEmotionColor(String? emotion) {
    if (emotion == null) return Colors.grey;

    switch (emotion.toLowerCase()) {
      case 'happy':
        return const Color(0xFF4CD964); // iOS green
      case 'excited':
        return const Color(0xFFFF9500); // iOS orange
      case 'neutral':
        return const Color(0xFF8E8E93); // iOS gray
      case 'anxious':
        return const Color(0xFF5AC8FA); // iOS blue
      case 'stressed':
        return const Color(0xFFFF3B30); // iOS red
      default:
        return Colors.grey;
    }
  }

  void _navigateToTaskDetails(Task task) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => TaskDetailsScreen(task: task),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // iOS-style colors
    final backgroundColor = isDarkMode 
      ? const Color(0xFF1C1C1E) // iOS dark mode background
      : const Color(0xFFF2F2F7); // iOS light mode background
      
    final cardColor = isDarkMode
      ? const Color(0xFF2C2C2E) // iOS dark mode card
      : Colors.white;
    
    final textColor = isDarkMode
      ? Colors.white
      : const Color(0xFF000000);
    
    final subtitleColor = isDarkMode
      ? const Color(0xFFAEAEB2) // iOS dark mode secondary text
      : const Color(0xFF8E8E93); // iOS light mode secondary text

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12), // iOS-style corner radius
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // iOS-style drag indicator
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              height: 5,
              width: 36,
              decoration: BoxDecoration(
                color: subtitleColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 10, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Date title in iOS style
                    Text(
                      DateFormat('EEEE, MMMM d').format(widget.date),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: -0.5, // iOS-style letter spacing
                      ),
                    ),
                    // iOS-style close button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: subtitleColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 16,
                          color: subtitleColor,
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Task count in iOS style
                Text(
                  '${widget.tasks.length} task${widget.tasks.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 15,
                    color: subtitleColor,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          
          // Divider in iOS style
          Container(
            height: 1,
            color: subtitleColor.withOpacity(0.2),
          ),

          // Tasks List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: 12,
                bottom: bottomPadding + 20,
              ),
              itemCount: widget.tasks.length,
              itemBuilder: (context, index) {
                final task = widget.tasks[index];
                final taskColor = _getTaskCategoryColor(task.category);
                final priorityColor = _getPriorityColor(task.priority);
                
                // Use animation for each item
                return AnimatedBuilder(
                  animation: _taskAnimations[index],
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0.0,
                        20 * (1.0 - _taskAnimations[index].value),
                      ),
                      child: Opacity(
                        opacity: _taskAnimations[index].value,
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    onTap: () => _navigateToTaskDetails(task),
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: taskColor.withOpacity(isDarkMode ? 0.1 : 0.15),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top row with category and completion status
                                Row(
                                  children: [
                                    // Category indicator - iOS style pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: taskColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _getCategoryIcon(task.category),
                                            color: taskColor,
                                            size: 12,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            task.category,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: taskColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
                                    // Status indicator
                                    if (task.done)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF4CD964).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              CupertinoIcons.checkmark_circle_fill,
                                              color: Color(0xFF4CD964),
                                              size: 12,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Complete',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                                color: const Color(0xFF4CD964),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                
                                const SizedBox(height: 10),
                                
                                // Task title - iOS style font
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                
                                const SizedBox(height: 12),
                                
                                // Task metadata row
                                Row(
                                  children: [
                                    // Time
                                    Icon(
                                      CupertinoIcons.clock,
                                      color: subtitleColor,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      DateFormat('h:mm a').format(task.time),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: subtitleColor,
                                      ),
                                    ),
                                    
                                    // Separator dot
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        '•',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: subtitleColor.withOpacity(0.5),
                                        ),
                                      ),
                                    ),
                                    
                                    // Priority
                                    Text(
                                      _getPriorityIcon(task.priority),
                                      style: TextStyle(
                                        fontSize: 14, 
                                        color: priorityColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      task.priority.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: subtitleColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    
                                    // Emotion icon if present
                                    if (task.emotion != null && task.emotion!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        // child: Icon(
                                        //   _getEmotionIcon(task.emotion),
                                        //   color: _getEmotionColor(task.emotion),
                                        //   size: 16,
                                        // ),
                                        child: Text('${task.emotion}', style: TextStyle(fontSize: 10),),
                                      ),
                                  ],
                                ),
                                
                                // Repeat information if repeating
                                if (task.isRepeated) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        CupertinoIcons.repeat,
                                        color: subtitleColor,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _getRepeatText(task.repeatInterval,
                                            task.repeatedIntervalTime),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: subtitleColor,
                                        ),
                                      ),
                                    ],
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
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods
  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase() ?? 'other') {
      case 'work':
        return CupertinoIcons.briefcase_fill;
      case 'personal':
        return CupertinoIcons.person_fill;
      case 'entertainment':
        return CupertinoIcons.gamecontroller_fill;
      case 'health':
        return CupertinoIcons.heart_fill;
      default:
        return CupertinoIcons.square_grid_2x2_fill;
    }
  }

  String _getRepeatText(String interval, int? time) {
    if (time == null) return 'Repeating';

    switch (interval.toLowerCase()) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        return 'Every week';
      case 'monthly':
        return 'Every month';
      case 'yearly':
        return 'Every year';
      default:
        return 'Repeating';
    }
  }
}