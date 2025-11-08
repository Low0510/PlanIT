import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/services/ai_analyzer.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/widgets/toast.dart';
import 'package:intl/intl.dart';

class TimetableAnalyzerScreen extends StatefulWidget {
  @override
  _TimetableAnalyzerScreenState createState() =>
      _TimetableAnalyzerScreenState();
}

class _TimetableAnalyzerScreenState extends State<TimetableAnalyzerScreen> {
  final AiAnalyzer _analyzer = AiAnalyzer();
  final ScheduleService _scheduleService = ScheduleService();
  bool _isAnalyzing = false;
  String _resultText = '';
  List<Map<String, dynamic>> _tasks = [];
  File? _imageFile;
  List<String> _rawCommands = [];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _resultText = '';
        _tasks = [];
        _rawCommands = [];
      });

      _analyzeTimetable();
    }
  }

  Future<void> _takePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _resultText = '';
        _tasks = [];
        _rawCommands = [];
      });

      _analyzeTimetable();
    }
  }

  Future<void> _analyzeTimetable() async {
    if (_imageFile == null) return;

    setState(() {
      _isAnalyzing = true;
      _resultText = 'Analyzing timetable...';
    });

    try {
      final result = await _analyzer.analyzeTimetable(_imageFile!);

      if (result['success']) {
        // Store the raw commands for display
        final commands = List<String>.from(result['commands']);
        _rawCommands = commands;

        // Process the commands to create tasks
        final List<Map<String, dynamic>> parsedTasks = [];

        for (final command in commands) {
          try {
            // Process each command using regex to extract parts
            final RegExp addTaskRegex = RegExp(
                r'add\s+(\d{4}/\d{2}/\d{2})\s+(\d{1,2}:\d{2})\s+(\w+)\s+(\w+)\s+(.+)');

            final match = addTaskRegex.firstMatch(command);

            if (match != null) {
              final dateStr = match
                  .group(1)!
                  .replaceAll('/', '-'); // Convert to yyyy-MM-dd format
              final timeStr = match.group(2)!; // Time in HH:mm format
              final category = match.group(3)!;
              final priority = match.group(4)!;
              final taskDescription = match.group(5)!;

              // Combine date and time for DateTime parsing
              final taskDateTime = DateTime.parse("$dateStr $timeStr:00");

              // Check for conflicts
              final conflicts = await _scheduleService.getConflictTasks(
                  newTaskTime: taskDateTime);
              List<Task> conflictTasks = conflicts;

              // Add a unique ID for each task (timestamp + random suffix)
              final String taskId =
                  '${DateTime.now().millisecondsSinceEpoch}_${taskDescription.hashCode}';

              final task = {
                'id': taskId, // Add a unique ID for easier tracking
                'dateStr': dateStr,
                'timeStr': timeStr,
                'category': category,
                'priority': priority.toLowerCase(),
                'description': taskDescription,
                'dateTime': taskDateTime,
                'conflicts': conflictTasks,
                'status': conflicts.isEmpty ? 'ready' : 'conflict',
                'isRepeated': false,
                'repeatInterval': 'Daily',
                'repeatedIntervalTime': 0,
              };

              parsedTasks.add(task);
            }
          } catch (e) {
            print('Error parsing command: $command, Error: $e');
          }
        }

        setState(() {
          _isAnalyzing = false;
          _tasks = parsedTasks;
          _resultText = 'Found ${parsedTasks.length} tasks in your timetable';

          // If there are any conflicts, add a note
          final conflictCount =
              parsedTasks.where((task) => task['status'] == 'conflict').length;
          if (conflictCount > 0) {
            _resultText +=
                '\n⚠️ $conflictCount tasks have scheduling conflicts.';
          }
        });
      } else {
        setState(() {
          _isAnalyzing = false;
          _resultText = 'Analysis failed: ${result['message']}';
        });
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _resultText = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _addTaskToSchedule(Map<String, dynamic> task) async {
    try {
      final DateTime selectedTime = task['dateTime'];
      final String taskDescription = task['description'];
      final String category = task['category'];
      final String priority = task['priority'];
      final bool isRepeated = task['isRepeated'] ?? false;
      final String repeatInterval = task['repeatInterval'] ?? 'Daily';
      final int repeatedIntervalTime = task['repeatedIntervalTime'] ?? 0;
      final String taskId = task['id'];

      // Add empty subtasks list - can be expanded later if needed
      final List<String> subtasks = [];

      // Add task to Firebase using your schedule service
      await _scheduleService.addSchedule(
        title: taskDescription,
        category: category,
        url: "",
        placeURL: "",
        time: selectedTime,
        subtasks: subtasks,
        priority: priority,
        isRepeated: isRepeated,
        repeatInterval: repeatInterval,
        repeatedIntervalTime: repeatedIntervalTime,
      );

      // Update the task status in the UI using the ID
      _updateTaskStatus(taskId, 'added');

      SuccessToast.show(context, 'Task added to schedule');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add task: ${e.toString()}')),
      );
    }
  }

  void _updateTaskStatus(String taskId, String newStatus) {
    setState(() {
      final index = _tasks.indexWhere((task) => task['id'] == taskId);
      if (index != -1) {
        _tasks[index] = {..._tasks[index], 'status': newStatus};
      }
    });
  }

  Future<void> _handleConflictTask(Map<String, dynamic> task) async {
    final List<Task> conflicts = task['conflicts'];

    if (conflicts.isEmpty) {
      // No conflicts, show repeat options
      _showRepeatOptionsDialog(task);
      return;
    }

    // Show conflict dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Scheduling Conflict'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The task "${task['description']}" conflicts with:'),
            SizedBox(height: 8),
            ...conflicts.map((conflict) => Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 4),
                  child: Text(
                      '• ${conflict.title} (${DateFormat('MMM d, yyyy – h:mm a').format(conflict.time)})'),
                )),
            SizedBox(height: 8),
            Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Add Anyway'),
            onPressed: () {
              Navigator.of(context).pop();
              _showRepeatOptionsDialog(task);
            },
          ),
        ],
      ),
    );
  }

  void _showRepeatOptionsDialog(Map<String, dynamic> task) {
    bool isRepeated = task['isRepeated'] ?? false;
    String repeatInterval = task['repeatInterval'] ?? 'Daily';
    int repeatedIntervalTime = task['repeatedIntervalTime'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Repeat Options'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                title: Text('Repeat Task'),
                value: isRepeated,
                onChanged: (value) {
                  setState(() {
                    isRepeated = value;
                  });
                },
              ),
              if (isRepeated) ...[
                SizedBox(height: 8),
                Text('Repeat Interval'),
                DropdownButton<String>(
                  value: repeatInterval,
                  isExpanded: true,
                  items: ['Daily', 'Weekly', 'Monthly'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        repeatInterval = newValue;
                      });
                    }
                  },
                ),
                SizedBox(height: 8),
                Text('Repeat every:'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: repeatedIntervalTime.toDouble(),
                        min: 0,
                        max: 20,
                        divisions: 20,
                        label: repeatedIntervalTime.toString(),
                        onChanged: (double value) {
                          HapticFeedback.heavyImpact();
                          setState(() {
                            repeatedIntervalTime = value.toInt();
                          });
                        },
                      ),
                    ),
                    Text('$repeatedIntervalTime'),
                  ],
                ),
                Text(
                  repeatedIntervalTime == 0
                      ? 'Event will repeat continuously'
                      : 'Event will repeat every $repeatedIntervalTime ${repeatInterval.toLowerCase()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Add Task'),
              onPressed: () {
                // Update task with repeat settings
                final updatedTask = {
                  ...task,
                  'isRepeated': isRepeated,
                  'repeatInterval': repeatInterval,
                  'repeatedIntervalTime': repeatedIntervalTime,
                };
                Navigator.of(context).pop();
                _addTaskToSchedule(updatedTask);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addAllTasks() async {
    // Only process tasks that haven't been added yet
    final List<Map<String, dynamic>> tasksToAdd =
        _tasks.where((task) => task['status'] != 'added').toList();

    if (tasksToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No tasks to add')),
      );
      return;
    }

    _showBatchAddDialog(tasksToAdd);
  }

  void _showBatchAddDialog(List<Map<String, dynamic>> tasksToAdd) {
    bool isRepeated = false;
    String repeatInterval = 'Weekly';
    int repeatedIntervalTime = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add All Tasks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Would you like to add all ${tasksToAdd.length} tasks to your schedule?'),
              SizedBox(height: 12),
              SwitchListTile(
                title: Text('Apply repeat settings to all tasks'),
                value: isRepeated,
                onChanged: (value) {
                  setState(() {
                    isRepeated = value;
                  });
                },
              ),
              if (isRepeated) ...[
                SizedBox(height: 8),
                Text('Repeat Interval'),
                DropdownButton<String>(
                  value: repeatInterval,
                  isExpanded: true,
                  items: ['Daily', 'Weekly', 'Monthly'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        repeatInterval = newValue;
                      });
                    }
                  },
                ),
                SizedBox(height: 8),
                Text('Repeat every:'),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: repeatedIntervalTime.toDouble(),
                        min: 0,
                        max: 20,
                        divisions: 20,
                        label: repeatedIntervalTime.toString(),
                        onChanged: (double value) {
                          HapticFeedback.heavyImpact();
                          setState(() {
                            repeatedIntervalTime = value.toInt();
                          });
                        },
                      ),
                    ),
                    Text('$repeatedIntervalTime'),
                  ],
                ),
                Text(
                  repeatedIntervalTime == 0
                      ? 'Events will repeat continuously'
                      : 'Events will repeat every $repeatedIntervalTime ${repeatInterval.toLowerCase()}',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Add All'),
              onPressed: () async {
                Navigator.of(context).pop();

                // Show progress dialog
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => AlertDialog(
                    content: Row(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text('Adding tasks...'),
                      ],
                    ),
                  ),
                );

                // Add all tasks with repeat settings if specified
                int addedCount = 0;

                for (final task in tasksToAdd) {
                  try {
                    final updatedTask = {
                      ...task,
                      'isRepeated': isRepeated,
                      'repeatInterval': isRepeated ? repeatInterval : 'Daily',
                      'repeatedIntervalTime':
                          isRepeated ? repeatedIntervalTime : 0,
                    };

                    await _addTaskToSchedule(updatedTask);
                    addedCount++;
                  } catch (e) {
                    print('Error adding task: ${e.toString()}');
                  }
                }

                // Close progress dialog
                Navigator.of(context).pop();

                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Added $addedCount out of ${tasksToAdd.length} tasks'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      iconTheme: IconThemeData(color: Colors.brown),
      backgroundColor: Colors.transparent, // Make AppBar transparent
          elevation: 0, // Remove shadow
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 10, sigmaY: 10), // Frosted glass effect
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Subtle white overlay
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
                "Timetable Analyzer",
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
    ),
    body: Stack(
      children: [
        // Background image layer that fills the entire screen
        Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.png'),
              fit: BoxFit.cover,
              // colorFilter: ColorFilter.mode(
              //   Colors.white.withOpacity(0.5),
              //   BlendMode.lighten,
              // ),
            ),
            ),
            width: double.infinity,
            height: double.infinity,
          ),

          // Semi-transparent overlay
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white.withOpacity(0.5),
          ),
          // Scrollable content layer
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Introduction card
                if (_imageFile == null && _resultText.isEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 48,
                          color: Colors.blue[700],
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Timetable Scanner',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Upload or take a photo of your timetable, and we will automatically convert it into digital tasks and schedules.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Get started by selecting one of the options below:',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.photo_library),
                      label: Text('Pick Image'),
                      onPressed: _isAnalyzing ? null : _pickImage,
                    ),
                    ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text('Take Picture'),
                      onPressed: _isAnalyzing ? null : _takePicture,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (_imageFile != null) ...[
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Image.file(
                      _imageFile!,
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 16),
                ],
                if (_resultText.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Lottie.asset('assets/lotties/timetable_robot.json',
                            height: 100),
                        SizedBox(
                          height: 10,
                        ),
                        Text(_resultText),
                      ],
                    ),
                  ),
                SizedBox(height: 16),
                if (_tasks.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Detected Tasks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: Icon(Icons.add_circle),
                        label: Text('Add All Tasks'),
                        onPressed: _tasks.isEmpty ? null : _addAllTasks,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ..._tasks.map((task) => _buildTaskCard(task)),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildTaskCard(Map<String, dynamic> task) {
    String priorityColor;
    switch (task['priority'].toString().toLowerCase()) {
      case 'high':
        priorityColor = '#FF5252';
        break;
      case 'medium':
        priorityColor = '#FFC107';
        break;
      case 'low':
        priorityColor = '#4CAF50';
        break;
      default:
        priorityColor = '#9E9E9E';
    }

    IconData categoryIcon;
    switch (task['category'].toString().toLowerCase()) {
      case 'work':
        categoryIcon = Icons.work_outline_rounded;
        break;
      case 'personal':
        categoryIcon = Icons.person_outline_rounded;
        break;
      case 'entertainment':
        categoryIcon = Icons.sports_esports_rounded;
        break;
      case 'health':
        categoryIcon = Icons.favorite_outline_rounded;
        break;
      default:
        categoryIcon = Icons.category_rounded;
    }

    // Status indicator styles
    IconData statusIcon;
    Color statusColor;
    String statusText;

    switch (task['status']) {
      case 'added':
        statusIcon = Icons.check_circle;
        statusColor = Colors.green;
        statusText = 'Added';
        break;
      case 'conflict':
        statusIcon = Icons.warning;
        statusColor = Colors.orange;
        statusText = 'Conflict';
        break;
      default:
        statusIcon = Icons.schedule;
        statusColor = Colors.blue;
        statusText = 'Ready';
    }

    // Show repeat indicator if task is set to repeat
    final bool isRepeated = task['isRepeated'] ?? false;
    final String repeatInterval = task['repeatInterval'] ?? 'Daily';

    DateTime date = DateTime.parse(task['dateStr']);
    String weekday =
        ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1];
    String displayDate = '$weekday, ${task['dateStr']}';

    return Card(
      color: Colors.white.withOpacity(0.7),
      margin: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: HexColor(priorityColor),
                shape: BoxShape.circle,
              ),
            ),
            title: Text(task['description']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$displayDate at ${task['timeStr']}'),
                if (isRepeated)
                  Row(
                    children: [
                      Icon(Icons.repeat, size: 14, color: Colors.grey),
                      SizedBox(width: 4),
                      Text(
                        'Repeats ${repeatInterval}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(categoryIcon, size: 20),
                SizedBox(width: 12),
                Icon(statusIcon, color: statusColor),
              ],
            ),
            onTap: () {
              if (task['status'] != 'added') {
                _showEditDateTimeDialog(task);
              }
            },
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(statusText, style: TextStyle(color: statusColor)),
                if (task['status'] != 'added')
                  ElevatedButton(
                    onPressed: () => _handleConflictTask(task),
                    child: Text('Add to Schedule',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: task['status'] == 'conflict'
                          ? Colors.orange
                          : Colors.blue,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDateTimeDialog(Map<String, dynamic> task) {
    // Create a copy of the dateTime for editing
    DateTime selectedDate = DateTime.parse(task['dateStr']);
    TimeOfDay selectedTime = TimeOfDay(
      hour: int.parse(task['timeStr'].split(':')[0]),
      minute: int.parse(task['timeStr'].split(':')[1]),
    );

    IconData categoryIcon;
    switch (task['category'].toString().toLowerCase()) {
      case 'work':
        categoryIcon = Icons.work_outline_rounded;
        break;
      case 'personal':
        categoryIcon = Icons.person_outline_rounded;
        break;
      case 'entertainment':
        categoryIcon = Icons.sports_esports_rounded;
        break;
      case 'health':
        categoryIcon = Icons.favorite_outline_rounded;
        break;
      default:
        categoryIcon = Icons.category_rounded;
    }



    // Get priority color
    Color priorityColor;
    switch (task['priority'].toString().toLowerCase()) {
      case 'high':
        priorityColor = HexColor('#FF5252');
        break;
      case 'medium':
        priorityColor = HexColor('#FFC107');
        break;
      case 'low':
        priorityColor = HexColor('#4CAF50');
        break;
      default:
        priorityColor = HexColor('#9E9E9E');
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with task description
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: priorityColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(categoryIcon, size: 20),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Edit Task',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          Text(
                            task['description'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                Divider(height: 24),

                // Current date & time summary
                Container(
                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Schedule',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '${DateFormat('EEE, MMM d, yyyy').format(selectedDate)} at ${selectedTime.format(context)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.edit, color: Colors.blue),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                // Date Picker Button
                InkWell(
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now().subtract(Duration(days: 365)),
                      lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: priorityColor,
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedDate != null && pickedDate != selectedDate) {
                      setState(() {
                        selectedDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          selectedDate.hour,
                          selectedDate.minute,
                        );
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.blue[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: Colors.blue[700],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Date',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, MMMM d, yyyy')
                                    .format(selectedDate),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.blue[700]),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Time Picker Button
                InkWell(
                  onTap: () async {
                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: ColorScheme.light(
                              primary: priorityColor,
                              onPrimary: Colors.white,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );

                    if (pickedTime != null && pickedTime != selectedTime) {
                      setState(() {
                        selectedTime = pickedTime;
                        selectedDate = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.purple[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.access_time,
                            color: Colors.purple[700],
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Time',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                selectedTime.format(context),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_drop_down, color: Colors.purple[700]),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Update the task with new date and time
                        final dateStr =
                            DateFormat('yyyy-MM-dd').format(selectedDate);
                        final timeStr =
                            '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';

                        // Check for conflicts with the new time
                        _checkConflictsAndUpdateTask(
                          task,
                          dateStr,
                          timeStr,
                          DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          ),
                        );

                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: priorityColor,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Save Changes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
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

  Future<void> _checkConflictsAndUpdateTask(Map<String, dynamic> task,
      String dateStr, String timeStr, DateTime newDateTime) async {
    try {
      // Check for conflicts with the new time
      final conflicts =
          await _scheduleService.getConflictTasks(newTaskTime: newDateTime);

      // Update the task in the state with new date and time
      setState(() {
        final index = _tasks.indexWhere((t) => t['id'] == task['id']);
        if (index != -1) {
          _tasks[index] = {
            ..._tasks[index],
            'dateStr': dateStr,
            'timeStr': timeStr,
            'dateTime': newDateTime,
            'conflicts': conflicts,
            'status': conflicts.isEmpty ? 'ready' : 'conflict',
          };
        }
      });

      // Show feedback based on conflicts
      if (conflicts.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '⚠️ The updated time conflicts with ${conflicts.length} existing tasks'),
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Task time updated successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating task: ${e.toString()}')),
      );
    }
  }
}

// Helper class to convert hex color string to Color
class HexColor extends Color {
  static int _getColorFromHex(String hexColor) {
    hexColor = hexColor.toUpperCase().replaceAll('#', '');
    if (hexColor.length == 6) {
      hexColor = 'FF' + hexColor;
    }
    return int.parse(hexColor, radix: 16);
  }

  HexColor(final String hexColor) : super(_getColorFromHex(hexColor));
}
