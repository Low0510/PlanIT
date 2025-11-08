import 'package:flutter/material.dart';
import 'dart:async';
import 'package:planit_schedule_manager/models/task.dart';

class TaskCountdownWidget extends StatefulWidget {
  final List<Task> tasks;
  final Function(String taskId, bool favourite) onUpdateFavourite;
  final Function() onUpdateLatestTasks;

  const TaskCountdownWidget({
    Key? key,
    required this.tasks,
    required this.onUpdateFavourite,
    required this.onUpdateLatestTasks,
  }) : super(key: key);

  @override
  _TaskCountdownWidgetState createState() => _TaskCountdownWidgetState();
}

class _TaskCountdownWidgetState extends State<TaskCountdownWidget>
    with TickerProviderStateMixin {
  Task? selectedTask;
  Timer? countdownTimer;
  Duration remainingTime = Duration.zero;
  bool isTaskSwitch = false; // Track if we're switching tasks

  @override
  void initState() {
    super.initState();
    _initializeSelectedTask();
  }

  void _initializeSelectedTask() {
    // Find a previously favourited task among the available ones
    final favouriteTask = _getAvailableTasks().firstWhere(
      (task) => task.favourite == true,
      orElse: () => Task(
          id: '',
          title: '',
          category: '',
          time: DateTime.now(),
          subtasks: [],
          isRepeated: false,
          priority: '',
          repeatInterval: ''), 
    );

    if (favouriteTask.id.isNotEmpty) {
      setState(() {
        selectedTask = favouriteTask;
      });
      _startCountdown();
    }
  }

  List<Task> _getAvailableTasks() {

    final now = DateTime.now();
    return widget.tasks
        .where((task) => task.done == false && task.time.isAfter(now))
        .toList();
  }

  void _startCountdown() {
    if (selectedTask == null) return;

    countdownTimer?.cancel();
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        final now = DateTime.now();
        if (selectedTask!.time.isAfter(now)) {
          remainingTime = selectedTask!.time.difference(now);
          isTaskSwitch = false; // Reset task switch flag when counting
        } else {
          remainingTime = Duration.zero;
          timer.cancel();
        }
      });
    });
  }

  void _selectTask(Task task) async {
    // Set task switch flag if we're switching from one task to another
    if (selectedTask != null && selectedTask!.id != task.id) {
      setState(() {
        isTaskSwitch = true;
      });
      await widget.onUpdateFavourite(selectedTask!.id, false);
    }

    // Select new task
    await widget.onUpdateFavourite(task.id, true);
    setState(() {
      selectedTask = task;
    });
    _startCountdown();
  }

  void _changeTask() async {
    if (selectedTask != null) {
      // Safely try updating if the ID is valid (you may want to check from a list or API)
      try {
        await widget.onUpdateFavourite(selectedTask!.id, false);
      } catch (e) {
        // ID not found or other error — silently ignore or log
        print("Warning: Task ID not found or could not update.");
      }
    }

    widget.onUpdateLatestTasks();

    setState(() {
      selectedTask = null;
      countdownTimer?.cancel();
      remainingTime = Duration.zero;
      isTaskSwitch = false;
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 160, 
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            child: selectedTask == null
                ? _buildTaskSelection()
                : _buildCountdownView(),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskSelection() {
    final availableTasks = _getAvailableTasks();

    return Column(
      key: const ValueKey('selectionView'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Task Countdown',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),
        const Text(
          'Select an upcoming task to track',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        // const SizedBox(height: 12),
        Flexible(
          child: availableTasks.isEmpty
              ? _buildNoTasksAvailable()
              : ListView.builder(
                  itemCount: availableTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskOption(availableTasks[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoTasksAvailable() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt, size: 32, color: Color(0xFF64748B)),
          SizedBox(height: 6),
          Text(
            'No Upcoming Tasks',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Add a new task to start the countdown.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskOption(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _selectTask(task),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'Due in ${_formatDuration(task.time.difference(DateTime.now()))}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownView() {
    final days = remainingTime.inDays;
    final hours = remainingTime.inHours % 24;
    final minutes = remainingTime.inMinutes % 60;
    final seconds = remainingTime.inSeconds % 60;
    final bool isTimeUp = remainingTime.inSeconds <= 0 && !isTaskSwitch;

    return Column(
      key: const ValueKey('countdownView'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedTask!.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Due: ${_formatDateTime(selectedTask!.time)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.sync_alt_outlined, color: Color(0xFF64748B)),
              onPressed: _changeTask,
              tooltip: 'Change Task',
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
            )
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: isTaskSwitch
              ? _buildTaskSwitchDisplay()
              : isTimeUp
                  ? _buildTimeUpDisplay()
                  : _buildCountdownDisplay(days, hours, minutes, seconds),
        ),
      ],
    );
  }

  Widget _buildTaskSwitchDisplay() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_horiz, size: 36, color: Color(0xFF3B82F6)),
          SizedBox(height: 6),
          Text(
            "Task Switched!",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B82F6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeUpDisplay() {
    return const Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 30, color: Color(0xFF10B981)),
          SizedBox(height: 4),
          Text(
            "Time's Up!",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountdownDisplay(int days, int hours, int minutes, int seconds) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTimeUnit(days.toString().padLeft(2, '0'), 'Days'),
          _buildTimeUnit(hours.toString().padLeft(2, '0'), 'Hours'),
          _buildTimeUnit(minutes.toString().padLeft(2, '0'), 'Mins'),
          _buildTimeUnit(seconds.toString().padLeft(2, '0'), 'Secs'),
        ],
      ),
    );
  }

  Widget _buildTimeUnit(String value, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}