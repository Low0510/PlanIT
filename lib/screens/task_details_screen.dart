import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/models/subtask.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/models/task_file.dart';
import 'package:planit_schedule_manager/screens/edit_schedule_sreen.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/widgets/in_app_viewer.dart';
import 'package:planit_schedule_manager/widgets/toast.dart';
import 'package:planit_schedule_manager/widgets/wave_progressbar.dart';
import 'package:url_launcher/url_launcher.dart';

class TaskDetailsScreen extends StatefulWidget {
  final Task task;

  TaskDetailsScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  
  // State variables for edit functionality
  String? _selectedCategory;
  DateTime? _selectedDateTime;
  String _selectedPriority = 'Medium';
  bool _isRepeatEnabled = false;
  String _selectedRepeatInterval = 'Daily';
  int? _repeatedIntervalTime;
  List<SubTask> subtasks = [];
  List<TaskFile> files = [];

  final ScheduleService _scheduleService = ScheduleService();
  late Task _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
  }

  String _calculateUsageTime(DateTime createdAt, DateTime? completedAt) {
    if(completedAt == null) {
      return 'Incompleted';
    }
    
    final difference = completedAt.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ${difference.inHours % 24}h ${difference.inMinutes % 60}m';
    } else if (difference.inHours > 0) {
      return '${difference.inHours % 24}h ${difference.inMinutes % 60}m';
    } else {
      return '${difference.inMinutes }m';
    }
  }

  Future<void> _toggleSubtaskStatus(SubTask subtaskToUpdate) async {
  // 1. Capture the original state in case we need to revert
  final originalTask = _currentTask;
  final originalSubtask = originalTask.subtasks.firstWhere((s) => s.id == subtaskToUpdate.id);

  // 2. Create the new "optimistic" state
  final updatedSubtasks = originalTask.subtasks.map((subtask) {
    if (subtask.id == subtaskToUpdate.id) {
      return subtask.copyWith(
        isDone: !subtask.isDone,
        completedAt: !subtask.isDone ? DateTime.now() : null,
      );
    }
    return subtask;
  }).toList();

  final optimisticTask = originalTask.copyWith(subtasks: updatedSubtasks);

  // 3. Update the UI INSTANTLY (The Optimistic part)
  if (mounted) {
    setState(() {
      _currentTask = optimisticTask;
    });
  }

  // 4. Try to sync the change with the backend
  try {
    await _scheduleService.updateSubtaskStatus(
      _currentTask.id,
      subtaskToUpdate.id,
      !originalSubtask.isDone, // Use the original status to toggle
    );
    // Success! No need to do anything, the UI is already updated.
    // You could show a subtle, non-blocking success indicator if you want, but it's often not needed.
  } catch (e) {
    // 5. OOPS! Something went wrong. Revert the UI and show an error.
    if (mounted) {
      setState(() {
        _currentTask = originalTask; // Revert to the original state
      });
      ErrorToast.show(context, 'Failed to update. Please try again.');
    }
  }
}

  @override
Widget build(BuildContext context) {
  final createdAt = (_currentTask.createdAt);
  final completedAt = _currentTask.completedAt;
  final time = _currentTask.time;
  final subtasks = _currentTask.subtasks;

  final title = _currentTask.title;
  final category = _currentTask.category;
  final url = _currentTask.url;
  final placeURL = _currentTask.placeURL;
  final isDone = _currentTask.done;
  final priority = _currentTask.priority;
  final emotion = _currentTask.emotion ?? '';
  final files = _currentTask.files;

  final differenceTime = _calculateUsageTime(createdAt!, completedAt);

  return Scaffold(
    // Set background image for the entire screen
    body: Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          _buildSliverAppBar(category),
          SliverToBoxAdapter(
            child: Container(
              // No background overlay - letting the background image show through
              // margin: const EdgeInsets.only(top: 10),
              // padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Column(
                children: [
                  _buildTitleSection(title, differenceTime, priority, emotion),
                  _buildTimelineSection(createdAt, time, isDone, completedAt),
                  _buildSubtaskSection(subtasks),
                  if (url.isNotEmpty) _buildUrlCard(url),
                  if (placeURL.isNotEmpty) _buildPlaceUrlCard(placeURL),
                  if (files.isNotEmpty) _buildFileSegment(files),
                  _buildTaskStatusButton(_currentTask),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSliverAppBar(String category) {
  // Light yellowish-brown theme colors that complement the background image
  final Color primaryColor = const Color(0xFFD4B483); // Base yellowish-brown
  final Color secondaryColor = const Color(0xFFC19A6B); // Darker tone
  final Color accentColor = const Color(0xFFE6D2B5);   // Lighter tone

  return SliverAppBar(
    expandedHeight: 250,
    floating: false,
    pinned: true,
    stretch: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    flexibleSpace: FlexibleSpaceBar(
      stretchModes: const [
        StretchMode.zoomBackground,
        StretchMode.blurBackground,
      ],
      centerTitle: true,
      title: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Text(
              'Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 2),
                    blurRadius: 6.0,
                    color: Colors.black.withOpacity(0.4),
                  ),
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 3.0,
                    color: Colors.black.withOpacity(0.2),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      background: Stack(
        fit: StackFit.expand,
        children: [
          // Background image with overlay gradient that matches the color theme
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.5),
              ],
            ).createShader(bounds),
            blendMode: BlendMode.darken,
            child: Image.asset(
              'assets/images/background.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter, // Align to top for better title visibility
            ),
          ),
          // Gradient overlay to ensure text visibility
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  primaryColor.withOpacity(0.2),
                  secondaryColor.withOpacity(0.6),
                ],
              ),
            ),
          ),
          // Content
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: child,
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.25),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.category,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.white),
        onPressed: () {
          _showDeleteConfirmation();
        },
      ),
      IconButton(
        icon: const Icon(Icons.edit_outlined, color: Colors.white),
        onPressed: () {
          _editSchedule();
        },
      ),  
    ],
  );
}
Widget _buildTaskStatusButton(Task task) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    child: GestureDetector(
      onTap: () {
        // Toggle the task completion status
        _scheduleService.updateTaskCompletion(task.id, !task.done);
        Navigator.pop(context);
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: task.done
                ? [Colors.orange.shade400, Colors.orange.shade600]
                : [Colors.green.shade400, Colors.green.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: task.done
                  ? Colors.orange.withOpacity(0.3)
                  : Colors.green.withOpacity(0.3),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Animated circles
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Main button content
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    task.done
                        ? Icons.replay_circle_filled_outlined
                        : Icons.check_circle_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    task.done ? 'Mark as Undone' : 'Mark as Complete',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildTitleSection(String title, String differenceTime, String priority, String emotion) {
  return Container(
    margin: EdgeInsets.all(16),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.8),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 10,
          offset: Offset(0, 2),
        )
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.assignment_outlined,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Text(
              'Task Title',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
            height: 1.3,
          ),
        ),
        SizedBox(height: 12),
        Divider(color: Colors.grey.shade200),
        SizedBox(height: 12),
        Row(
          children: [
            _buildTaskStat(
              icon: Icons.timer_outlined,
              label: 'Time Usage',
              value: differenceTime,
              color: Colors.orange,
              size: 14
            ),
            SizedBox(width: 24),
            _buildTaskStat(
              icon: Icons.priority_high_rounded,
              label: 'Priority',
              value: priority,
              color: Colors.red,
              size: 14,
            ),
            SizedBox(width: 24),
            if (emotion.isNotEmpty) _buildTaskStat(
              icon: Icons.add_reaction_outlined,
              label: 'Feeling',
              value: ' $emotion',
              color: Colors.blue,
              size: 14,
            ),

          ],
        ),
      ],
    ),
  );
}

Widget _buildTaskStat({
  required IconData icon,
  required String label,
  required String value,
  required Color color,
  required double size,
}) {
  return Row(
    children: [
      Icon(
        icon,
        size: 20,
        color: color,
      ),
      SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    ],
  );
}

  Widget _buildTimelineSection(
      DateTime createdAt, DateTime time, bool isDone, DateTime? completedAt) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 20),
          _buildTimelineItem(
            icon: Icons.create,
            color: Colors.blue,
            title: 'Created',
            datetime: createdAt,
            isCompleted: true,
          ),
          _buildTimelineConnector(),
          _buildTimelineItem(
            icon: Icons.access_time,
            color: Colors.orange,
            title: 'Due',
            datetime: time,
            isCompleted: isDone,
          ),
          if (isDone) ...[
            _buildTimelineConnector(),
            _buildTimelineItem(
              icon: Icons.check_circle,
              color: Colors.green,
              title: 'Completed',
              datetime: completedAt!,
              isCompleted: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineConnector() {
    return Container(
      margin: EdgeInsets.only(left: 15),
      width: 2,
      height: 30,
      color: Colors.grey.shade300,
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required Color color,
    required String title,
    required DateTime datetime,
    required bool isCompleted,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
              Text(
                DateFormat('EEE, MMM d, yyyy | h:mm a').format(datetime),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubtaskSection(List<SubTask> subtasks) {
    if (subtasks.isEmpty) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtasks (${subtasks.where((st) => st.isDone).length}/${subtasks.length})',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              WaveProgressBar(
                completed: subtasks.where((st) => st.isDone).length,
                total: subtasks.length,
              ),
            ],
          ),
          SizedBox(height: 15),
          ...subtasks.map((subtask) => _buildSubtaskItem(subtask)).toList(),
        ],
      ),
    );
  }

  // --- MODIFIED: This widget is now interactive ---
  Widget _buildSubtaskItem(SubTask subtask) {
    return InkWell(
      // <-- NEW: Makes the whole item tappable
      onTap: () => _toggleSubtaskStatus(subtask),
      borderRadius: BorderRadius.circular(10), // For a nice ripple effect
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            // Using a MouseRegion to provide feedback on Desktop/Web
            MouseRegion(
              cursor: SystemMouseCursors.click, // <-- NEW: Changes cursor on hover
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      subtask.isDone ? Colors.green.shade100 : Colors.white,
                  border: Border.all(
                    color: subtask.isDone
                        ? Colors.green
                        : Colors.grey.shade400,
                  ),
                ),
                child: subtask.isDone
                    ? Icon(
                        Icons.check,
                        size: 16,
                        color: Colors.green,
                      )
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                subtask.title,
                style: TextStyle(
                  fontSize: 16,
                  decoration: subtask.isDone
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                  color: subtask.isDone
                      ? Colors.grey.shade500
                      : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlCard(String url) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Reference Link',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(width: 6,),
              Icon(Icons.link, color: Colors.blue.shade700, size: 24),
            ],
          ),
          SizedBox(height: 15),
          InkWell(
            onTap: () => _launchURL(url),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: Colors.blue.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      url,
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceUrlCard(String url) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Place Link',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              SizedBox(width: 6,),
              Icon(
                Icons.place,
                color: Colors.blue.shade700,
                size: 24,
              ),
            ],
          ),
          SizedBox(height: 15),
          InkWell(
            onTap: () => _launchURL(url),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: Colors.blue.shade700),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      extractPlaceName(url),
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 16,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


Widget _buildFileSegment(List<TaskFile> files) {
  return Container(
    margin: EdgeInsets.all(16),
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.8),
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.1),
          spreadRadius: 1,
          blurRadius: 10,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Attachments',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            Icon(
              Icons.attach_file_rounded,
              color: Colors.grey.shade600,
              size: 24,
            ),
          ],
        ),
        SizedBox(height: 12),
        ...files.map((file) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildFileCard(file),
            )),
      ],
    ),
  );
}





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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
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
          child: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: fileColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: fileColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    getFileIcon(file.type),
                    color: fileColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Added ${DateFormat.yMMMd().format(file.uploadedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_browser_rounded,
                  color: fileColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
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

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _editSchedule() {
    // Initialize controllers with current task data
    _titleController.text = _currentTask.title;
    _urlController.text = _currentTask.url ?? '';
    _locationController.text = _currentTask.placeURL ?? '';
    _selectedCategory = _currentTask.category;
    _selectedDateTime = _currentTask.time;
    _selectedPriority = _currentTask.priority;
    _selectedRepeatInterval = _currentTask.repeatInterval;
    _isRepeatEnabled = _currentTask.isRepeated;
    _repeatedIntervalTime = _currentTask.repeatedIntervalTime ?? 0;

    

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async {
            _clearFields();
            return true;
          },
          child: EditScheduleSheet(
            taskId: _currentTask.id,
            titleController: _titleController,
            urlController: _urlController,
            placeUrlController: _locationController,
            selectedCategory: _selectedCategory!,
            selectedDateTime: _selectedDateTime!,
            priority: _selectedPriority,
            isRepeatEnabled: _isRepeatEnabled,
            selectedRepeatInterval: _selectedRepeatInterval,
            repeatedIntervalTime: _repeatedIntervalTime ?? 0,
            subtasks:  _currentTask.subtasks ?? [],
            files: _currentTask.files ?? [],

            onUpdate: (title, category, url, placeURL, time, priority, isRepeat,
                repeatInterval, repeatedIntervalTime, subtasks, files) async {
              try {
                await _scheduleService.updateSchedule(
                  id: _currentTask.id,
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


                final updatedTask = await _scheduleService.getScheduleById(_currentTask.id);


                if (context.mounted) {
                  setState(() {
                    _currentTask = updatedTask;
                  });
                  _clearFields();
                  Navigator.pop(context);
                  SuccessToast.show(context, 'Updated Successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  ErrorToast.show(context, 'Failed to update schedule: $e');
                  print('Error: $e');
                }
              }
            },
          ),
        );
      },
    ).whenComplete(() {
      _clearFields();
    });
  }

  void _clearFields() {
    _titleController.clear();
    _urlController.clear();
    setState(() {
      _selectedCategory = 'Other';
      _selectedDateTime = DateTime.now().copyWith(hour: 23, minute: 59);
      _selectedPriority = 'Medium';
      _isRepeatEnabled = false;
      _selectedRepeatInterval = 'Daily';
      _repeatedIntervalTime = 0;
    });
    
  }

  Future<void> _showDeleteConfirmation() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Schedule'),
          content: const Text('Are you sure you want to delete this schedule?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                try {
                  await _scheduleService.deleteSchedule(_currentTask.id);
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Return to previous screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Schedule deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete schedule: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
