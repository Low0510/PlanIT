import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:planit_schedule_manager/models/project50task.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/screens/project50_summary_screen.dart';
import 'package:planit_schedule_manager/services/ai_analyzer.dart';
import 'package:planit_schedule_manager/services/project50_service.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/widgets/reset_challenge_button.dart';
import 'package:planit_schedule_manager/widgets/toast.dart';
import 'package:planit_schedule_manager/widgets/week_progress_project50.dart';

class Project50Screen extends StatefulWidget {
  @override
  _Project50ScreenState createState() => _Project50ScreenState();
}

class _Project50ScreenState extends State<Project50Screen>
    with SingleTickerProviderStateMixin {
  // final ScheduleService _scheduleService = ScheduleService();
  final Project50Service _project50service = Project50Service();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Challenge state
  bool _isLoading = true;
  bool _hasStartedChallenge = false;
  List<Project50Task> _allTasks = [];
  Map<int, List<Project50Task>> _tasksByDay = {};
  Map<String, dynamic>? _challengeDetails;

  int _selectedDay = 1;

  // Progress tracking
  int _currentDay = 0;
  int _completedTasks = 0;
  double _overallProgress = 0.0;
  DateTime? _challengeStartDate;
  DateTime? _challengeEndDate;
  bool _streakActive = false;
  int _completedDays = 0;

  // UI Controllers
  PageController _pageController = PageController();
  int _currentPage = 0;

  final TextEditingController _skillTextController = TextEditingController();
  String skillName = "";

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);

    _initializeProject50();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _skillTextController.dispose();
    super.dispose();
  }

  Future<void> _initializeProject50() async {
    try {
      // Check if user has already started the challenge
      print("Start initializing...");
      _hasStartedChallenge = await _project50service.isProject50init();

      print("Has started: ${_hasStartedChallenge}");

      if (_hasStartedChallenge) {
        await _loadProject50Data();
        await _checkAndPromptForReset();
      }
    } catch (e) {
      _showErrorSnackBar('Error initializing Project 50: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _startChallenge() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _project50service.initializeProject50IfNeeded();
      _hasStartedChallenge = true;
      await _loadProject50Data();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Your 50-day challenge has been set up! Starting tomorrow.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Error starting challenge: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  bool _isAllChallengesComplete() {
    return _completedTasks == 350;
  }

  Future<void> _loadProject50Data() async {
    try {
      // Load challenge details
      _challengeDetails = await _project50service.getProject50Details();
      if (_challengeDetails != null) {
        // Extract challenge metadata
        _completedDays = _challengeDetails!['completedDays'] ?? 0;
        // _streakActive = challengeDetails!['streakActive'] == 1; // sqflite stores as INTEGER (0 or 1)
        // _overallProgress =
        //     _challengeDetails!['progressPercentage']?.toDouble() ?? 0.0;
        // Parse dates from ISO 8601 strings
        if (_challengeDetails!['challengeStartDate'] != null) {
          _challengeStartDate =
              DateTime.parse(_challengeDetails!['challengeStartDate']);
        }
        if (_challengeDetails!['challengeEndDate'] != null) {
          _challengeEndDate =
              DateTime.parse(_challengeDetails!['challengeEndDate']);
        }
      }

      // Load all tasks
      _allTasks = await _project50service.getProject50Tasks();

      // Group tasks by day
      _tasksByDay = {};
      for (var task in _allTasks) {
        if (!_tasksByDay.containsKey(task.day)) {
          _tasksByDay[task.day] = [];
        }
        _tasksByDay[task.day]!.add(task);
      }

      // Calculate completed tasks
      _completedTasks = _allTasks.where((task) => task.isCompleted).length;

      // Calculate current day based on completed tasks
      _currentDay = 1; // Default to day 1

      // Find the latest day where all tasks are completed, then set current day to the next day
      for (int i = 1; i <= 50; i++) {
        if (_tasksByDay.containsKey(i)) {
          bool allCompleted = _tasksByDay[i]!.every((task) => task.isCompleted);
          if (allCompleted) {
            _currentDay = i + 1; // Set to the next day
          } else {
            break; // Stop at the first incomplete day
          }
        }
      }

      // Check for reset challenge

      final today = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);

      if (_tasksByDay.containsKey(_currentDay) &&
          _tasksByDay[_currentDay]!.isNotEmpty) {
        Project50Task _task = _tasksByDay[_currentDay]!.first;

        final previousDayTasks = _tasksByDay[_currentDay - 2] ?? [];

        // if(_task.time.isBefore(today)) {
        //   _showResetChallengeDialog(previousDayTasks);
        // }
      }

      // Ensure _currentDay doesn't exceed 50
      _currentDay = _currentDay > 50 ? 50 : _currentDay;

      print('Current Day: $_currentDay');

      // Update UI
      setState(() {
        if (_isAllChallengesComplete()) {
          _selectedDay = 50;
        } else {
          _selectedDay = _currentDay;
        }
      });
    } catch (e) {
      _showErrorSnackBar('Error loading challenge data: ${e.toString()}');
    }
  }

  Future<void> _toggleTaskCompletion(Project50Task task) async {
    try {
      // Check if we're completing the task (not un-completing)
      final bool isCompletingTask = !task.isCompleted;

      setState(() {
        // Update local state immediately for responsive UI
        final index = _allTasks.indexWhere((t) => t.id == task.id);
        if (index != -1) {
          _allTasks[index] = Project50Task(
            id: task.id,
            title: task.title,
            category: task.category,
            description: task.description,
            time: task.time,
            isCompleted: !task.isCompleted,
            day: task.day,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            orderTask: task.orderTask,
          );
        }

        // Update the tasks by day
        if (_tasksByDay.containsKey(task.day)) {
          final dayIndex =
              _tasksByDay[task.day]!.indexWhere((t) => t.id == task.id);
          if (dayIndex != -1) {
            _tasksByDay[task.day]![dayIndex] = Project50Task(
              id: task.id,
              title: task.title,
              category: task.category,
              description: task.description,
              time: task.time,
              isCompleted: !task.isCompleted,
              day: task.day,
              createdAt: task.createdAt,
              updatedAt: task.updatedAt,
              orderTask: task.orderTask,
            );
          }
        }

        // Recalculate progress
        _completedTasks = _allTasks.where((task) => task.isCompleted).length;
        _overallProgress = _completedTasks / (7 * 50);
      });

      // Show Lottie animation only when completing a task (not when un-completing)
      if (isCompletingTask) {
        _showCompletionAnimation();
      }

      // Update in the backend
      final updatedTask = Project50Task(
        id: task.id,
        title: task.title,
        category: task.category,
        description: task.description,
        time: task.time,
        isCompleted: !task.isCompleted,
        day: task.day,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        orderTask: task.orderTask,
      );

      await _project50service.updateProject50TaskDetails(task.id, updatedTask);

      // Optional: refresh from server to ensure data consistency
      await _loadProject50Data();
    } catch (e) {
      _showErrorSnackBar('Error updating task: $e');

      // Revert the local change if the backend update failed
      await _loadProject50Data();
    }
  }

// Add this method to show the Lottie animation overlay
  void _showCompletionAnimation() {
    OverlayState? overlayState = Overlay.of(context);
    if (overlayState == null) return;

    // Create a late variable that we'll initialize within the handler
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned.fill(
        child: Material(
          color: Colors.black.withOpacity(0.3),
          child: Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/lotties/task50_complete.json',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    repeat: false,
                    onLoaded: (composition) {
                      // Remove the overlay after animation completes
                      Future.delayed(composition.duration, () {
                        entry.remove();
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Task Completed!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Add the overlay to the screen
    overlayState.insert(entry);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    // ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(content: Text(message), backgroundColor: Colors.red));
    print(message);
  }

  Future<void> _checkAndPromptForReset() async {
    try {
      // Get today's date without time component
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      // Check if challenge has started and we're within the challenge period
      if (_challengeStartDate != null && _currentDay > 0 && _currentDay <= 50) {
        print("Challenge Start Date: $_challengeStartDate");
        print("Current Day: $_currentDay");

        // Get tasks for the current day
        final currentDayTasks = _tasksByDay[_currentDay] ?? [];

        if (currentDayTasks.isNotEmpty) {
          // Get the timestamp from the first task of the current day
          final taskDate = currentDayTasks[0].time;
          print("Task Date: $taskDate");

          // Convert task date to date-only for comparison
          final taskDateOnly =
              DateTime(taskDate.year, taskDate.month, taskDate.day);

          // If the task's date is before today and not all tasks are completed, show reset dialog
          if (taskDateOnly.isBefore(today)) {
            final allTasksCompleted =
                currentDayTasks.every((task) => task.isCompleted);

            if (!allTasksCompleted) {
              // Delayed to ensure the UI is built
              Future.delayed(Duration(milliseconds: 300), () {
                _showResetChallengeDialog(currentDayTasks);
              });
            }
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error checking challenge status: ${e.toString()}');
    }
  }
  // void _showResetChallengeDialog(List<Project50Task> incompleteTasks) {
  //   // Count how many tasks were incomplete
  //   final incompleteCount =
  //       incompleteTasks.where((task) => !task.isCompleted).length;
  //   final totalTasks = incompleteTasks.length;

  //   showDialog(
  //     context: context,
  //     barrierDismissible: false, // User must take action
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         shape:
  //             RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //         title: Row(
  //           children: [
  //             Icon(Icons.refresh, color: Theme.of(context).primaryColor),
  //             SizedBox(width: 8),
  //             Text('Challenge Incomplete'),
  //           ],
  //         ),
  //         content: Container(
  //           width: double.maxFinite,
  //           child: Column(
  //             mainAxisSize: MainAxisSize.min,
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 'You completed ${totalTasks - incompleteCount} out of $totalTasks tasks for Day ${_currentDay - 1}.',
  //                 style: TextStyle(fontSize: 16),
  //               ),
  //               SizedBox(height: 16),
  //               Text(
  //                 'The Project 50 challenge requires completing all daily tasks to maintain momentum.',
  //                 style: TextStyle(fontSize: 14),
  //               ),
  //               SizedBox(height: 14),
  //               Center(
  //                 child: Lottie.asset(
  //                   'assets/lotties/crying.json',
  //                   height: 180,
  //                 ),
  //               ),
  //               SizedBox(
  //                 height: 10,
  //               ),
  //               Text(
  //                 'Aww nooo~ challenge missed! 😢:',
  //                 style: TextStyle(fontWeight: FontWeight.bold),
  //               ),
  //               SizedBox(height: 8),
  //               _buildOptionCard(
  //                 icon: Icons.refresh,
  //                 title: 'Reset Challenge',
  //                 description:
  //                     'Start fresh with all tasks marked incomplete. Your challenge will begin tomorrow.',
  //                 color: Colors.orange.shade100,
  //                 iconColor: Colors.orange,
  //               ),
  //               SizedBox(height: 8),
  //               _buildOptionCard(
  //                 icon: Icons.skip_next,
  //                 title: 'Continue Anyway',
  //                 description:
  //                     'Continue your challenge from Day $_currentDay without resetting progress.',
  //                 color: Colors.blue.shade100,
  //                 iconColor: Colors.blue,
  //               ),
  //             ],
  //           ),
  //         ),
  //         actions: [
  //           TextButton(
  //             child: Text('RESET CHALLENGE'),
  //             style: TextButton.styleFrom(
  //               foregroundColor: Colors.orange,
  //             ),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //               _resetChallenge();
  //             },
  //           ),
  //           ElevatedButton(
  //             child: Text('CONTINUE ANYWAY'),
  //             style: ElevatedButton.styleFrom(
  //               backgroundColor: Theme.of(context).primaryColor,
  //               foregroundColor: Colors.white,
  //             ),
  //             onPressed: () {
  //               Navigator.of(context).pop();
  //             },
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }
  void _showResetChallengeDialog(List<Project50Task> incompleteTasks) {
    final incompleteCount =
        incompleteTasks.where((task) => !task.isCompleted).length;
    final totalTasks = incompleteTasks.length;
    final completedCount = totalTasks - incompleteCount;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Project 50 - Oops! Day $_currentDay Missed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/lotties/crying.json',
                height: 120,
              ),
              SizedBox(height: 12),
              Text(
                '$completedCount/$totalTasks tasks done. So close!',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _resetChallenge();
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.orange),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Reset & Start Fresh Tomorrow'),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _continueChallenge(incompleteTasks);
                },
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.skip_next, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('Pretend This Never Happened 😉'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "It happens to the best of us!",
                  style: TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

// New function to handle the "Continue Anyway" option
  // Future<void> _continueChallenge(List<Project50Task> incompleteTasks) async {
  //   try {
  //     // Show loading indicator
  //     setState(() {
  //       _isLoading = true;
  //     });

  //     final int missedDay = _currentDay - 1;

  //     // 1. Auto-mark all incomplete tasks for the missed day as complete
  //     for (var task in incompleteTasks) {
  //       if (!task.isCompleted) {
  //         // Update the task to mark it as completed
  //         task.isCompleted = true;
  //         task.updatedAt = DateTime.now();
  //         task.title = "${task.title} (Failed)";
  //         await _project50service.updateProject50TaskDetails(task.id, task);
  //       }
  //     }

  //     // 2. Get project details to determine challenge dates
  //     final projectDetails = await _project50service.getProject50Details();
  //     if (projectDetails == null) {
  //       throw Exception("Project details not found");
  //     }

  //     // 3. Update future task dates (days > missedDay) by adding one day
  //     // Get all future tasks
  //     for (int day = missedDay + 1; day <= 50; day++) {
  //       final List<Project50Task> dayTasks =
  //           await _project50service.getProject50TasksByDay(day);

  //       for (var task in dayTasks) {
  //         // Parse the current task date
  //         DateTime currentTaskDate = task.time;

  //         // Add one day to the task date
  //         DateTime newTaskDate = currentTaskDate.add(Duration(days: 1));

  //         // Update the task with the new date
  //         task.time = newTaskDate;
  //         task.updatedAt = DateTime.now();

  //         // Save the updated task
  //         await _project50service.updateProject50TaskDetails(task.id, task);
  //       }
  //     }

  //     // 4. Update project details with the new end date
  //     DateTime endDate = DateTime.parse(projectDetails['challengeEndDate']);
  //     DateTime newEndDate = endDate.add(Duration(days: 1));

  //     await _project50service.updateProject50Details({
  //       'challengeEndDate': newEndDate.toIso8601String(),
  //       'lastActivityDate': DateTime.now().toIso8601String(),
  //     });

  //     // // 5. Update total completed tasks count
  //     // int totalCompletedTasks = projectDetails['totalCompletedTasks'] + incompleteCount;
  //     // double progressPercentage = (totalCompletedTasks / (50 * 7)) * 100;

  //     // await _project50service.updateProject50Details({
  //     //   'totalCompletedTasks': totalCompletedTasks,
  //     //   'progressPercentage': progressPercentage,
  //     // });

  //     // 6. Update UI and refresh data
  //     _loadProject50Data();

  //     // Show success message
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text(
  //             'Challenge continued! All future dates adjusted.'),
  //         backgroundColor: Colors.green,

  //       ),

  //     );
  //   } catch (e) {
  //     print("Error in _continueChallenge: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('Failed to continue challenge: ${e.toString()}'),
  //         backgroundColor: Colors.red,
  //       ),
  //     );
  //   } finally {
  //     // Hide loading indicator
  //     setState(() {
  //       _isLoading = false;
  //     });
  //   }
  // }

  Future<void> _continueChallenge(List<Project50Task> incompleteTasks) async {
    try {
      // Show loading indicator
      setState(() {
        _isLoading = true;
      });

      final int missedDay = _currentDay - 1;
      final DateTime today = DateTime.now();

      // 1. Auto-mark all incomplete tasks for the missed day as complete
      for (var task in incompleteTasks) {
        if (!task.isCompleted) {
          task.isCompleted = true;
          task.updatedAt = today;
          task.title = "${task.title} (Failed)";
          await _project50service.updateProject50TaskDetails(task.id, task);
        }
      }

      // 2. Get project details to determine challenge dates
      final projectDetails = await _project50service.getProject50Details();
      if (projectDetails == null) {
        throw Exception("Project details not found");
      }

      // Calculate the original days between tasks
      DateTime challengeStartDate =
          DateTime.parse(projectDetails['challengeStartDate']);
      DateTime originalEndDate =
          DateTime.parse(projectDetails['challengeEndDate']);

      // 3. Calculate new start day for future tasks (tomorrow)
      final DateTime tomorrowDate = DateTime(
        today.year,
        today.month,
        today.day + 1,
      );

      // 4. Update future task dates based on new schedule
      for (int day = missedDay + 1; day <= 50; day++) {
        final List<Project50Task> dayTasks =
            await _project50service.getProject50TasksByDay(day);

        for (var task in dayTasks) {
          // Calculate how many days from challenge start this task was scheduled
          int originalDayOffset = day - 1; // Days from start (0-indexed)

          // Set new task date as tomorrow + offset from the missed day
          DateTime newTaskDate =
              tomorrowDate.add(Duration(days: day - (missedDay + 1)));

          // Update the task with the new date
          task.time = newTaskDate;
          task.updatedAt = today;

          // Save the updated task
          await _project50service.updateProject50TaskDetails(task.id, task);
        }
      }

      // 5. Calculate and update project end date based on new schedule
      // New end date = tomorrow + remaining days
      int remainingDays = 50 - missedDay;
      DateTime newEndDate = tomorrowDate.add(Duration(
          days: remainingDays - 1)); // -1 because day 1 starts tomorrow

      await _project50service.updateProject50Details({
        'challengeEndDate': newEndDate.toIso8601String(),
        'lastActivityDate': today.toIso8601String(),
      });

      // 6. Update UI and refresh data
      _loadProject50Data();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Challenge rescheduled! Your next task starts tomorrow.'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print("Error in _continueChallenge: $e");
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(
      //     content: Text('Failed to continue challenge: ${e.toString()}'),
      //     backgroundColor: Colors.red,
      //   ),
      // );
    } finally {
      // Hide loading indicator
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Widget _buildOptionCard({
  //   required IconData icon,
  //   required String title,
  //   required String description,
  //   required Color color,
  //   required Color iconColor,
  // }) {
  //   return Container(
  //     padding: EdgeInsets.all(12),
  //     decoration: BoxDecoration(
  //       color: color,
  //       borderRadius: BorderRadius.circular(8),
  //     ),
  //     child: Row(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Container(
  //           padding: EdgeInsets.all(8),
  //           decoration: BoxDecoration(
  //             color: Colors.white,
  //             shape: BoxShape.circle,
  //           ),
  //           child: Icon(icon, color: iconColor, size: 20),
  //         ),
  //         SizedBox(width: 12),
  //         Expanded(
  //           child: Column(
  //             crossAxisAlignment: CrossAxisAlignment.start,
  //             children: [
  //               Text(
  //                 title,
  //                 style: TextStyle(
  //                   fontWeight: FontWeight.bold,
  //                   fontSize: 15,
  //                 ),
  //               ),
  //               SizedBox(height: 4),
  //               Text(
  //                 description,
  //                 style: TextStyle(fontSize: 13),
  //               ),
  //             ],
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _resetChallenge() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Resetting your challenge...")
              ],
            ),
          );
        },
      );

      // Reset the sqflite database
      final db = await _project50service.getDatabase();

      // Use a transaction to ensure atomic deletion
      await db.transaction((txn) async {
        // Delete all tasks
        await txn.delete('project50_tasks');
        // Delete all challenge details
        await txn.delete('project50_details');
      });

      setState(() {
        _hasStartedChallenge = false;
      });

      // Re-initialize the challenge
      // await _project50service.initializeProject50IfNeeded();

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Challenge Reset'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/icon.png',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.refresh, size: 80, color: Colors.green),
                ),
                SizedBox(height: 16),
                Text(
                  'Your Project 50 Challenge has been reset successfully!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                child: Text('GOT IT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 45),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );

      // Reload data
      await _loadProject50Data();
    } catch (e) {
      // Close loading dialog if open
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _showErrorSnackBar('Error resetting challenge: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      // Remove traditional AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Make AppBar transparent
        iconTheme: IconThemeData(color: Colors.brown),
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
              "Project 50",
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
      // Use a safe area to handle status bar
      body: _isLoading
          ? _buildLoadingIndicator()
          : Column(
              children: [
                // Custom app header
                SizedBox(
                  height: 103,
                ),
                _buildCustomHeader(),
                // Main content
                Expanded(
                  child: _hasStartedChallenge
                      ? _buildChallengeContent()
                      : _buildIntroContent(),
                ),
              ],
            ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Show progress indicator if challenge started
          if (_hasStartedChallenge) ...[
            // Progress indicator with integrated tab switching
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Left side: Day counter
                    Text(
                      'Day $_currentDay of 50',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    // Right side: Tab switcher with percentage
                    Row(
                      children: [
                        // Improved button switcher container
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              // Overview tab button
                              GestureDetector(
                                onTap: () => _pageController.animateToPage(
                                  0,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _currentPage == 0
                                        ? Theme.of(context).primaryColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Overview',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _currentPage == 0
                                          ? Colors.white
                                          : Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color,
                                    ),
                                  ),
                                ),
                              ),
                              // Daily Tasks tab button
                              GestureDetector(
                                onTap: () => _pageController.animateToPage(
                                  1,
                                  duration: Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _currentPage == 1
                                        ? Theme.of(context).primaryColor
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Daily Tasks',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _currentPage == 1
                                          ? Colors.white
                                          : Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.color,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        // Percentage display
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${(((_currentDay - 1) / 50) * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _overallProgress,
                    minHeight: 6,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChallengeContent() {
    return PageView(
      controller: _pageController,
      onPageChanged: (index) {
        setState(() {
          _currentPage = index;
        });
      },
      children: [
        _buildOverviewTab(),
        _buildDailyTasksTab(),
      ],
    );
  }

  Widget _buildLoadingIndicator({String message = 'Loading, please wait...'}) {
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
            // Loading Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                color: Colors.blue,
                size: 32,
              ),
            ),
            const SizedBox(height: 24),

            // Circular Progress Indicator
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
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroContent() {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color accentColor =
        Theme.of(context).colorScheme.secondary; // Or another distinct color

    return Container(
      // Optional: Add a subtle gradient background to the whole page
      // decoration: BoxDecoration(
      //   gradient: LinearGradient(
      //     colors: [primaryColor.withOpacity(0.1), Colors.white],
      //     begin: Alignment.topCenter,
      //     end: Alignment.bottomCenter,
      //   ),
      // ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Hero Section ---
            _buildHeroSection(primaryColor),

            SizedBox(height: 24),

            // --- The 7 Rules ---
            _buildSectionCard(
              title: 'THE 7 RULES FOR 50 DAYS',
              icon: Icons.rule_folder_outlined,
              iconColor: primaryColor,
              children: [
                _buildRuleItem(1, 'Wake up by 8am', Icons.alarm, primaryColor),
                _buildRuleItem(2, '1 hour morning routine',
                    Icons.self_improvement, primaryColor),
                _buildRuleItem(3, 'Exercise for 1 hour a day',
                    Icons.fitness_center, primaryColor),
                _buildRuleItem(
                    4, 'Read 10 pages a day', Icons.menu_book, primaryColor),
                _buildRuleItem(5, '1 hour towards a new skill/goal',
                    Icons.lightbulb_outline, primaryColor),
                _buildRuleItem(6, 'Follow a healthy diet',
                    Icons.restaurant_menu, primaryColor),
                _buildRuleItem(
                    7, 'Track your progress', Icons.trending_up, primaryColor),
              ],
            ),

            SizedBox(height: 24),

            // --- Benefits Section ---
            _buildSectionCard(
              title: 'UNLOCK YOUR POTENTIAL',
              icon: Icons.emoji_events_outlined,
              iconColor:
                  accentColor, // Use a different color for visual distinction
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              cardDecoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.2),
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                  border: Border.all(
                      color: accentColor.withOpacity(0.5), width: 1.5)),
              children: [
                _buildBenefitItem('Build unbreakable discipline',
                    Icons.shield_outlined, accentColor),
                _buildBenefitItem('Increase mental toughness',
                    Icons.psychology_outlined, accentColor),
                _buildBenefitItem('Form lasting healthy habits',
                    Icons.all_inclusive, accentColor),
                _buildBenefitItem('Boost confidence & self-esteem',
                    Icons.thumb_up_alt_outlined, accentColor),
                _buildBenefitItem('Achieve your goals faster',
                    Icons.rocket_launch_outlined, accentColor),
              ],
            ),

            SizedBox(height: 32),

            // --- Start Button ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: ElevatedButton(
                onPressed: _startChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                  shadowColor: primaryColor.withOpacity(0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'START THE CHALLENGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 80), // More space at the bottom
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection(Color primaryColor) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        // Background image
        Container(
          height: 300,
          decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/project50.png'),
                fit: BoxFit.cover,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                )
              ]),
        ),
        // Dark overlay
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: Colors.black
                .withOpacity(0.3), // Same opacity as your ColorFilter
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
        ),
        // Your existing positioned content
        Positioned(
          top: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                'PROJECT 50',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.5,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        blurRadius: 10.0,
                        color: Colors.black.withOpacity(0.5),
                        offset: Offset(2.0, 2.0)),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'A Mental Toughness Challenge',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.9),
                  shadows: [
                    Shadow(
                        blurRadius: 5.0,
                        color: Colors.black.withOpacity(0.5),
                        offset: Offset(1.0, 1.0)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(0, 25),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.5),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              '50 DAYS OF CONSISTENCY',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
    EdgeInsetsGeometry? contentPadding,
    BoxDecoration? cardDecoration,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: contentPadding ?? EdgeInsets.all(20),
      decoration: cardDecoration ??
          BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          Divider(height: 24, thickness: 1, color: iconColor.withOpacity(0.3)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRuleItem(
      int number, String rule, IconData icon, Color themeColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              // color: themeColor.withOpacity(0.15),
              // shape: BoxShape.circle,
              // border: Border.all(color: themeColor, width: 2)
              gradient: LinearGradient(
                colors: [themeColor, themeColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Icon(icon, color: themeColor, size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              rule,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String benefit, IconData icon, Color themeColor) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: themeColor, size: 22),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              benefit,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to display the countdown until challenge starts
  String _timeUntilStart() {
    Duration timeLeft = _challengeStartDate!.difference(DateTime.now());
    int hours = timeLeft.inHours % 24;
    int minutes = timeLeft.inMinutes % 60;

    return '${timeLeft.inDays} days, $hours hours, $minutes minutes';
  }

  Widget _buildOverviewTab() {
    // Calculate days completed (days where all tasks are completed)
    int daysCompleted = 0;
    for (int i = 1; i <= 50; i++) {
      if (_tasksByDay.containsKey(i)) {
        bool allCompleted = _tasksByDay[i]!.every((task) => task.isCompleted);
        if (allCompleted) {
          daysCompleted++;
        }
      }
    }

    bool challengeStarted = DateTime.now().isAfter(_challengeStartDate!);

    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit
              .cover, // You can change this to BoxFit.fill, BoxFit.contain, etc.
        ),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          overscroll: false, // Disable overscroll
          physics: ClampingScrollPhysics(), // Use clamping physics
        ),
        child: SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Card
              Card(
                elevation: 2,
                color: Colors.white.withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          challengeStarted
                              ? 'YOUR PROGRESS'
                              : 'CHALLENGE COMING SOON',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 10),

                        if (challengeStarted)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Ends on ${DateFormat('MMMM d, yyyy').format(_challengeEndDate!)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        SizedBox(height: 24),

                        // Show different UI based on whether the challenge has started
                        if (challengeStarted)
                          // Original progress UI
                          CircularPercentIndicator(
                            radius: 120,
                            lineWidth: 15,
                            percent: daysCompleted / 50,
                            center: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 100,
                                  width: 100,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.center,
                                    children: [
                                      if (_currentDay > 1)
                                        Positioned(
                                          top: -30,
                                          child: Image.asset(
                                            'assets/images/fire.png',
                                            width: 150,
                                            height: 150,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      Positioned(
                                        bottom: 0,
                                        child: Text(
                                          '$daysCompleted',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  'days completed',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            progressColor: Theme.of(context).primaryColor,
                            backgroundColor: Colors.grey[300]!,
                            circularStrokeCap: CircularStrokeCap.round,
                            animation: true,
                            animationDuration: 1500,
                          )
                        else
                          // Coming soon UI
                          Container(
                            height: 280,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 200,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.3),
                                        spreadRadius: 2,
                                        blurRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        Icons.hourglass_top,
                                        size: 80,
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withOpacity(0.7),
                                      ),
                                      Positioned(
                                        bottom: 40,
                                        child: Text(
                                          'Starts Tomorrow',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),
                                Text(
                                  _timeUntilStart(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        SizedBox(height: 24),

                        // Show stats or get ready message based on challenge status
                        if (challengeStarted)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatItem('Current Day',
                                  _currentDay.toString(), Icons.calendar_today),
                              _buildStatItem(
                                  'Days Left',
                                  (50 - daysCompleted).toString(),
                                  Icons.timelapse),
                              _buildStatItem(
                                  'Tasks Done',
                                  '$_completedTasks/${7 * 50}',
                                  Icons.check_circle),
                            ],
                          )
                        else
                          Container(
                            padding: EdgeInsets.symmetric(
                                vertical: 16, horizontal: 20),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tips_and_updates,
                                  color: Theme.of(context).primaryColor,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Get ready! Your 50-day challenge starts tomorrow. Set your goals and prepare to succeed!',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12),

              WeeklyProgressCard(currentDay: _currentDay),

              SizedBox(height: 12),

              // Category Completion
              Card(
                elevation: 2,
                color: Colors.white.withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
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
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CATEGORY COMPLETION',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(height: 20),
                          _buildCategoryProgressBar(
                              'Morning', 'Wake up by 8am & Morning routine'),
                          SizedBox(height: 12),
                          _buildCategoryProgressBar(
                              'Health', 'Exercise & Healthy diet'),
                          SizedBox(height: 12),
                          _buildCategoryProgressBar(
                              'Learning', 'Read 10 pages'),
                          SizedBox(height: 12),
                          _buildCategoryProgressBar('Growth', 'New skill/goal'),
                          SizedBox(height: 12),
                          _buildCategoryProgressBar(
                              'Accountability', 'Track progress'),
                          SizedBox(height: 18),
                          if (_currentDay >= 2)
                            Center(
                              child: buildSummaryButton(),
                              // child: ElevatedButton.icon(
                              //   onPressed: () {
                              //     Navigator.push(
                              //         context,
                              //         MaterialPageRoute(
                              //             builder: (context) =>
                              //                 Project50SummaryPage()));
                              //   },
                              //   icon: Icon(Icons.bar_chart, size: 20),
                              //   label: Text('View Summary'),
                              //   style: ElevatedButton.styleFrom(
                              //     padding: EdgeInsets.symmetric(
                              //         horizontal: 20, vertical: 14),
                              //     shape: RoundedRectangleBorder(
                              //       borderRadius: BorderRadius.circular(12),
                              //     ),
                              //     textStyle: TextStyle(
                              //         fontSize: 16, fontWeight: FontWeight.w500),
                              //   ),
                              // ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 12),

              // Motivation Quote
              Card(
                elevation: 0,
                color: Colors.white.withOpacity(0.7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
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
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1.5,
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
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.format_quote,
                            size: 40,
                            color: Theme.of(context).primaryColor,
                          ),
                          SizedBox(height: 12),
                          Text(
                            '"Discipline is the bridge between goals and accomplishment."',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '- Jim Rohn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              ChallengeResetButton(onReset: _resetChallenge),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSummaryButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.3),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Project50SummaryPage(),
              ),
            );
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: 8),
                Text(
                  'View Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: 28,
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekProgressBar(int week) {
    // Calculate week completion
    int startDay = (week - 1) * 7 + 1;
    int endDay = week * 7;
    if (endDay > 50) endDay = 50;

    int totalTasksCompleted = 0;
    int totalTasks = 0;

    for (int day = startDay; day <= endDay; day++) {
      if (_tasksByDay.containsKey(day)) {
        totalTasks += _tasksByDay[day]!.length;
        totalTasksCompleted +=
            _tasksByDay[day]!.where((task) => task.isCompleted).length;
      }
    }

    double progress = totalTasks > 0 ? totalTasksCompleted / totalTasks : 0.0;

    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Week $week (Days $startDay-$endDay)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          LinearPercentIndicator(
            lineHeight: 12,
            percent: progress,
            progressColor: Theme.of(context).primaryColor,
            backgroundColor: Colors.grey[300],
            barRadius: Radius.circular(8),
            trailing: Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            animation: true,
            animationDuration: 1000,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProgressBar(String category, String description) {
    // Calculate category completion
    int totalTasksInCategory = 0;
    int completedTasksInCategory = 0;

    for (var tasks in _tasksByDay.values) {
      for (var task in tasks) {
        if (task.category == category) {
          totalTasksInCategory++;
          if (task.isCompleted) {
            completedTasksInCategory++;
          }
        }
      }
    }

    double progress = totalTasksInCategory > 0
        ? completedTasksInCategory / totalTasksInCategory
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              category,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$completedTasksInCategory/$totalTasksInCategory',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        LinearPercentIndicator(
          lineHeight: 10,
          percent: progress,
          progressColor: _getCategoryColor(category),
          backgroundColor: Colors.grey[300],
          barRadius: Radius.circular(8),
          animation: true,
          animationDuration: 1000,
        ),
      ],
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Morning':
        return Colors.orange;
      case 'Health':
        return Colors.green;
      case 'Learning':
        return Colors.blue;
      case 'Growth':
        return Colors.purple;
      case 'Accountability':
        return Colors.teal;
      default:
        return Theme.of(context).primaryColor;
    }
  }

  Widget _buildDailyTasksTab() {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit
              .cover, // You can change this to BoxFit.fill, BoxFit.contain, etc.
        ),
      ),
      child: Column(
        children: [
          // Enhanced day selector with better scrolling behavior
          Container(
            height: 70,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 50,
              padding: EdgeInsets.symmetric(horizontal: 12),
              itemBuilder: (context, index) {
                final day = index + 1;
                final isSelected = day == _selectedDay;
                final isLocked = day > _currentDay;

                // Check if day is completed
                bool isDayCompleted = false;
                if (_tasksByDay.containsKey(day)) {
                  isDayCompleted =
                      _tasksByDay[day]!.every((task) => task.isCompleted);
                }

                // Determine the background color based on day status
                Color bgColor;
                IconData statusIcon;

                if (isLocked) {
                  bgColor = Colors.grey[200]!;
                  statusIcon = Icons.lock;
                } else if (isSelected) {
                  bgColor = Theme.of(context).primaryColor;
                  statusIcon = Icons.calendar_today;
                } else if (isDayCompleted) {
                  bgColor = Colors.green;
                  statusIcon = Icons.check_circle;
                } else if (day < _selectedDay) {
                  bgColor = Colors.orange;
                  statusIcon = Icons.warning;
                } else {
                  bgColor = Colors.grey[400]!;
                  statusIcon = Icons.circle_outlined;
                }

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 3),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      width: isSelected ? 60 : 50,
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            day.toString(),
                            style: TextStyle(
                              color: isLocked ? Colors.grey[600] : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: isSelected ? 18 : 16,
                            ),
                          ),
                          SizedBox(height: 2),
                          Icon(
                            statusIcon,
                            color: isLocked ? Colors.grey[600] : Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Content area for the selected day
          Expanded(
            child: _selectedDay <= _currentDay
                ? AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: _buildDayContent(),
                  )
                : _buildLockedDayContent(),
          ),
        ],
      ),
    );
  }

// Extracted day content into a separate method for better maintainability
  Widget _buildDayContent() {
    // Check if we have tasks for this day
    final hasTasks = _tasksByDay.containsKey(_selectedDay) &&
        _tasksByDay[_selectedDay]!.isNotEmpty;

    if (!hasTasks) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.pending_actions,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No tasks available for Day $_selectedDay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () async {
                // This would need to be implemented to refresh or generate tasks
                await _loadProject50Data();
              },
              icon: Icon(Icons.refresh),
              label: Text('Refresh Tasks'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Day Info Card with completion status
        Padding(
          padding: EdgeInsets.all(16),
          child: Card(
            color: Colors.white.withOpacity(0.85),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            'DAY $_selectedDay',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          SizedBox(width: 8),
                          _getDayStatusIndicator(),
                        ],
                      ),
                      Text(
                        _formatDate(_tasksByDay[_selectedDay]!.first.time),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),

                  // Task completion stats
                  Row(
                    children: [
                      Icon(
                        Icons.checklist,
                        size: 20,
                        color: Theme.of(context).primaryColor,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${_tasksByDay[_selectedDay]!.where((task) => task.isCompleted).length}/${_tasksByDay[_selectedDay]!.length} tasks completed',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),

                  // Enhanced progress indicator
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _tasksByDay[_selectedDay]!
                              .where((task) => task.isCompleted)
                              .length /
                          _tasksByDay[_selectedDay]!.length,
                      minHeight: 10,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getDayProgressColor(),
                      ),
                    ),
                  ),

                  // Optional: Task categories summary
                  if (_tasksByDay[_selectedDay]!.length > 3) ...[
                    SizedBox(height: 12),
                    _buildCategorySummary(),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Tasks List with animations
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              overscroll: false,
              physics: ClampingScrollPhysics(),
            ),
            child: ListView.builder(
              key: PageStorageKey('tasks_day_$_selectedDay'),
              padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              physics: ClampingScrollPhysics(),
              itemCount:
                  _tasksByDay[_selectedDay]!.length + 1, // Add 1 for spacing
              itemBuilder: (context, index) {
                // Return empty space for the last item
                if (index == _tasksByDay[_selectedDay]!.length) {
                  return SizedBox(height: 10); // Empty space at bottom
                }

                final task = _tasksByDay[_selectedDay]![index];
                return AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: 1.0,
                  curve: Curves.easeInOut,
                  child: _buildTaskCard(task, index),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

// Extracted locked day content into a separate method
  Widget _buildLockedDayContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock,
              size: 64,
              color: Colors.grey[500],
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Day $_selectedDay is locked',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Complete all tasks from previous days to unlock this day in your challenge journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ),
          SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to the first incomplete day
              setState(() {
                _selectedDay = _findFirstIncompleteDay();
              });
            },
            icon: Icon(Icons.arrow_back),
            label: Text('Go to current day'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Project50Task task, int index) {
    return Card(
      elevation: 2,
      color: Colors.white.withOpacity(0.85),
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: task.isCompleted ? Colors.green : Colors.transparent,
          width: task.isCompleted ? 1 : 0,
        ),
      ),
      child: InkWell(
        onTap: () => _showTaskFeatureDialog(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Task category icon with more visual appeal
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _getCategoryColor(task.category).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _getCategoryColor(task.category).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    _getCategoryIcon(task.category),
                    color: _getCategoryColor(task.category),
                    size: 26,
                  ),
                ),
              ),
              SizedBox(width: 16),

              // Task details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // if (task.title.contains("Failed"))
                    //   Text(
                    //     "⚠️ Failed",
                    //     style: TextStyle(color: Colors.red),
                    //   ),
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.title.contains("Failed")
                            ? Colors.red
                            : (task.isCompleted
                                ? Colors.grey[600]
                                : Colors.black87),
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(task.category)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            task.category,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _getCategoryColor(task.category),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Tap info hint
                        Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              size: 14,
                              color: Colors.grey[500],
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Tap for tips',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Checkbox - only this will toggle completion
              GestureDetector(
                onTap: () => _toggleTaskCompletion(task),
                child: Container(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: Theme(
                      data: ThemeData(
                        unselectedWidgetColor: Colors.grey[400],
                      ),
                      child: Transform.scale(
                        scale: 1.2,
                        child: Checkbox(
                          value: task.isCompleted,
                          onChanged: (value) => _toggleTaskCompletion(task),
                          activeColor: Colors.green,
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Task Feature Dialog ----------

  void _showTaskFeatureDialog(Project50Task task) {
    String title = '';

    if (task.title.contains('Wake up by')) {
      _handleWakeUpTask(task);
    } else if (task.title.contains('1 hour morning routine')) {
      _handleDeepWorkTask(task);
    } else if (task.title.contains('Exercise for 1 hour')) {
      _handleExerciseTask(task);
    } else if (task.title.contains('Read 10 pages')) {
      _handleReadingTask(task);
    } else if (task.title.contains('1 hour towards new skill/goal')) {
      _handleSkillDevelopmentTask(task);
    } else if (task.title.contains('Follow a healthy diet')) {
      _handleHealthyDietTask(task);
    } else if (task.title.contains('Track your progress')) {
      _handleDailyProgressTask(task);
    }
  }

  void _showTaskSuggestionDialog(Project50Task task) {
    Widget _buildTipItem({
      required IconData icon,
      required String title,
      required String description,
    }) {
      return Padding(
        padding: EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getCategoryColor(task.category).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: _getCategoryColor(task.category),
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    String title = '';
    List<Map<String, dynamic>> tipItems = [];
    IconData headerIcon = Icons.lightbulb_outline;
    Color color = _getCategoryColor(task.category);

    // Define suggestions based on task title
    if (task.title == 'Wake up by 8am') {
      title = 'Morning Wake-Up Tips';
      headerIcon = Icons.wb_sunny;
      tipItems = [
        {
          'icon': Icons.alarm_off,
          'title': 'Move Your Alarm',
          'description':
              'Place your alarm clock away from your bed to force getting up',
        },
        {
          'icon': Icons.wb_sunny_outlined,
          'title': 'Natural Light',
          'description': 'Open curtains immediately for natural light exposure',
        },
        {
          'icon': Icons.checkroom,
          'title': 'Prepare Ahead',
          'description': 'Prepare your morning clothes the night before',
        },
        {
          'icon': Icons.calendar_today,
          'title': 'Consistent Schedule',
          'description':
              'Create a consistent sleep schedule (even on weekends)',
        },
        {
          'icon': Icons.smartphone,
          'title': 'Smart Alarm',
          'description': 'Try an app that wakes you during light sleep phases',
        },
        {
          'icon': Icons.do_not_disturb,
          'title': 'Screen-Free Time',
          'description': 'Avoid screens at least 30 minutes before bedtime',
        },
        {
          'icon': Icons.nightlight_round,
          'title': 'Bedtime Routine',
          'description':
              'Create a relaxing bedtime routine to improve sleep quality',
        },
      ];
    } else if (task.title == '1 hour morning routine') {
      title = 'Effective Morning Routine Ideas';
      headerIcon = Icons.format_list_bulleted;
      tipItems = [
        {
          'icon': Icons.water_drop,
          'title': 'Hydration First',
          'description': '10min: Hydrate with a glass of water',
        },
        {
          'icon': Icons.self_improvement,
          'title': 'Meditation',
          'description': '15min: Meditation or deep breathing',
        },
        {
          'icon': Icons.edit_note,
          'title': 'Journaling',
          'description': '10min: Journaling or gratitude practice',
        },
        {
          'icon': Icons.accessibility_new,
          'title': 'Morning Movement',
          'description': '10min: Light stretching or yoga',
        },
        {
          'icon': Icons.checklist,
          'title': 'Daily Planning',
          'description': '15min: Plan your day with priorities',
        },
        {
          'icon': Icons.bed,
          'title': 'Make Your Bed',
          'description': 'Creates first accomplishment of the day',
        },
        {
          'icon': Icons.do_not_disturb,
          'title': 'Digital Detox',
          'description': 'Avoid checking email/social media in the first hour',
        },
      ];
    } else if (task.title == 'Exercise for 1 hour') {
      title = 'Exercise Routine Suggestions';
      headerIcon = Icons.fitness_center;
      tipItems = [
        {
          'icon': Icons.sync_alt,
          'title': 'Balanced Workout',
          'description': 'Mix cardio (20min) with strength training (40min)',
        },
        {
          'icon': Icons.timer,
          'title': 'HIIT Training',
          'description': 'Try HIIT workouts for maximum efficiency',
        },
        {
          'icon': Icons.shuffle,
          'title': 'Variety',
          'description': 'Add variety with different activities each day',
        },
        {
          'icon': Icons.group,
          'title': 'Social Exercise',
          'description': 'Find workout buddies for accountability',
        },
        {
          'icon': Icons.flag,
          'title': 'Set Goals',
          'description': 'Set specific goals for each workout session',
        },
        {
          'icon': Icons.trending_up,
          'title': 'Track Progress',
          'description': 'Track your progress with an app or journal',
        },
        {
          'icon': Icons.watch_later,
          'title': 'Complete Routine',
          'description': 'Remember to include warm-up and cool-down time',
        },
      ];
    } else if (task.title == 'Read 10 pages') {
      title = 'Reading Habit Tips';
      headerIcon = Icons.book;
      tipItems = [
        {
          'icon': Icons.schedule,
          'title': 'Dedicated Time',
          'description': 'Dedicate a specific time each day for reading',
        },
        {
          'icon': Icons.weekend,
          'title': 'Reading Space',
          'description': 'Create a comfortable reading environment',
        },
        {
          'icon': Icons.edit,
          'title': 'Active Reading',
          'description': 'Highlight key ideas or take brief notes',
        },
        {
          'icon': Icons.people,
          'title': 'Book Club',
          'description': 'Join a book club for accountability',
        },
        {
          'icon': Icons.category,
          'title': 'Explore Genres',
          'description': 'Try different genres to find what keeps you engaged',
        },
        {
          'icon': Icons.headphones,
          'title': 'Audiobooks',
          'description': 'Use audiobooks during commutes or chores',
        },
      ];
    } else if (task.title == '1 hour towards new skill/goal') {
      title = 'Skill Development Strategies';
      headerIcon = Icons.trending_up;
      tipItems = [
        {
          'icon': Icons.layers,
          'title': 'Break It Down',
          'description': 'Break down your skill into specific sub-skills',
        },
        {
          'icon': Icons.center_focus_strong,
          'title': '80/20 Rule',
          'description': 'Focus on high-impact areas first',
        },
        {
          'icon': Icons.repeat,
          'title': 'Deliberate Practice',
          'description':
              'Use deliberate practice techniques for faster progress',
        },
        {
          'icon': Icons.school,
          'title': 'Find Mentors',
          'description': 'Find mentors or online courses in your area',
        },
        {
          'icon': Icons.flag,
          'title': 'Set Milestones',
          'description': 'Set small, measurable milestones to track progress',
        },
        {
          'icon': Icons.photo_camera,
          'title': 'Document Progress',
          'description': 'Document your progress with photos or videos',
        },
        {
          'icon': Icons.schedule,
          'title': 'Peak Learning',
          'description': 'Schedule learning sessions when you have peak energy',
        },
      ];
    } else if (task.title == 'Follow a healthy diet') {
      title = 'Healthy Eating Strategies';
      headerIcon = Icons.restaurant;
      tipItems = [
        {
          'icon': Icons.kitchen,
          'title': 'Meal Prep',
          'description': 'Meal prep on weekends to save time',
        },
        {
          'icon': Icons.pie_chart,
          'title': 'Plate Method',
          'description':
              'Follow the plate method: ½ vegetables, ¼ protein, ¼ carbs',
        },
        {
          'icon': Icons.water_drop,
          'title': 'Stay Hydrated',
          'description': 'Drink at least 8 glasses of water daily',
        },
        {
          'icon': Icons.egg,
          'title': 'Protein Priority',
          'description': 'Include protein in every meal for satiety',
        },
        {
          'icon': Icons.shopping_basket,
          'title': 'Smart Snacking',
          'description': 'Keep healthy snacks accessible',
        },
        {
          'icon': Icons.phonelink_off,
          'title': 'Mindful Eating',
          'description': 'Practice mindful eating (no screens while eating)',
        },
        {
          'icon': Icons.cake,
          'title': 'Balance',
          'description':
              'Allow yourself occasional treats to avoid feeling deprived',
        },
      ];
    } else if (task.title == 'Track your progress') {
      title = 'Effective Tracking Methods';
      headerIcon = Icons.insert_chart;
      tipItems = [
        {
          'icon': Icons.book,
          'title': 'Journal',
          'description': 'Use a dedicated journal for the challenge',
        },
        {
          'icon': Icons.photo_camera,
          'title': 'Progress Photos',
          'description': 'Take weekly progress photos',
        },
        {
          'icon': Icons.mood,
          'title': 'Track Mood',
          'description': 'Note your energy levels and mood daily',
        },
        {
          'icon': Icons.directions_run,
          'title': 'Overcome Obstacles',
          'description': 'Record obstacles and how you overcame them',
        },
        {
          'icon': Icons.celebration,
          'title': 'Celebrate Wins',
          'description': 'Celebrate small wins and milestones',
        },
        {
          'icon': Icons.calendar_view_week,
          'title': 'Weekly Review',
          'description': 'Review weekly to identify patterns',
        },
      ];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        headerIcon,
                        color: color,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Task title reminder
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getCategoryIcon(task.category),
                        color: color,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.title,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Tips list using _buildTipItem
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var item in tipItems)
                          _buildTipItem(
                            icon: item['icon'],
                            title: item['title'],
                            description: item['description'],
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Close button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Got it',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

// Task-specific functionality implementation

// 1. Wake Up Before 8am
  void _handleWakeUpTask(Project50Task task) {
    print("Sleep Task ID: " + task.id);
    void _saveSleepLog(
        TimeOfDay? bedtime, TimeOfDay? wakeup, int extraMinutes) async {
      // Validate inputs
      if (bedtime == null || wakeup == null) {
        return;
      }

      try {
        // Get current date for the log
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);

        // Calculate sleep duration for storing
        int bedMinutes = bedtime.hour * 60 + bedtime.minute;
        int wakeMinutes = wakeup.hour * 60 + wakeup.minute;

        // Adjust if wakeup is on the next day
        if (wakeMinutes < bedMinutes) {
          wakeMinutes += 24 * 60;
        }

        int totalMinutes = wakeMinutes - bedMinutes;
        int hours = totalMinutes ~/ 60;
        int minutes = totalMinutes % 60;

        // Format times for storage
        String bedtimeStr =
            "${bedtime.hour.toString().padLeft(2, '0')}:${bedtime.minute.toString().padLeft(2, '0')}";
        String wakeupStr =
            "${wakeup.hour.toString().padLeft(2, '0')}:${wakeup.minute.toString().padLeft(2, '0')}";

        // Create sleep log data
        Map<String, dynamic> sleepData = {
          'bedtime': bedtimeStr,
          'wakeup': wakeupStr,
          'sleepDuration': totalMinutes,
          'extraMinutes': extraMinutes,
          'date': today.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Save sleep data to local storage or database for trends
        // This would be implemented separately with a dedicated sleep tracking service

        // Get current task and update its description
        if (task != null && task.id.isNotEmpty) {
          // Clean up old sleep log if it exists
          String baseDescription = task.description;
          if (baseDescription.contains("Sleep Log:")) {
            baseDescription = baseDescription.split("Sleep Log:")[0].trim();
          }

          // Create nicely formatted sleep log info
          String sleepLogInfo = """

Sleep Log:
- Bedtime $bedtimeStr
- Wakeup $wakeupStr
- Duration ${hours}h ${minutes}m (${totalMinutes} minutes)
- Recorded on ${DateFormat('MMM dd, yyyy').format(now)}""";

          // Update task description to include sleep log info
          String updatedDescription = baseDescription + sleepLogInfo;

          // Create updated task object
          Project50Task updatedTask = Project50Task(
            id: task.id,
            title: task.title,
            category: task.category,
            description: updatedDescription,
            time: task.time,
            isCompleted: true, // Mark as completed if wake-up is recorded
            day: task.day,
            createdAt: task.createdAt,
            updatedAt: DateTime.now(),
            orderTask: task.orderTask,
          );

          // Update task in Firestore
          await _project50service.updateProject50TaskDetails(
              task.id, updatedTask);

          print("Sleep log saved successfully!");
        }
      } catch (e) {
        print("Error saving sleep log: $e");
      }
    }

    // Sleep log and adjustment
    void _showSleepLogDialog(Project50Task task) async {
      try {
        // Create loading state while data is being fetched
        bool isLoading = true;
        Map<String, dynamic>? sleepData;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setState) {
                final mediaQuery = MediaQuery.of(context);
                final availableHeight = mediaQuery.size.height -
                    mediaQuery.padding.top -
                    mediaQuery.padding.bottom;
                final bottomSheetHeight = availableHeight * 0.7;
                // Get the category color for styling
                Color primaryColor = _getCategoryColor(task.category);

                // Function to load sleep data from Firestore
                void loadSleepData() async {
                  try {
                    final tasks = await _project50service.getProject50Tasks();
                    final taskFromDb = tasks.firstWhere(
                      (t) => t.id == task.id,
                      orElse: () =>
                          throw Exception("Task not found in sqflite"),
                    );

                    final description = taskFromDb.description ?? '';

                    print(
                        "Description to parse: $description"); // Debugging line

                    // Extract sleep data using regex
                    RegExp bedtimeRegex = RegExp(r'Bedtime (\d{2}:\d{2})');
                    RegExp wakeupRegex = RegExp(r'Wakeup (\d{2}:\d{2})');

                    Match? bedtimeMatch = bedtimeRegex.firstMatch(description);
                    Match? wakeupMatch = wakeupRegex.firstMatch(description);

                    TimeOfDay? selectedBedtime;
                    TimeOfDay? selectedWakeup;

                    bool isBedTimeNull = false;
                    bool isWakeUpNull = false;

                    if (bedtimeMatch != null) {
                      String bedtimeStr = bedtimeMatch.group(1)!;
                      List<String> parts = bedtimeStr.split(':');
                      selectedBedtime = TimeOfDay(
                        hour: int.parse(parts[0]),
                        minute: int.parse(parts[1]),
                      );
                    } else {
                      isBedTimeNull = true;
                    }

                    if (wakeupMatch != null) {
                      String wakeupStr = wakeupMatch.group(1)!;
                      List<String> parts = wakeupStr.split(':');
                      selectedWakeup = TimeOfDay(
                        hour: int.parse(parts[0]),
                        minute: int.parse(parts[1]),
                      );
                    } else {
                      isWakeUpNull = true;
                    }

                    // Default to current time for missing values
                    selectedBedtime ??= TimeOfDay.now();
                    // selectedWakeup ??= TimeOfDay(
                    //   hour: (TimeOfDay.now().hour + 8) % 24,
                    //   minute: TimeOfDay.now().minute,
                    // );
                    selectedWakeup ??= TimeOfDay(hour: 08, minute: 00);

                    setState(() {
                      sleepData = {
                        'bedtime': selectedBedtime,
                        'wakeup': selectedWakeup,
                        'description':
                            description.split("Sleep Log:")[0].trim(),
                        'adjustedGoal': false,
                        'extraMinutes': 0,
                        'isBedTimeNull': isBedTimeNull,
                        'isWakeUpNull': isWakeUpNull,
                      };
                      isLoading = false;
                    });
                  } catch (e) {
                    print("Error loading sleep data: $e");
                    setState(() {
                      isLoading = false;
                      sleepData = null;
                    });
                  }
                }

                // Load data when dialog is first shown
                if (isLoading && sleepData == null) {
                  loadSleepData();
                }

                // Calculate sleep duration and health indicators if data is available
                String sleepDuration = '';
                bool isHealthySleep = false;
                double sleepHealth = 0.0;

                if (!isLoading && sleepData != null) {
                  TimeOfDay bedtime = sleepData!['bedtime'];
                  TimeOfDay wakeup = sleepData!['wakeup'];

                  int bedMinutes = bedtime.hour * 60 + bedtime.minute;
                  int wakeMinutes = wakeup.hour * 60 + wakeup.minute;

                  // Adjust if wakeup is on the next day
                  if (wakeMinutes < bedMinutes) {
                    wakeMinutes += 24 * 60;
                  }

                  int totalMinutes = wakeMinutes - bedMinutes;
                  int hours = totalMinutes ~/ 60;
                  int minutes = totalMinutes % 60;

                  sleepDuration = '$hours hrs $minutes min';

                  // Check if sleep duration is healthy (7-9 hours)
                  isHealthySleep = totalMinutes >= 420 && totalMinutes <= 540;

                  // Calculate sleep health percentage (100% = 8 hours)
                  sleepHealth = totalMinutes / 480;
                  if (sleepHealth > 1.2)
                    sleepHealth = 0.7; // Penalize oversleeping
                  sleepHealth = sleepHealth.clamp(0.0, 1.0);
                }

                Color sleepHealthColor = isHealthySleep
                    ? Colors.green
                    : (sleepHealth > 0.7 ? Colors.orange : Colors.red);

                return Container(
                  height: bottomSheetHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: primaryColor),
                                SizedBox(height: 16),
                                Text("Loading sleep details...")
                              ],
                            ),
                          )
                        : sleepData == null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.nightlight,
                                        size: 50, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      "No sleep data found for this task",
                                      style: TextStyle(fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 20),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text("CLOSE"),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Header with nice sleep icon
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.nightlight_round,
                                          color: primaryColor,
                                          size: 28,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          "Sleep Tracker",
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 15),

                                    // Task details container
                                    Container(
                                      margin: EdgeInsets.only(bottom: 15),
                                      padding: EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: primaryColor.withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.task_alt,
                                                  color: primaryColor,
                                                  size: 18),
                                              SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  task.title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            sleepData!['description'] ?? '',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(Icons.calendar_today,
                                                  size: 14,
                                                  color: Colors.grey[600]),
                                              SizedBox(width: 5),
                                              Text(
                                                "Day ${task.day}",
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[600],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Sleep duration indicator with visual elements
                                    if (sleepDuration.isNotEmpty)
                                      Container(
                                        margin: EdgeInsets.only(bottom: 15),
                                        padding: EdgeInsets.symmetric(
                                            vertical: 15, horizontal: 15),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  Colors.grey.withOpacity(0.2),
                                              spreadRadius: 1,
                                              blurRadius: 4,
                                              offset: Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.access_time,
                                                  color: sleepHealthColor,
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  "Sleep Duration: $sleepDuration",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: Colors.grey[800],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 15),

                                            // Sleep quality progress bar
                                            Container(
                                              height: 12,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                color: Colors.grey[300],
                                              ),
                                              child: Stack(
                                                children: [
                                                  FractionallySizedBox(
                                                    widthFactor: sleepHealth,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        color: sleepHealthColor,
                                                        gradient:
                                                            LinearGradient(
                                                          colors: [
                                                            sleepHealthColor
                                                                .withOpacity(
                                                                    0.7),
                                                            sleepHealthColor,
                                                          ],
                                                          begin: Alignment
                                                              .centerLeft,
                                                          end: Alignment
                                                              .centerRight,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            SizedBox(height: 8),

                                            // Sleep quality labels
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text('5h',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey)),
                                                Text('7h',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey)),
                                                Text('8h',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                Text('9h',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey)),
                                                Text('10h+',
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey)),
                                              ],
                                            ),

                                            SizedBox(height: 12),
                                            Text(
                                              isHealthySleep
                                                  ? "✓ Healthy sleep (7-9 hours recommended)"
                                                  : "! Aim for 7-9 hours of sleep",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: sleepHealthColor,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    // Sleep time cards with improved UI and save status indicators
                                    Row(
                                      children: [
                                        // Bedtime card
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              final TimeOfDay? time =
                                                  await showTimePicker(
                                                context: context,
                                                initialTime:
                                                    sleepData!['bedtime'],
                                                builder: (context, child) {
                                                  return Theme(
                                                    data: Theme.of(context)
                                                        .copyWith(
                                                      colorScheme:
                                                          ColorScheme.light(
                                                        primary: primaryColor,
                                                      ),
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );
                                              if (time != null) {
                                                setState(() {
                                                  sleepData!['bedtime'] = time;
                                                  sleepData!['isBedTimeNull'] =
                                                      false;
                                                });
                                              }
                                            },
                                            child: Card(
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                side: BorderSide(
                                                  color: sleepData![
                                                          'isBedTimeNull']
                                                      ? Colors.grey
                                                          .withOpacity(0.3)
                                                      : primaryColor
                                                          .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Stack(
                                                children: [
                                                  // Status indicator
                                                  if (!sleepData![
                                                      'isBedTimeNull'])
                                                    Positioned(
                                                      top: 10,
                                                      right: 10,
                                                      child: Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.green,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                    ),

                                                  Padding(
                                                    padding: EdgeInsets.all(15),
                                                    child: Column(
                                                      children: [
                                                        Icon(
                                                          Icons.bedtime,
                                                          color: sleepData![
                                                                  'isBedTimeNull']
                                                              ? Colors.grey
                                                              : primaryColor,
                                                          size: 24,
                                                        ),
                                                        SizedBox(height: 10),
                                                        Text(
                                                          "Bedtime",
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        SizedBox(height: 5),
                                                        Text(
                                                          sleepData![
                                                                  'isBedTimeNull']
                                                              ? "Not Set"
                                                              : sleepData![
                                                                      'bedtime']
                                                                  .format(
                                                                      context),
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: sleepData![
                                                                    'isBedTimeNull']
                                                                ? Colors.grey
                                                                : primaryColor,
                                                          ),
                                                        ),
                                                        SizedBox(height: 8),
                                                        ElevatedButton(
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor: sleepData![
                                                                    'isBedTimeNull']
                                                                ? Colors.blue
                                                                    .withOpacity(
                                                                        0.1)
                                                                : primaryColor
                                                                    .withOpacity(
                                                                        0.1),
                                                            foregroundColor:
                                                                sleepData![
                                                                        'isBedTimeNull']
                                                                    ? Colors
                                                                        .blue
                                                                    : primaryColor,
                                                            elevation: 0,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                            ),
                                                            minimumSize: Size(
                                                                double.infinity,
                                                                30),
                                                          ),
                                                          onPressed: () {
                                                            setState(() {
                                                              sleepData![
                                                                      'bedtime'] =
                                                                  TimeOfDay
                                                                      .now();
                                                              sleepData![
                                                                      'isBedTimeNull'] =
                                                                  false;
                                                            });
                                                          },
                                                          child: Text(sleepData![
                                                                  'isBedTimeNull']
                                                              ? "Set Now"
                                                              : "Update"),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),

                                        // Wake-up card
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () async {
                                              final TimeOfDay? time =
                                                  await showTimePicker(
                                                context: context,
                                                initialTime:
                                                    sleepData!['wakeup'],
                                                builder: (context, child) {
                                                  return Theme(
                                                    data: Theme.of(context)
                                                        .copyWith(
                                                      colorScheme:
                                                          ColorScheme.light(
                                                        primary: primaryColor,
                                                      ),
                                                    ),
                                                    child: child!,
                                                  );
                                                },
                                              );
                                              if (time != null) {
                                                setState(() {
                                                  sleepData!['wakeup'] = time;
                                                  sleepData!['isWakeUpNull'] =
                                                      false;
                                                });
                                              }
                                            },
                                            child: Card(
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                side: BorderSide(
                                                  color:
                                                      sleepData!['isWakeUpNull']
                                                          ? Colors.grey
                                                              .withOpacity(0.3)
                                                          : primaryColor
                                                              .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: Stack(
                                                children: [
                                                  // Status indicator
                                                  if (!sleepData![
                                                      'isWakeUpNull'])
                                                    Positioned(
                                                      top: 10,
                                                      right: 10,
                                                      child: Container(
                                                        width: 12,
                                                        height: 12,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.green,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                      ),
                                                    ),

                                                  Padding(
                                                    padding: EdgeInsets.all(15),
                                                    child: Column(
                                                      children: [
                                                        Icon(
                                                          Icons.wb_sunny,
                                                          color: sleepData![
                                                                  'isWakeUpNull']
                                                              ? Colors.grey
                                                              : primaryColor,
                                                          size: 24,
                                                        ),
                                                        SizedBox(height: 10),
                                                        Text(
                                                          "Wake Up",
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        SizedBox(height: 5),
                                                        Text(
                                                          sleepData![
                                                                  'isWakeUpNull']
                                                              ? "Not Set"
                                                              : sleepData![
                                                                      'wakeup']
                                                                  .format(
                                                                      context),
                                                          style: TextStyle(
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            color: sleepData![
                                                                    'isWakeUpNull']
                                                                ? Colors.grey
                                                                : primaryColor,
                                                          ),
                                                        ),
                                                        SizedBox(height: 8),
                                                        ElevatedButton(
                                                          style: ElevatedButton
                                                              .styleFrom(
                                                            backgroundColor: sleepData![
                                                                    'isWakeUpNull']
                                                                ? Colors.blue
                                                                    .withOpacity(
                                                                        0.1)
                                                                : primaryColor
                                                                    .withOpacity(
                                                                        0.1),
                                                            foregroundColor:
                                                                sleepData![
                                                                        'isWakeUpNull']
                                                                    ? Colors
                                                                        .blue
                                                                    : primaryColor,
                                                            elevation: 0,
                                                            shape:
                                                                RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          20),
                                                            ),
                                                            minimumSize: Size(
                                                                double.infinity,
                                                                30),
                                                          ),
                                                          onPressed: () {
                                                            if (TimeOfDay.now()
                                                                .isAfter(TimeOfDay(
                                                                    hour: 8,
                                                                    minute:
                                                                        00))) {
                                                              // Show the custom dialog when it's after 8:00 AM
                                                              showDialog(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (BuildContext
                                                                        context) {
                                                                  return Dialog(
                                                                    backgroundColor:
                                                                        Colors
                                                                            .transparent,
                                                                    elevation:
                                                                        0,
                                                                    child:
                                                                        Container(
                                                                      padding:
                                                                          EdgeInsets.all(
                                                                              20),
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: Colors
                                                                            .white,
                                                                        borderRadius:
                                                                            BorderRadius.circular(20),
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                            color:
                                                                                Colors.orange.withOpacity(0.3),
                                                                            spreadRadius:
                                                                                5,
                                                                            blurRadius:
                                                                                7,
                                                                            offset:
                                                                                Offset(0, 3),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                      child:
                                                                          Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          // Sleepy emoji face
                                                                          Container(
                                                                            padding:
                                                                                EdgeInsets.all(15),
                                                                            decoration:
                                                                                BoxDecoration(
                                                                              color: Colors.orange.shade100,
                                                                              shape: BoxShape.circle,
                                                                            ),
                                                                            child:
                                                                                Icon(
                                                                              Icons.bedtime_rounded,
                                                                              color: Colors.orange.shade700,
                                                                              size: 50,
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                              height: 20),

                                                                          // Message
                                                                          Text(
                                                                            "Oops! Early bird missed the worm!",
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 18,
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.orange.shade800,
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                              height: 15),

                                                                          Text(
                                                                            "It's past 8:00 AM! For the best sleep tracking results, try to wake up earlier tomorrow.",
                                                                            textAlign:
                                                                                TextAlign.center,
                                                                            style:
                                                                                TextStyle(
                                                                              fontSize: 16,
                                                                              color: Colors.grey.shade700,
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                              height: 25),

                                                                          // Action buttons
                                                                          Row(
                                                                            mainAxisAlignment:
                                                                                MainAxisAlignment.spaceEvenly,
                                                                            children: [
                                                                              TextButton(
                                                                                onPressed: () {
                                                                                  Navigator.of(context).pop();
                                                                                },
                                                                                child: Text(
                                                                                  "Try again tomorrow",
                                                                                  style: TextStyle(
                                                                                    color: Colors.grey.shade700,
                                                                                    fontSize: 15,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              ElevatedButton(
                                                                                style: ElevatedButton.styleFrom(
                                                                                  backgroundColor: Colors.orange.shade500,
                                                                                  foregroundColor: Colors.white,
                                                                                  shape: RoundedRectangleBorder(
                                                                                    borderRadius: BorderRadius.circular(30),
                                                                                  ),
                                                                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                                                                ),
                                                                                onPressed: () {
                                                                                  Navigator.of(context).pop();
                                                                                  // Record anyway
                                                                                  setState(() {
                                                                                    sleepData!['wakeup'] = TimeOfDay.now();
                                                                                    sleepData!['isWakeUpNull'] = false;
                                                                                  });
                                                                                },
                                                                                child: Text(
                                                                                  "Just Record",
                                                                                  style: TextStyle(fontSize: 15),
                                                                                ),
                                                                              ),
                                                                            ],
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                              );
                                                            } else {
                                                              // If before 8:00 AM, record as normal
                                                              setState(() {
                                                                sleepData![
                                                                        'wakeup'] =
                                                                    TimeOfDay
                                                                        .now();
                                                                sleepData![
                                                                        'isWakeUpNull'] =
                                                                    false;
                                                              });
                                                            }
                                                          },
                                                          child: Text(sleepData![
                                                                  'isWakeUpNull']
                                                              ? "Set Now"
                                                              : "Update"),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    SizedBox(height: 25),

                                    // Bottom buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey[200],
                                              foregroundColor: Colors.black87,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12),
                                              child: Text("CANCEL"),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                            ),
                                            onPressed: () {
                                              // Create the updated description with sleep log
                                              String formattedBedtime =
                                                  "${sleepData!['bedtime'].hour.toString().padLeft(2, '0')}:${sleepData!['bedtime'].minute.toString().padLeft(2, '0')}";
                                              String formattedWakeup =
                                                  "${sleepData!['wakeup'].hour.toString().padLeft(2, '0')}:${sleepData!['wakeup'].minute.toString().padLeft(2, '0')}";

                                              String updatedDescription =
                                                  "${sleepData!['description']}\nSleep Log: Bedtime $formattedBedtime - Wakeup $formattedWakeup - $sleepDuration";

                                              try {
                                                // Update the task in sqflite using Project50Service
                                                _project50service
                                                    .updateProject50TaskDetails(
                                                  task.id,
                                                  Project50Task(
                                                    id: task.id,
                                                    title: task.title,
                                                    category: task.category,
                                                    description:
                                                        updatedDescription,
                                                    time: task.time,
                                                    isCompleted:
                                                        task.isCompleted,
                                                    day: task.day,
                                                    createdAt: task.createdAt,
                                                    updatedAt: DateTime
                                                        .now(), // Updated timestamp
                                                    orderTask: task.orderTask,
                                                  ),
                                                );

                                                // Close dialog and refresh
                                                Navigator.of(context).pop();
                                                // Optionally refresh UI (e.g., reload tasks)
                                                _loadProject50Data(); // Assuming this method exists in your screen
                                              } catch (e) {
                                                print(
                                                    "Error updating sleep data: $e");
                                                // Show error message to user
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          "Error updating sleep data: $e")),
                                                );
                                              }
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 12),
                                              child: Text("SAVE"),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                  ),
                );
              },
            );
          },
        );
      } catch (e) {
        print("Error showing sleep log dialog: $e");
      }
    }

    // Main function to handle wake-up task interaction
    void _showWakeUpTaskOptions() {
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Wake Up Task",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                OptionCard(
                  icon: Icons.bedtime,
                  color: _getCategoryColor(task.category),
                  title: "Log Sleep & History",
                  description:
                      "Track your sleep and adjust tomorrow's wake-up time",
                  onTap: () {
                    Navigator.pop(context);
                    _showSleepLogDialog(task);
                  },
                ),
                OptionCard(
                  icon: Icons.tips_and_updates,
                  color: _getCategoryColor(task.category),
                  title: "View Wake-Up Tips",
                  description: "Get strategies for waking up consistently",
                  onTap: () {
                    Navigator.pop(context);
                    _showTaskSuggestionDialog(task);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    // Entry point - call this when user interacts with wake-up task
    _showWakeUpTaskOptions();
  }

// 2. Deep Work (1 hour)
  void _handleDeepWorkTask(Project50Task task) {
    // Track audio state
    bool isWhiteNoiseEnabled = true;
    String currentWhiteNoiseTrack = 'musics/rain_loop.mp3';
    List<Map<String, dynamic>> whiteNoiseTracks = [
      {
        'name': 'Rain',
        'asset': 'musics/rain_loop.mp3',
        'icon': Icons.water_drop
      },
      {
        'name': 'Forest',
        'asset': 'musics/forest_loop.mp3',
        'icon': Icons.forest
      },
      {
        'name': 'Fire',
        'asset': 'musics/fire_loop.mp3',
        'icon': Icons.fireplace
      },
      {'name': 'Ocean', 'asset': 'musics/wave_loop.mp3', 'icon': Icons.waves},
    ];

    // Helper methods
    void _playWhiteNoise() {
      if (isWhiteNoiseEnabled) {
        _audioPlayer.setReleaseMode(ReleaseMode.loop);
        _audioPlayer.play(AssetSource(currentWhiteNoiseTrack));
      }
    }

    void _stopWhiteNoise() {
      _audioPlayer.stop();
    }

    void _changeWhiteNoise(String trackAsset) {
      currentWhiteNoiseTrack = trackAsset;
      if (isWhiteNoiseEnabled) {
        _stopWhiteNoise();
        _playWhiteNoise();
      }
    }

    void _toggleWhiteNoise() {
      isWhiteNoiseEnabled = !isWhiteNoiseEnabled;
      if (isWhiteNoiseEnabled) {
        _playWhiteNoise();
      } else {
        _stopWhiteNoise();
      }
    }

    void _playTimerEndSound() {
      _audioPlayer.setReleaseMode(ReleaseMode.release);
      _audioPlayer.play(AssetSource('musics/end.mp3'));
    }

    // Custom button widget as a local function
    Widget _TimerButton({
      required IconData icon,
      required Color color,
      required String label,
      required VoidCallback onPressed,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(icon),
              iconSize: 30,
              color: color,
              onPressed: onPressed,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
            ),
          ),
        ],
      );
    }

    // Focus timer implementation
    void _startFocusTimer() {
      int focusDuration = 25; // Default Pomodoro duration in minutes
      int breakDuration = 5; // Default break duration in minutes
      int pomodoroCount = 0;
      bool isBreak = false;
      int secondsRemaining = focusDuration * 60;
      Timer? timer;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              // Start the timer
              void startTimer() {
                _playWhiteNoise();
                timer = Timer.periodic(Duration(seconds: 1), (timer) {
                  setState(() {
                    if (secondsRemaining > 0) {
                      secondsRemaining--;
                    } else {
                      timer.cancel();
                      // Switch between focus and break
                      if (isBreak) {
                        isBreak = false;
                        secondsRemaining = focusDuration * 60;
                      } else {
                        pomodoroCount++;
                        isBreak = true;
                        secondsRemaining = breakDuration * 60;

                        // After 4 pomodoros, take a longer break
                        if (pomodoroCount % 4 == 0) {
                          secondsRemaining = 15 * 60; // 15 minutes long break
                        }

                        // If completed a full hour (2 pomodoros or more)
                        // if (pomodoroCount >= 2) {
                        //   _markTaskCompleted(task);
                        // }
                      }
                      // Play sound and show notification
                      _playTimerEndSound();
                      // Auto-start the next interval
                      startTimer();
                    }
                  });
                });
              }

              // Format time as mm:ss
              String formatTime() {
                int minutes = secondsRemaining ~/ 60;
                int seconds = secondsRemaining % 60;
                return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
              }

              // Initialize timer on first build
              if (timer == null) {
                startTimer();
              }

              // Progress indicator calculation
              double getProgress() {
                int totalSeconds =
                    isBreak ? (breakDuration * 60) : (focusDuration * 60);
                if (pomodoroCount % 4 == 0 && isBreak) {
                  totalSeconds = 15 * 60; // Long break
                }
                return 1 - (secondsRemaining / totalSeconds);
              }

              return WillPopScope(
                onWillPop: () async {
                  bool shouldPop = false;
                  await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: Text("Stop Timer?"),
                        content: Text("Your progress will be lost."),
                        actions: [
                          TextButton(
                            child: Text("Cancel"),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          TextButton(
                            child: Text("Stop",
                                style: TextStyle(color: Colors.red)),
                            onPressed: () {
                              shouldPop = true;
                              Navigator.of(context).pop();
                            },
                          ),
                        ],
                      );
                    },
                  );
                  if (shouldPop && timer != null) {
                    timer!.cancel();
                    _stopWhiteNoise();
                  }
                  return shouldPop;
                },
                child: Dialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isBreak ? "Break Time" : "Focus Time",
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isBreak
                                    ? Colors.green
                                    : _getCategoryColor(task.category),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                isWhiteNoiseEnabled
                                    ? Icons.volume_up
                                    : Icons.volume_off,
                                color: isWhiteNoiseEnabled
                                    ? _getCategoryColor(task.category)
                                    : Colors.grey,
                              ),
                              onPressed: () {
                                setState(() {
                                  _toggleWhiteNoise();
                                });
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 5),
                        Text(
                          "Pomodoro ${pomodoroCount + 1}${isBreak ? " - Break" : ""}",
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 20),
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 220,
                              height: 220,
                              child: CircularProgressIndicator(
                                value: getProgress(),
                                strokeWidth: 8,
                                backgroundColor: Colors.grey[200],
                                color: isBreak
                                    ? Colors.green
                                    : _getCategoryColor(task.category),
                              ),
                            ),
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      formatTime(),
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      isBreak ? "Recharge" : "Deep Focus",
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),

                        // Sound controls
                        if (isWhiteNoiseEnabled)
                          Container(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: whiteNoiseTracks.length,
                              itemBuilder: (context, index) {
                                final track = whiteNoiseTracks[index];
                                final isSelected =
                                    currentWhiteNoiseTrack == track['asset'];

                                return Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8),
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _changeWhiteNoise(track['asset']);
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (isBreak
                                                ? Colors.green.withOpacity(0.2)
                                                : _getCategoryColor(
                                                        task.category)
                                                    .withOpacity(0.2))
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: isSelected
                                              ? (isBreak
                                                  ? Colors.green
                                                  : _getCategoryColor(
                                                      task.category))
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            track['icon'],
                                            color: isSelected
                                                ? (isBreak
                                                    ? Colors.green
                                                    : _getCategoryColor(
                                                        task.category))
                                                : Colors.grey[600],
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            track['name'],
                                            style: TextStyle(
                                              color: isSelected
                                                  ? (isBreak
                                                      ? Colors.green
                                                      : _getCategoryColor(
                                                          task.category))
                                                  : Colors.grey[600],
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
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

                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _TimerButton(
                              icon: timer!.isActive
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: isBreak
                                  ? Colors.green
                                  : _getCategoryColor(task.category),
                              label: timer!.isActive ? "Pause" : "Resume",
                              onPressed: () {
                                setState(() {
                                  if (timer!.isActive) {
                                    timer!.cancel();
                                    _stopWhiteNoise();
                                  } else {
                                    startTimer();
                                  }
                                });
                              },
                            ),
                            _TimerButton(
                              icon: Icons.skip_next,
                              color: Colors.amber[700]!,
                              label: "Skip",
                              onPressed: () {
                                setState(() {
                                  timer!.cancel();
                                  // Skip to next interval
                                  if (isBreak) {
                                    isBreak = false;
                                    secondsRemaining = focusDuration * 60;
                                  } else {
                                    pomodoroCount++;
                                    isBreak = true;
                                    secondsRemaining = breakDuration * 60;
                                    if (pomodoroCount % 4 == 0) {
                                      secondsRemaining = 15 * 60;
                                    }
                                  }
                                  startTimer();
                                });
                              },
                            ),
                            _TimerButton(
                              icon: Icons.stop,
                              color: Colors.red,
                              label: "Stop",
                              onPressed: () {
                                timer!.cancel();
                                _stopWhiteNoise();
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Container(
                          padding:
                              EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.emoji_events,
                                color: Colors.amber[700],
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Completed: ${pomodoroCount} pomodoros",
                                style: TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                        if (pomodoroCount >= 2)
                          Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: Colors.green, width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.celebration, color: Colors.green),
                                  SizedBox(width: 8),
                                  Text(
                                    "You've reached your 1-hour goal!",
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    void _saveDeepWorkTask(String updatedDescription) async {
      // Save the task description for this session
      Project50Task updatedTask = Project50Task(
        id: task.id,
        title: task.title,
        category: task.category,
        description: updatedDescription,
        time: task.time,
        isCompleted: task.isCompleted,
        day: task.day,
        createdAt: task.createdAt,
        updatedAt: DateTime.now(),
        orderTask: task.orderTask,
      );

      await _project50service.updateProject50TaskDetails(task.id, updatedTask);
    }

    // Add this new method to show the completed tasks in a bottom sheet
    void _showCompletedTasksSelectionSheet(
        BuildContext context, Function(Task) onTaskSelected) {
      ScheduleService _scheduleService = ScheduleService();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.6,
            padding: EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    children: [
                      Text(
                        "Incompleted Tasks Today",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<List<Task>>(
                    stream: _scheduleService.getInCompletedSchedulesForToday(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy,
                                  size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                "No incompleted tasks for today",
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.builder(
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final task = snapshot.data![index];
                          return Card(
                            elevation: 1,
                            margin: EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: InkWell(
                              onTap: () {
                                onTaskSelected(task);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 4,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: _getCategoryColor(task.category),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            task.title,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.label_outline,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                task.category,
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Icon(
                                                Icons.check_circle_outline,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                task.completedAt != null
                                                    ? "${task.completedAt!.hour}:${task.completedAt!.minute.toString().padLeft(2, '0')}"
                                                    : "Completed",
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    void _showTaskSelectionDialog() {
      String taskDescription = "";
      Task? selectedCompletedTask;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology,
                      size: 48,
                      color: _getCategoryColor(task.category),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "What will you work on?",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "Be specific about your deep work goal",
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    SizedBox(height: 20),

                    // Manual entry option
                    if (selectedCompletedTask == null)
                      TextField(
                        decoration: InputDecoration(
                          hintText: "Describe your deep work task",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                          prefixIcon: Icon(Icons.edit_note),
                        ),
                        maxLines: 3,
                        onChanged: (value) {
                          taskDescription = value;
                        },
                      ),

                    // Selected task display
                    if (selectedCompletedTask != null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(10),
                          color: Colors.grey[100],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: _getCategoryColor(
                                      selectedCompletedTask!.category),
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    selectedCompletedTask!.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      selectedCompletedTask = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (selectedCompletedTask!.category.isNotEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.only(left: 28, top: 4),
                                child: Text(
                                  selectedCompletedTask!.category,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    SizedBox(height: 16),

                    // "Or select from completed tasks" section
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[400]!),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        _showCompletedTasksSelectionSheet(context, (task) {
                          setState(() {
                            selectedCompletedTask = task;
                            taskDescription = task.title;
                          });
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.playlist_add_check, size: 20),
                            SizedBox(width: 8),
                            Text("Select from incompleted tasks"),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          child: Text("Cancel"),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _getCategoryColor(task.category),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                          ),
                          icon: Icon(Icons.timer),
                          label: Text("Start Timer"),
                          onPressed: () {
                            if (selectedCompletedTask != null ||
                                taskDescription.trim().isNotEmpty) {
                              if (selectedCompletedTask != null) {
                                _saveDeepWorkTask(selectedCompletedTask!.title);
                              } else {
                                _saveDeepWorkTask(taskDescription);
                              }
                              Navigator.of(context).pop();
                              _startFocusTimer();
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          });
        },
      );
    }

    // Custom focus mode step widget as a local function
    Widget _FocusModeStep({
      required IconData icon,
      required String title,
      required String subtitle,
    }) {
      return Container(
        margin: EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.grey[700], size: 24),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    void _showFocusModeInstructions() {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.do_not_disturb_on,
                    size: 48,
                    color: _getCategoryColor(task.category),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Focus Mode Instructions",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber[200]!, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb, color: Colors.amber[700]),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "Minimize distractions during deep work to maximize productivity",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  _FocusModeStep(
                    icon: Icons.smartphone,
                    title: "Enable Do Not Disturb",
                    subtitle: "Settings > Notifications > Do Not Disturb",
                  ),
                  _FocusModeStep(
                    icon: Icons.notifications_off,
                    title: "Silence Notifications",
                    subtitle: "Turn your phone face-down or set to silent mode",
                  ),
                  _FocusModeStep(
                    icon: Icons.desktop_windows,
                    title: "Close Distracting Apps",
                    subtitle: "Email, messaging, and social media apps",
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getCategoryColor(task.category),
                      foregroundColor: Colors.white,
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    icon: Icon(Icons.check_circle),
                    label: Text("I'll Do This!"),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showTaskSelectionDialog();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Main function to handle deep work task interaction
    Future<void> _showDeepWorkTaskOptions() async {
      final taskFromDb = await _project50service.getProject50TaskById(task.id);
      if (taskFromDb == null) {
        throw Exception("Task with ID ${task.id} not found in database");
      }

      String description = taskFromDb.description;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                SizedBox(height: 20),

                Text(
                  "Deep Work Options",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                // Display the task description in a nice UI (only if description is not empty)
                if (description.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(task.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _getCategoryColor(task.category)
                              .withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              color: _getCategoryColor(task.category),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              "Task Plan",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _getCategoryColor(task.category),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                ],
                OptionCard(
                  icon: Icons.do_not_disturb_on,
                  color: _getCategoryColor(task.category),
                  title: "Enable Focus Mode",
                  description: "Mute notifications during deep work",
                  onTap: () {
                    Navigator.pop(context);
                    _showFocusModeInstructions();
                  },
                ),
                SizedBox(height: 12),
                OptionCard(
                  icon: Icons.tips_and_updates,
                  color: _getCategoryColor(task.category),
                  title: "Deep Work Tips",
                  description: "Get strategies for effective deep work",
                  onTap: () {
                    Navigator.pop(context);
                    _showTaskSuggestionDialog(task);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    // Entry point - call this when user interacts with deep work task
    _showDeepWorkTaskOptions();
  }

// 3. Handle Healthy Diet Task
  void _handleHealthyDietTask(Project50Task task) {
    Future<void> _saveMealLog(
      String mealType,
      String description,
      File? imageFile,
      bool isHealthy,
      int healthScore,
      Map<String, dynamic>? nutritionData,
    ) async {
      try {
        // Get current date for the log
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        String? imagePath;

        // Save image to filesystem if provided
        if (imageFile != null) {
          final directory =
              await path_provider.getApplicationDocumentsDirectory();
          imagePath =
              '${directory.path}/meal_${task.id}_${now.millisecondsSinceEpoch}.jpg';
          await imageFile.copy(imagePath);
        }

        // Fetch the current task's details from sqflite
        final taskFromDb =
            await _project50service.getProject50TaskById(task.id);
        if (taskFromDb == null) {
          throw Exception("Task with ID ${task.id} not found in database");
        }

        // Create meal log data - store full structure for future reference
        Map<String, dynamic> mealData = {
          'mealType': mealType,
          'description': description,
          'imagePath': imagePath,
          'isHealthy': isHealthy,
          'healthScore': healthScore,
          'date': today.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'nutritionData': nutritionData
        };

        // Update task description to include meal log info
        String mealStatus = isHealthy
            ? "✓ Healthy meal (Score: $healthScore%)"
            : "⚠️ Needs improvement (Score: $healthScore%)";

        // Format nutrition info in a structured way that can be parsed by regex
        String nutritionInfo = "Nutrition: ";
        if (nutritionData != null && nutritionData.containsKey('data')) {
          var data = nutritionData['data'];

          // Add food name
          nutritionInfo += "${data['name'] ?? 'Unknown food'}, ";

          // Add calories
          if (data['nutrition']?.containsKey('calories')) {
            nutritionInfo += "${data['nutrition']['calories']} calories";
          } else {
            nutritionInfo += "0 calories";
          }

          // Save detailed nutrition in JSON format for better retrieval
          // This is in addition to the readable format above
          String detailedNutrition =
              "\nNutritionJSON: ${jsonEncode(nutritionData)}";

          // Add health benefits if available
          if (data.containsKey('healthBenefits') &&
              data['healthBenefits'] is List &&
              (data['healthBenefits'] as List).isNotEmpty) {
            nutritionInfo +=
                "\nBenefits: ${(data['healthBenefits'] as List).join(', ')}";
          }

          // Add cautions if available
          if (data.containsKey('cautions') &&
              data['cautions'] is List &&
              (data['cautions'] as List).isNotEmpty) {
            nutritionInfo +=
                "\nCautions: ${(data['cautions'] as List).join(', ')}";
          }

          // Add protein, carbs, fat if available
          if (data['nutrition']?.containsKey('protein')) {
            nutritionInfo += "\nProtein: ${data['nutrition']['protein']}g";
          }
          if (data['nutrition']?.containsKey('carbs')) {
            nutritionInfo += "\nCarbs: ${data['nutrition']['carbs']}g";
          }
          if (data['nutrition']?.containsKey('fat')) {
            nutritionInfo += "\nFat: ${data['nutrition']['fat']}g";
          }

          nutritionInfo += detailedNutrition;
        } else {
          nutritionInfo += "No detailed data available";
        }

        // Build updated description with clear section markers for regex parsing
        String updatedDescription = "${taskFromDb.description}\n\n";
        updatedDescription += "Meal Log: $mealType - $mealStatus\n";
        updatedDescription += "$nutritionInfo";

        // Add description and image path with clear markers
        if (description.isNotEmpty) {
          updatedDescription += "\nDetails: $description";
        }
        if (imagePath != null) {
          updatedDescription += "\nImage: $imagePath";
        }

        // Add timestamp for reference
        updatedDescription +=
            "\nLogged: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}";

        // Create updated task object
        Project50Task updatedTask = Project50Task(
          id: task.id,
          title: task.title,
          category: task.category,
          description: updatedDescription,
          time: task.time,
          isCompleted: true,
          day: task.day,
          createdAt: task.createdAt,
          updatedAt: DateTime.now(),
          orderTask: task.orderTask,
        );

        // Update task in sqflite
        await _project50service.updateProject50TaskDetails(
            task.id, updatedTask);

        _showCompletionAnimation();

        _loadProject50Data();

        // Update local state
        setState(() {
          final index = _allTasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _allTasks[index] = updatedTask;
          }
          if (_tasksByDay.containsKey(task.day)) {
            final dayIndex =
                _tasksByDay[task.day]!.indexWhere((t) => t.id == task.id);
            if (dayIndex != -1) {
              _tasksByDay[task.day]![dayIndex] = updatedTask;
            }
          }
          _completedTasks = _allTasks.where((t) => t.isCompleted).length;
          _overallProgress = _completedTasks / (7 * 50);
        });

        print("Meal log saved successfully!");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //       content: Text("Meal log saved successfully!"),
        //       backgroundColor: Colors.green),
        // );
        SuccessToast.show(context, "Meal log saved successfully!");

        await _loadProject50Data();
      } catch (e) {
        print("Error saving meal log: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error saving meal log: $e"),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    // Helper method to build meal type selection buttons
    Widget _buildMealTypeButton({
      required IconData icon,
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
      required Color color,
    }) {
      return InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 5),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey[600],
                size: 28,
              ),
              SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey[800],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Helper widget for nutrition chips
    Widget _nutritionChip(String text) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Show dialog to record a meal
    // Show bottom sheet to record a meal
    void _showMealLogBottomSheet() {
      String selectedMealType = 'Breakfast';
      String mealDescription = '';
      String aiMealResult = '';
      File? selectedImage;
      Map<String, dynamic>? nutritionAnalysisResult;
      int healthScore = 0;
      bool isAnalyzing = false;

      void _processSelectedImage(XFile? image, Function setState) async {
        if (image != null) {
          setState(() {
            selectedImage = File(image.path);
            isAnalyzing = true;
            aiMealResult = 'Analyzing your meal...';
          });

          try {
            // Create a singleton instance of AiAnalyzer
            final analyzer = AiAnalyzer();

            // Analyze the image
            final result = await analyzer.analyzeNutrition(File(image.path));

            // Update UI with result
            setState(() {
              isAnalyzing = false;

              if (result['success'] == true && result.containsKey('data')) {
                nutritionAnalysisResult = result;

                // Get human-readable summary
                aiMealResult = analyzer.getReadableSummary(result);

                // Set health score based on nutrition score (scale 1-10 to 0-100)
                if (result['data'].containsKey('nutritionScore')) {
                  healthScore = (result['data']['nutritionScore'] * 10).toInt();
                }
              } else {
                aiMealResult =
                    'Could not analyze image: ${result['message'] ?? 'Unknown error'}';
                healthScore = 50; // Default to middle score if analysis fails
              }
            });
          } catch (e) {
            print('Error processing image: $e');
            setState(() {
              isAnalyzing = false;
              aiMealResult = 'Error analyzing image: $e';
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error analyzing image'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled:
            true, // Makes the bottom sheet take up the full screen height if needed
        backgroundColor:
            Colors.transparent, // Make the outer container transparent
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              // Calculate available height (consider safe area)
              final mediaQuery = MediaQuery.of(context);
              final availableHeight = mediaQuery.size.height -
                  mediaQuery.padding.top -
                  mediaQuery.padding.bottom;
              final bottomSheetHeight =
                  availableHeight * 0.9; // Use 90% of available height

              Color primaryColor = _getCategoryColor(task.category);

              // Calculate score color
              Color scoreColor = healthScore > 70
                  ? Colors.green
                  : healthScore > 40
                      ? Colors.orange
                      : Colors.red;

              return Container(
                height: bottomSheetHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle at the top
                    Container(
                      margin: EdgeInsets.only(top: 10),
                      width: 60,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),

                    // Main content in a scrollable area
                    Expanded(
                      child: ListView(
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        children: [
                          // Compact header with task title
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Icon
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: primaryColor.withOpacity(0.2),
                                ),
                                child: Icon(Icons.restaurant_menu,
                                    color: primaryColor, size: 22),
                              ),
                              SizedBox(width: 10),
                              // Title text
                              Text(
                                "Meal Tracker",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 15),

                          // Compact task reference
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 15, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: primaryColor.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.task_alt,
                                    color: primaryColor, size: 16),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Text(
                                  "Day ${task.day}",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 15),

                          // Meal type selector with icons
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.grey[100],
                            ),
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("What meal is this?",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    )),
                                SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildMealTypeButton(
                                      icon: Icons.wb_sunny,
                                      label: 'Breakfast',
                                      isSelected:
                                          selectedMealType == 'Breakfast',
                                      onTap: () => setState(
                                          () => selectedMealType = 'Breakfast'),
                                      color: Colors.blueAccent,
                                    ),
                                    _buildMealTypeButton(
                                      icon: Icons.wb_twilight,
                                      label: 'Lunch',
                                      isSelected: selectedMealType == 'Lunch',
                                      onTap: () => setState(
                                          () => selectedMealType = 'Lunch'),
                                      color: Colors.blueAccent,
                                    ),
                                    _buildMealTypeButton(
                                      icon: Icons.nightlight_round,
                                      label: 'Dinner',
                                      isSelected: selectedMealType == 'Dinner',
                                      onTap: () => setState(
                                          () => selectedMealType = 'Dinner'),
                                      color: Colors.blueAccent,
                                    ),
                                    _buildMealTypeButton(
                                      icon: Icons.cookie,
                                      label: 'Snack',
                                      isSelected: selectedMealType == 'Snack',
                                      onTap: () => setState(
                                          () => selectedMealType = 'Snack'),
                                      color: Colors.blueAccent,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 15),

                          // Camera section with preview
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.grey[100],
                            ),
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Take a photo of your meal",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    )),
                                SizedBox(height: 12),
                                GestureDetector(
                                  onTap: () async {
                                    final ImagePicker picker = ImagePicker();

                                    // Show options for camera or gallery
                                    showModalBottomSheet(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return SafeArea(
                                          child: Wrap(
                                            children: [
                                              ListTile(
                                                leading: Icon(Icons.camera_alt),
                                                title: Text('Take a photo'),
                                                onTap: () async {
                                                  Navigator.pop(context);
                                                  final XFile? image =
                                                      await picker.pickImage(
                                                    source: ImageSource.camera,
                                                    maxWidth: 800,
                                                    maxHeight: 800,
                                                  );
                                                  _processSelectedImage(
                                                      image, setState);
                                                },
                                              ),
                                              ListTile(
                                                leading:
                                                    Icon(Icons.photo_library),
                                                title:
                                                    Text('Choose from gallery'),
                                                onTap: () async {
                                                  Navigator.pop(context);
                                                  final XFile? image =
                                                      await picker.pickImage(
                                                    source: ImageSource.gallery,
                                                    maxWidth: 800,
                                                    maxHeight: 800,
                                                  );
                                                  _processSelectedImage(
                                                      image, setState);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: Container(
                                    height: 150, // Reduced height
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.5),
                                        width: 2,
                                      ),
                                    ),
                                    child: selectedImage != null
                                        ? Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(13),
                                                child: Image.file(
                                                  selectedImage!,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              // Change photo button
                                              Positioned(
                                                bottom: 10,
                                                right: 10,
                                                child: Container(
                                                  padding: EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.7),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.edit,
                                                    color: Colors.white,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                              // Show loading indicator when analyzing
                                              if (isAnalyzing)
                                                Container(
                                                  decoration: BoxDecoration(
                                                    color: Colors.black
                                                        .withOpacity(0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            13),
                                                  ),
                                                  child: Center(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                        ),
                                                        SizedBox(height: 10),
                                                        Text(
                                                          "Analyzing meal...",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          )
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.add_a_photo,
                                                  size: 40,
                                                  color: primaryColor
                                                      .withOpacity(0.7)),
                                              SizedBox(height: 8),
                                              Text(
                                                "Add a photo of your meal",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // AI Food Analysis Result - Collapsible
                          if (aiMealResult.isNotEmpty) ...[
                            SizedBox(height: 15),
                            ExpansionTile(
                              initiallyExpanded: true,
                              title: Row(
                                children: [
                                  Icon(
                                      isAnalyzing
                                          ? Icons.hourglass_top
                                          : nutritionAnalysisResult != null &&
                                                  nutritionAnalysisResult![
                                                          'success'] ==
                                                      true
                                              ? Icons.food_bank
                                              : Icons.warning,
                                      color: isAnalyzing
                                          ? Colors.blue
                                          : nutritionAnalysisResult != null &&
                                                  nutritionAnalysisResult![
                                                          'success'] ==
                                                      true
                                              ? Colors.green
                                              : Colors.orange),
                                  SizedBox(width: 8),
                                  Text(
                                    isAnalyzing
                                        ? "Analyzing..."
                                        : "AI Food Analysis",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: isAnalyzing
                                  ? Colors.blue.withOpacity(0.05)
                                  : nutritionAnalysisResult != null &&
                                          nutritionAnalysisResult!['success'] ==
                                              true
                                      ? Colors.green.withOpacity(0.05)
                                      : Colors.orange.withOpacity(0.05),
                              collapsedBackgroundColor: isAnalyzing
                                  ? Colors.blue.withOpacity(0.05)
                                  : nutritionAnalysisResult != null &&
                                          nutritionAnalysisResult!['success'] ==
                                              true
                                      ? Colors.green.withOpacity(0.05)
                                      : Colors.orange.withOpacity(0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color: isAnalyzing
                                      ? Colors.blue.withOpacity(0.3)
                                      : nutritionAnalysisResult != null &&
                                              nutritionAnalysisResult![
                                                      'success'] ==
                                                  true
                                          ? Colors.green.withOpacity(0.3)
                                          : Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Analysis Content
                                      Text(
                                        aiMealResult,
                                        style: TextStyle(fontSize: 14),
                                      ),

                                      // Show detailed nutrition if available
                                      if (nutritionAnalysisResult != null &&
                                          nutritionAnalysisResult!['success'] ==
                                              true &&
                                          nutritionAnalysisResult!
                                              .containsKey('data')) ...[
                                        SizedBox(height: 15),

                                        // Display key nutrition facts
                                        if (nutritionAnalysisResult!['data']
                                            .containsKey('nutrition')) ...[
                                          Divider(),
                                          SizedBox(height: 5),
                                          Text(
                                            "Nutrition Facts:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 5),

                                          // Nutrition facts in grid layout for better space usage
                                          Wrap(
                                            spacing: 10,
                                            runSpacing: 10,
                                            children: [
                                              if (nutritionAnalysisResult![
                                                      'data']['nutrition']
                                                  .containsKey('calories'))
                                                _nutritionChip(
                                                    "Calories: ${nutritionAnalysisResult!['data']['nutrition']['calories']}"),
                                              if (nutritionAnalysisResult![
                                                      'data']['nutrition']
                                                  .containsKey('protein'))
                                                _nutritionChip(
                                                    "Protein: ${nutritionAnalysisResult!['data']['nutrition']['protein']}g"),
                                              if (nutritionAnalysisResult![
                                                      'data']['nutrition']
                                                  .containsKey('carbs'))
                                                _nutritionChip(
                                                    "Carbs: ${nutritionAnalysisResult!['data']['nutrition']['carbs']}g"),
                                              if (nutritionAnalysisResult![
                                                      'data']['nutrition']
                                                  .containsKey('fat'))
                                                _nutritionChip(
                                                    "Fat: ${nutritionAnalysisResult!['data']['nutrition']['fat']}g"),
                                            ],
                                          ),
                                        ],

                                        // Health benefits if available - horizontal scroll
                                        if (nutritionAnalysisResult!['data']
                                                .containsKey(
                                                    'healthBenefits') &&
                                            nutritionAnalysisResult!['data']
                                                ['healthBenefits'] is List &&
                                            (nutritionAnalysisResult!['data']
                                                    ['healthBenefits'] as List)
                                                .isNotEmpty) ...[
                                          SizedBox(height: 10),
                                          Text(
                                            "Health Benefits:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Container(
                                            height: 35,
                                            child: ListView(
                                              scrollDirection: Axis.horizontal,
                                              children:
                                                  (nutritionAnalysisResult![
                                                                  'data']
                                                              ['healthBenefits']
                                                          as List)
                                                      .map((benefit) =>
                                                          Container(
                                                            margin:
                                                                EdgeInsets.only(
                                                                    right: 8),
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .green
                                                                  .withOpacity(
                                                                      0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .green
                                                                      .withOpacity(
                                                                          0.3)),
                                                            ),
                                                            child: Text(
                                                              benefit
                                                                  .toString(),
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .green[700],
                                                              ),
                                                            ),
                                                          ))
                                                      .toList()
                                                      .cast<Widget>(),
                                            ),
                                          ),
                                        ],

                                        // Cautions if available - horizontal scroll
                                        if (nutritionAnalysisResult!['data']
                                                .containsKey('cautions') &&
                                            nutritionAnalysisResult!['data']
                                                ['cautions'] is List &&
                                            (nutritionAnalysisResult!['data']
                                                    ['cautions'] as List)
                                                .isNotEmpty) ...[
                                          SizedBox(height: 10),
                                          Text(
                                            "Cautions:",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          SizedBox(height: 5),
                                          Container(
                                            height: 35,
                                            child: ListView(
                                              scrollDirection: Axis.horizontal,
                                              children:
                                                  (nutritionAnalysisResult![
                                                              'data']
                                                          ['cautions'] as List)
                                                      .map((caution) =>
                                                          Container(
                                                            margin:
                                                                EdgeInsets.only(
                                                                    right: 8),
                                                            padding: EdgeInsets
                                                                .symmetric(
                                                                    horizontal:
                                                                        8,
                                                                    vertical:
                                                                        4),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Colors
                                                                  .orange
                                                                  .withOpacity(
                                                                      0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12),
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .orange
                                                                      .withOpacity(
                                                                          0.3)),
                                                            ),
                                                            child: Text(
                                                              caution
                                                                  .toString(),
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: Colors
                                                                        .orange[
                                                                    700],
                                                              ),
                                                            ),
                                                          ))
                                                      .toList()
                                                      .cast<Widget>(),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],

                          SizedBox(height: 15),

                          // Meal description with character count
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.grey[100],
                            ),
                            padding: EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Description",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    )),
                                SizedBox(height: 12),
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: "List what you eat",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: primaryColor.withOpacity(0.5),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  maxLines: 2, // Reduced to save space
                                  onChanged: (value) {
                                    setState(() {
                                      mealDescription = value;
                                    });
                                  },
                                ),
                                SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Text(
                                      "${mealDescription.length}/200 characters",
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
                          SizedBox(height: 15),

                          // Nutrition Score Display - made more compact
                          AnimatedContainer(
                            duration: Duration(milliseconds: 500),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scoreColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: scoreColor,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Nutrition Score",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: scoreColor,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      LinearProgressIndicator(
                                        value: healthScore / 100,
                                        backgroundColor: Colors.grey[300],
                                        color: scoreColor,
                                        minHeight: 8,
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        healthScore > 70
                                            ? "Great balanced meal!"
                                            : healthScore > 40
                                                ? "Good effort, room for improvement"
                                                : "Consider adding more nutritional elements",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: scoreColor,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 10),
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: scoreColor.withOpacity(0.2),
                                  ),
                                  child: Text(
                                    "$healthScore%",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: scoreColor,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Action buttons in a fixed position at bottom
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 5,
                            offset: Offset(0, -3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text("CANCEL"),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.grey[700],
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(width: 15),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                padding: EdgeInsets.symmetric(vertical: 12),
                                elevation: 2,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, size: 18),
                                  SizedBox(width: 8),
                                  Text("SAVE"),
                                ],
                              ),
                              onPressed: () {
                                // Calculate if meal is healthy based on score
                                bool isHealthyMeal = healthScore >= 60;

                                // Save the meal log data
                                _saveMealLog(
                                    selectedMealType,
                                    mealDescription,
                                    selectedImage,
                                    isHealthyMeal,
                                    healthScore,
                                    nutritionAnalysisResult);

                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    }

    void _showMealDetailsDialog(Project50Task task) async {
      try {
        // Create a loading state while data is being fetched
        bool isLoading = true;
        Map<String, dynamic>? mealData;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setState) {
                final mediaQuery = MediaQuery.of(context);
                final availableHeight = mediaQuery.size.height -
                    mediaQuery.padding.top -
                    mediaQuery.padding.bottom;
                final bottomSheetHeight =
                    availableHeight * 0.9; // Use 90% of available height
                Color primaryColor = _getCategoryColor(task.category);

                // Function to load meal data
                void loadMealData() async {
                  print("Reading meal data");
                  try {
                    // Query sqflite for the task related to this meal log
                    final taskFromDb =
                        await _project50service.getProject50TaskById(task.id);
                    if (taskFromDb == null) {
                      throw Exception(
                          "Task with ID ${task.id} not found in database");
                    }

                    final description = taskFromDb.description ?? '';
                    print(
                        "Description to parse: $description"); // Debugging line

                    // First, check if this is a meal log by looking for the meal log prefix
                    if (!description.contains('Meal Log:')) {
                      setState(() {
                        isLoading = false;
                        mealData = null;
                      });
                      return;
                    }

                    // Extract base meal information with a simpler regex
                    final mealTypeStatusRegex =
                        RegExp(r'Meal Log: (.*?) - (.+?)(?:\n|$)');
                    final mealTypeStatusMatch =
                        mealTypeStatusRegex.firstMatch(description);

                    if (mealTypeStatusMatch == null) {
                      print("Could not parse basic meal info");
                      setState(() {
                        isLoading = false;
                        mealData = null;
                      });
                      return;
                    }

                    final mealType = mealTypeStatusMatch.group(1) ?? '';
                    final statusText = mealTypeStatusMatch.group(2) ?? '';

                    // Extract score from status text
                    final scoreRegex = RegExp(r'Score: (\d+)%');
                    final scoreMatch = scoreRegex.firstMatch(statusText);
                    final healthScore = scoreMatch != null
                        ? int.parse(scoreMatch.group(1)!)
                        : 0;

                    // Initialize nutrition data map
                    Map<String, dynamic> nutritionData = {
                      'data': {'nutrition': {}}
                    };

                    // Extract sections using line-by-line approach instead of regex
                    Map<String, String> sections = {};
                    String currentSection = "";
                    List<String> lines = description.split('\n');

                    for (int i = 0; i < lines.length; i++) {
                      String line = lines[i].trim();

                      if (line.isEmpty) continue;

                      // Check if this line starts a new section
                      if (line.startsWith('Meal Log:')) {
                        currentSection = 'mealLog';
                        continue;
                      } else if (line.startsWith('Nutrition:')) {
                        currentSection = 'nutrition';
                        sections[currentSection] =
                            line.substring('Nutrition:'.length).trim();
                        continue;
                      } else if (line.startsWith('Benefits:')) {
                        currentSection = 'benefits';
                        sections[currentSection] =
                            line.substring('Benefits:'.length).trim();
                        continue;
                      } else if (line.startsWith('Cautions:')) {
                        currentSection = 'cautions';
                        sections[currentSection] =
                            line.substring('Cautions:'.length).trim();
                        continue;
                      } else if (line.startsWith('Protein:')) {
                        sections['protein'] =
                            line.substring('Protein:'.length).trim();
                        continue;
                      } else if (line.startsWith('Carbs:')) {
                        sections['carbs'] =
                            line.substring('Carbs:'.length).trim();
                        continue;
                      } else if (line.startsWith('Fat:')) {
                        sections['fat'] = line.substring('Fat:'.length).trim();
                        continue;
                      } else if (line.startsWith('Details:')) {
                        currentSection = 'details';
                        sections[currentSection] =
                            line.substring('Details:'.length).trim();
                        continue;
                      } else if (line.startsWith('Image:')) {
                        currentSection = 'image';
                        sections[currentSection] =
                            line.substring('Image:'.length).trim();
                        continue;
                      } else if (line.startsWith('Logged:')) {
                        currentSection = 'logged';
                        sections[currentSection] =
                            line.substring('Logged:'.length).trim();
                        continue;
                      } else if (line.startsWith('NutritionJSON:')) {
                        currentSection = 'nutritionJSON';
                        // Start collecting all JSON content until we find another section
                        StringBuilder jsonContent = StringBuilder();
                        jsonContent.write(
                            line.substring('NutritionJSON:'.length).trim());

                        // Continue collecting lines until we hit another section or end of description
                        int j = i + 1;
                        while (j < lines.length) {
                          String nextLine = lines[j].trim();
                          if (nextLine.isEmpty ||
                              nextLine.startsWith('Meal Log:') ||
                              nextLine.startsWith('Nutrition:') ||
                              nextLine.startsWith('Benefits:') ||
                              nextLine.startsWith('Cautions:') ||
                              nextLine.startsWith('Protein:') ||
                              nextLine.startsWith('Carbs:') ||
                              nextLine.startsWith('Fat:') ||
                              nextLine.startsWith('Details:') ||
                              nextLine.startsWith('Image:') ||
                              nextLine.startsWith('Logged:')) {
                            break; // Stop if we hit another section header
                          }

                          // Add this line to our JSON content
                          jsonContent.write(' ' + nextLine);
                          j++;
                        }

                        // Store the complete JSON content
                        sections[currentSection] = jsonContent.toString();
                        i = j -
                            1; // Update outer loop counter to skip processed lines
                        continue;
                      } else if (currentSection.isNotEmpty) {
                        // Append to current section if we're collecting multi-line content
                        sections[currentSection] =
                            (sections[currentSection] ?? '') + ' ' + line;
                      }
                    }

                    print("Parsed sections: ${sections.keys.toList()}");

                    // Try to parse the JSON nutrition data first (most complete way)
                    if (sections.containsKey('nutritionJSON') &&
                        sections['nutritionJSON']!.isNotEmpty) {
                      try {
                        String jsonStr = sections['nutritionJSON']!;
                        print(
                            "Attempting to parse JSON: ${jsonStr.length > 100 ? jsonStr.substring(0, 100) + '...' : jsonStr}");

                        // Try to fix common JSON issues
                        if (!jsonStr.endsWith('}')) {
                          // If JSON is truncated, try to close it properly
                          int openBraces = jsonStr.split('{').length - 1;
                          int closeBraces = jsonStr.split('}').length - 1;

                          // Add missing closing braces
                          for (int i = 0; i < (openBraces - closeBraces); i++) {
                            jsonStr += '}';
                          }
                          print("Fixed JSON: $jsonStr");
                        }

                        nutritionData = jsonDecode(jsonStr);
                        print("Successfully parsed nutrition JSON data");
                      } catch (e) {
                        print("Error parsing nutrition JSON: $e");
                        // Continue with manual parsing as fallback
                      }
                    }

                    // If JSON parsing failed or wasn't available, build nutrition data from individual fields
                    if (nutritionData['data'] == null ||
                        nutritionData['data'].isEmpty) {
                      nutritionData = {
                        'data': {'nutrition': {}}
                      };

                      // Extract food name and calories if available
                      if (sections.containsKey('nutrition')) {
                        final nameCaloriesRegex =
                            RegExp(r'(.*?), (\d+) calories');
                        final nameCalMatch = nameCaloriesRegex
                            .firstMatch(sections['nutrition']!);

                        if (nameCalMatch != null) {
                          nutritionData['data']['name'] =
                              nameCalMatch.group(1)?.trim();
                          nutritionData['data']['nutrition']['calories'] =
                              nameCalMatch.group(2);
                        } else {
                          // Just use whatever is in the nutrition section as the name
                          nutritionData['data']['name'] =
                              sections['nutrition']!.trim();
                        }
                      }

                      // Add macronutrients if available
                      if (sections.containsKey('protein')) {
                        final proteinMatch =
                            RegExp(r'(\d+)g').firstMatch(sections['protein']!);
                        if (proteinMatch != null) {
                          nutritionData['data']['nutrition']['protein'] =
                              proteinMatch.group(1);
                        }
                      }

                      if (sections.containsKey('carbs')) {
                        final carbsMatch =
                            RegExp(r'(\d+)g').firstMatch(sections['carbs']!);
                        if (carbsMatch != null) {
                          nutritionData['data']['nutrition']['carbs'] =
                              carbsMatch.group(1);
                        }
                      }

                      if (sections.containsKey('fat')) {
                        final fatMatch =
                            RegExp(r'(\d+)g').firstMatch(sections['fat']!);
                        if (fatMatch != null) {
                          nutritionData['data']['nutrition']['fat'] =
                              fatMatch.group(1);
                        }
                      }

                      // Process benefits
                      if (sections.containsKey('benefits') &&
                          sections['benefits']!.isNotEmpty) {
                        final benefits = sections['benefits']!
                            .split(',')
                            .map((b) => b.trim())
                            .toList();
                        nutritionData['data']['healthBenefits'] = benefits;
                      }

                      // Process cautions
                      if (sections.containsKey('cautions') &&
                          sections['cautions']!.isNotEmpty) {
                        final cautions = sections['cautions']!
                            .split(',')
                            .map((c) => c.trim())
                            .toList();
                        nutritionData['data']['cautions'] = cautions;
                      }
                    }

                    setState(() {
                      mealData = {
                        'mealType': mealType,
                        'description': sections['details'] ?? '',
                        'nutritionData': nutritionData,
                        'healthScore': healthScore,
                        'isHealthy': statusText.contains('✓ Healthy'),
                        'date': taskFromDb.updatedAt.toIso8601String(),
                        'imagePath': sections['image'] ?? '',
                        'loggedTime': sections['logged'] ?? '',
                      };
                      isLoading = false;
                    });

                    print("Successfully parsed meal data");
                  } catch (e) {
                    print("Error loading meal data: $e");
                    setState(() {
                      isLoading = false;
                      mealData = null;
                    });
                  }
                }

                // Load data when dialog is first shown
                if (isLoading && mealData == null) {
                  loadMealData();
                }

                // Get color based on health score
                Color getScoreColor(int score) {
                  return score > 70
                      ? Colors.green
                      : score > 40
                          ? Colors.orange
                          : Colors.red;
                }

                return Container(
                  height: bottomSheetHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: primaryColor),
                                SizedBox(height: 16),
                                Text("Loading meal details...")
                              ],
                            ),
                          )
                        : mealData == null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.no_meals,
                                        size: 50, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      "No meal data found for this task",
                                      style: TextStyle(fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 20),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text("CLOSE"),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Animated Header with meal type icon
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Circular background
                                        Container(
                                          height: 80,
                                          width: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.rectangle,
                                            color:
                                                primaryColor.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        // Icon based on meal type
                                        Icon(
                                            mealData!['mealType'] == 'Breakfast'
                                                ? Icons.wb_sunny
                                                : mealData!['mealType'] ==
                                                        'Lunch'
                                                    ? Icons.wb_twilight
                                                    : mealData!['mealType'] ==
                                                            'Dinner'
                                                        ? Icons.nightlight_round
                                                        : Icons.fastfood,
                                            color: primaryColor,
                                            size: 22),
                                        // Title text positioned below
                                        Positioned(
                                          bottom: 0,
                                          child: Text(
                                            mealData!['mealType'] ?? "Meal",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20),

                                    // Compact task reference
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color:
                                                primaryColor.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.task_alt,
                                              color: primaryColor, size: 16),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "Day ${task.day}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 20),

                                    // Date and time
                                    if (mealData!.containsKey('date'))
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 15),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey[700]),
                                            SizedBox(width: 8),
                                            Text(
                                              DateFormat('MMMM d, yyyy').format(
                                                  DateTime.parse(
                                                      mealData!['date'])),
                                              style: TextStyle(
                                                color: Colors.grey[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    SizedBox(height: 20),

                                    // Meal photo if available
                                    if (mealData!.containsKey('imagePath') &&
                                        mealData!['imagePath'] != null &&
                                        mealData!['imagePath']
                                            .toString()
                                            .isNotEmpty)
                                      Container(
                                        height: 200,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color:
                                                primaryColor.withOpacity(0.5),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(13),
                                          child: Image.file(
                                            File(mealData!['imagePath']),
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                size: 40,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (mealData!.containsKey('imagePath') &&
                                        mealData!['imagePath'] != null &&
                                        mealData!['imagePath']
                                            .toString()
                                            .isNotEmpty)
                                      SizedBox(height: 20),

                                    // Health score indicator
                                    if (mealData!.containsKey('healthScore'))
                                      Container(
                                        padding: EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: getScoreColor(
                                                  mealData!['healthScore'])
                                              .withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(15),
                                          border: Border.all(
                                            color: getScoreColor(
                                                mealData!['healthScore']),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  "Nutrition Score",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: getScoreColor(
                                                        mealData![
                                                            'healthScore']),
                                                  ),
                                                ),
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 5),
                                                  decoration: BoxDecoration(
                                                    color: getScoreColor(
                                                            mealData![
                                                                'healthScore'])
                                                        .withOpacity(0.2),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Text(
                                                    "${mealData!['healthScore']}%",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: getScoreColor(
                                                          mealData![
                                                              'healthScore']),
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 10),
                                            LinearProgressIndicator(
                                              value: mealData!['healthScore'] /
                                                  100,
                                              backgroundColor: Colors.grey[300],
                                              color: getScoreColor(
                                                  mealData!['healthScore']),
                                              minHeight: 10,
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  mealData!['healthScore'] > 70
                                                      ? Icons
                                                          .sentiment_very_satisfied
                                                      : mealData!['healthScore'] >
                                                              40
                                                          ? Icons
                                                              .sentiment_satisfied
                                                          : Icons
                                                              .sentiment_dissatisfied,
                                                  color: getScoreColor(
                                                      mealData!['healthScore']),
                                                  size: 20,
                                                ),
                                                SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    mealData!['healthScore'] >
                                                            70
                                                        ? "Great balanced meal!"
                                                        : mealData!['healthScore'] >
                                                                40
                                                            ? "Good effort, room for improvement"
                                                            : "Consider adding more nutritional elements",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: getScoreColor(
                                                          mealData![
                                                              'healthScore']),
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    SizedBox(height: 20),

                                    // Nutrition data if available
                                    if (mealData!
                                            .containsKey('nutritionData') &&
                                        mealData!['nutritionData'] != null &&
                                        mealData!['nutritionData'] is Map &&
                                        mealData!['nutritionData'].isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Nutrition Information",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            SizedBox(height: 10),
                                            // Display food name
                                            if (mealData!['nutritionData']
                                                    .containsKey('data') &&
                                                mealData!['nutritionData']
                                                        ['data']
                                                    .containsKey('name'))
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 5),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.restaurant,
                                                        size: 16,
                                                        color: primaryColor),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      "Food: ${mealData!['nutritionData']['data']['name']}",
                                                      style: TextStyle(
                                                          fontSize: 14),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                            // Nutrition values
                                            if (mealData!['nutritionData']
                                                    .containsKey('data') &&
                                                mealData!['nutritionData']
                                                        ['data']
                                                    .containsKey('nutrition'))
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // Calories
                                                  if (mealData!['nutritionData']
                                                          ['data']['nutrition']
                                                      .containsKey('calories'))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 5),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .local_fire_department,
                                                              size: 16,
                                                              color: Colors
                                                                  .orange),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            "Calories: ${mealData!['nutritionData']['data']['nutrition']['calories']}",
                                                            style: TextStyle(
                                                                fontSize: 14),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                  // Protein
                                                  if (mealData!['nutritionData']
                                                          ['data']['nutrition']
                                                      .containsKey('protein'))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 5),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .fitness_center,
                                                              size: 16,
                                                              color:
                                                                  Colors.blue),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            "Protein: ${mealData!['nutritionData']['data']['nutrition']['protein']}g",
                                                            style: TextStyle(
                                                                fontSize: 14),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                  // Carbs
                                                  if (mealData!['nutritionData']
                                                          ['data']['nutrition']
                                                      .containsKey('carbs'))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 5),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.grain,
                                                              size: 16,
                                                              color:
                                                                  Colors.amber),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            "Carbs: ${mealData!['nutritionData']['data']['nutrition']['carbs']}g",
                                                            style: TextStyle(
                                                                fontSize: 14),
                                                          ),
                                                        ],
                                                      ),
                                                    ),

                                                  // Fat
                                                  if (mealData!['nutritionData']
                                                          ['data']['nutrition']
                                                      .containsKey('fat'))
                                                    Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              bottom: 5),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.opacity,
                                                              size: 16,
                                                              color: Colors
                                                                  .yellow[700]),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            "Fat: ${mealData!['nutritionData']['data']['nutrition']['fat']}g",
                                                            style: TextStyle(
                                                                fontSize: 14),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),

                                            // Health benefits if available
                                            if (mealData!['nutritionData']
                                                    .containsKey('data') &&
                                                mealData!['nutritionData']
                                                        ['data']
                                                    .containsKey(
                                                        'healthBenefits') &&
                                                mealData!['nutritionData']
                                                            ['data']
                                                        ['healthBenefits']
                                                    is List &&
                                                (mealData!['nutritionData']
                                                                ['data']
                                                            ['healthBenefits']
                                                        as List)
                                                    .isNotEmpty) ...[
                                              SizedBox(height: 10),
                                              Text(
                                                "Health Benefits:",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children:
                                                    (mealData!['nutritionData']
                                                                    ['data'][
                                                                'healthBenefits']
                                                            as List)
                                                        .map(
                                                            (benefit) =>
                                                                Container(
                                                                  padding: EdgeInsets
                                                                      .symmetric(
                                                                          horizontal:
                                                                              8,
                                                                          vertical:
                                                                              4),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: Colors
                                                                        .green
                                                                        .withOpacity(
                                                                            0.1),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            12),
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .green
                                                                            .withOpacity(0.3)),
                                                                  ),
                                                                  child: Text(
                                                                    benefit
                                                                        .toString(),
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                      color: Colors
                                                                              .green[
                                                                          700],
                                                                    ),
                                                                  ),
                                                                ))
                                                        .toList()
                                                        .cast<Widget>(),
                                              ),
                                            ],

                                            // Cautions if available
                                            if (mealData!['nutritionData']
                                                    .containsKey('data') &&
                                                mealData!['nutritionData']
                                                        ['data']
                                                    .containsKey('cautions') &&
                                                mealData!['nutritionData']
                                                        ['data']['cautions']
                                                    is List &&
                                                (mealData!['nutritionData']
                                                            ['data']['cautions']
                                                        as List)
                                                    .isNotEmpty) ...[
                                              SizedBox(height: 10),
                                              Text(
                                                "Cautions:",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              Wrap(
                                                spacing: 6,
                                                runSpacing: 6,
                                                children: (mealData![
                                                                'nutritionData']
                                                            ['data']['cautions']
                                                        as List)
                                                    .map((caution) => Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors.orange
                                                                .withOpacity(
                                                                    0.1),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                                color: Colors
                                                                    .orange
                                                                    .withOpacity(
                                                                        0.3)),
                                                          ),
                                                          child: Text(
                                                            caution.toString(),
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .orange[700],
                                                            ),
                                                          ),
                                                        ))
                                                    .toList()
                                                    .cast<Widget>(),
                                              ),
                                            ],

                                            // Show when the meal was logged
                                            if (mealData!.containsKey(
                                                    'loggedTime') &&
                                                mealData!['loggedTime'] !=
                                                    null) ...[
                                              SizedBox(height: 15),
                                              Divider(),
                                              SizedBox(height: 5),
                                              Row(
                                                children: [
                                                  Icon(Icons.access_time,
                                                      size: 14,
                                                      color: Colors.grey[600]),
                                                  SizedBox(width: 5),
                                                  Text(
                                                    "Logged: ${mealData!['loggedTime']}",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    SizedBox(height: 20,),
                                    // Meal description
                                    if (mealData!.containsKey('description') &&
                                        mealData!['description'] != null &&
                                        mealData!['description']
                                            .toString()
                                            .isNotEmpty)
                                      SizedBox(
                                        height: 20,
                                      ),
                                    Container(
                                      width: double.infinity,
                                      padding: EdgeInsets.all(15),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Meal Description",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            mealData!['description'],
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 25),

                                    // Bottom buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (mealData!['isHealthy'] == false)
                                          TextButton.icon(
                                            icon: Icon(Icons.edit),
                                            label: Text("LOG NEW MEAL"),
                                            style: TextButton.styleFrom(
                                              foregroundColor: primaryColor,
                                            ),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _showMealLogBottomSheet(); // Show the meal log dialog
                                            },
                                          ),
                                        SizedBox(width: 10),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 12),
                                          ),
                                          child: Text("CLOSE"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                  ),
                );
              },
            );
          },
        );
      } catch (e) {
        print("Error showing meal details dialog: $e");
      }
    }

    // Main function to handle wake-up task interaction
    void _showDietTaskOptions() {
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Wake Up Task",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                OptionCard(
                  icon: Icons.restaurant,
                  color: _getCategoryColor(task.category),
                  title: "Log Meals",
                  description: "Log your meals with a photo or notes",
                  onTap: () {
                    Navigator.pop(context);
                    _showMealLogBottomSheet();
                  },
                ),
                OptionCard(
                    icon: Icons.restaurant,
                    color: _getCategoryColor(task.category),
                    title: "View Meal Details",
                    description: "View your meal details",
                    onTap: () {
                      Navigator.pop(context);
                      _showMealDetailsDialog(task);
                    }),
                OptionCard(
                  icon: Icons.tips_and_updates,
                  color: _getCategoryColor(task.category),
                  title: "View Healthy Diet Tips",
                  description: "Get strategies for eating healthy",
                  onTap: () {
                    Navigator.pop(context);
                    _showTaskSuggestionDialog(task);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    // Show the meal log dialog when the function is called
    _showDietTaskOptions();
  }

// 4. Exercise for 1 Hour
  void _handleExerciseTask(Project50Task task) {
    print("Task ID: ${task.id}");
    void _saveExerciseLog(
        String activityType,
        int durationMinutes,
        int caloriesBurned,
        String intensity,
        List<String> muscleGroups,
        double userWeight) async {
      // Validate inputs
      if (activityType.isEmpty || durationMinutes <= 0) {
        return;
      }

      try {
        // Get current date for the log
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);

        // Format duration for display
        int hours = durationMinutes ~/ 60;
        int minutes = durationMinutes % 60;
        String durationStr =
            hours > 0 ? "${hours}h ${minutes}m" : "${minutes}m";

        // Create exercise log data
        Map<String, dynamic> exerciseData = {
          'activityType': activityType,
          'durationMinutes': durationMinutes,
          'caloriesBurned': caloriesBurned,
          'intensity': intensity,
          'muscleGroups': muscleGroups,
          'date': today.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
          'weight': userWeight,
        };

        // Get current task and update its description
        if (task != null && task.id.isNotEmpty) {
          // Update task description to include exercise log info
          String updatedDescription =
              "Exercise Log: $activityType for $durationStr, Intensity: $intensity, Calories: $caloriesBurned, Muscle Groups: $muscleGroups, Date: $today, Weight: $userWeight";

          // Create updated task object
          Project50Task updatedTask = Project50Task(
            id: task.id,
            title: task.title,
            category: task.category,
            description: updatedDescription,
            time: task.time,
            isCompleted: true,
            day: task.day,
            createdAt: task.createdAt,
            updatedAt: DateTime.now(),
            orderTask: task.orderTask,
          );

          // Update task in Firestore
          await _project50service.updateProject50TaskDetails(
              task.id, updatedTask);

          _showCompletionAnimation();

          _loadProject50Data();

          print("Exercise log saved successfully!");
        }
      } catch (e) {
        print("Error saving exercise log: $e");
      }
    }

    // Calculate calories based on activity type, duration, intensity, and user attributes
    int _calculateCalories(String activityType, int durationMinutes,
        String intensity, double weight) {
      // MET values (Metabolic Equivalent of Task) for different activities
      Map<String, Map<String, double>> metValues = {
        'Running': {'Low': 7.0, 'Medium': 9.8, 'High': 12.5},
        'Cycling': {'Low': 4.0, 'Medium': 8.0, 'High': 12.0},
        'Swimming': {'Low': 5.0, 'Medium': 7.0, 'High': 10.0},
        'Walking': {'Low': 2.5, 'Medium': 3.5, 'High': 5.0},
        'Weightlifting': {'Low': 3.0, 'Medium': 5.0, 'High': 6.0},
        'HIIT': {'Low': 6.0, 'Medium': 8.5, 'High': 12.0},
        'Yoga': {'Low': 2.5, 'Medium': 4.0, 'High': 6.0},
        'Dance': {'Low': 4.5, 'Medium': 6.5, 'High': 8.0},
        'Basketball': {'Low': 6.0, 'Medium': 8.0, 'High': 10.0},
        'Soccer': {'Low': 5.0, 'Medium': 7.0, 'High': 10.0},
      };

      // Default to medium intensity running if activity not found
      double met = metValues.containsKey(activityType)
          ? metValues[activityType]![intensity] ?? 8.0
          : 8.0;

      // Default weight if not provided (in kg)
      weight = weight > 0 ? weight : 50.0;

      // Formula: calories = MET * weight in kg * duration in hours
      double durationHours = durationMinutes / 60.0;
      int calories = (met * weight * durationHours).round();

      return calories;
    }

    // Get icon based on exercise type
    IconData getExerciseIcon(String exerciseType) {
      switch (exerciseType.toLowerCase()) {
        case 'running':
          return Icons.directions_run;
        case 'cycling':
          return Icons.directions_bike;
        case 'swimming':
          return Icons.pool;
        case 'walking':
          return Icons.directions_walk;
        case 'yoga':
          return Icons.self_improvement;
        case 'weightlifting':
          return Icons.fitness_center;
        case 'hiit':
          return Icons.timer;
        default:
          return Icons.fitness_center;
      }
    }

    // Show exercise logging dialog
    void _showExerciseLogDialog() {
      String selectedActivity = 'Running';
      int selectedDuration = 60; // Default to 60 minutes
      String selectedIntensity = 'Medium';
      List<String> selectedMuscleGroups = [];
      double userWeight = 50.0; // Default weight in kg
      int estimatedCalories = 0;

      final TextEditingController weightController = TextEditingController();

      weightController.text = userWeight.toString();

      // Predefined lists
      final List<String> activities = [
        'Running',
        'Cycling',
        'Swimming',
        'Walking',
        'Weightlifting',
        'HIIT',
        'Yoga',
        'Dance',
        'Basketball',
        'Soccer'
      ];

      final List<String> intensities = ['Low', 'Medium', 'High'];

      final Map<String, List<String>> muscleGroupsByActivity = {
        'Running': ['Quadriceps', 'Hamstrings', 'Calves', 'Core'],
        'Cycling': ['Quadriceps', 'Hamstrings', 'Calves', 'Glutes'],
        'Swimming': ['Shoulders', 'Back', 'Core', 'Arms', 'Legs'],
        'Walking': ['Calves', 'Hamstrings', 'Quadriceps'],
        'Weightlifting': ['Chest', 'Back', 'Shoulders', 'Arms', 'Legs', 'Core'],
        'HIIT': ['Full Body', 'Core', 'Cardio'],
        'Yoga': ['Core', 'Flexibility', 'Balance'],
        'Dance': ['Cardio', 'Core', 'Legs', 'Coordination'],
        'Basketball': ['Legs', 'Cardio', 'Arms', 'Core'],
        'Soccer': ['Legs', 'Cardio', 'Core', 'Agility'],
      };

      // Update calories calculation whenever inputs change
      void updateCalories() {
        estimatedCalories = _calculateCalories(
            selectedActivity, selectedDuration, selectedIntensity, userWeight);
      }

      // Initial calculation
      updateCalories();

      // Get color based on intensity level
      Color _getIntensityColor(String intensity) {
        switch (intensity) {
          case 'Low':
            return Colors.green;
          case 'Medium':
            return Colors.orange;
          case 'High':
            return Colors.red;
          default:
            return Colors.blue;
        }
      }

      // Get exercise tip based on activity
      String _getExerciseTip(String activity) {
        Map<String, String> tips = {
          'Running':
              "Start with a proper warm-up and focus on proper form. Land mid-foot rather than heel or toe.",
          'Cycling':
              "Adjust your bike seat to proper height. Your leg should be almost fully extended at the bottom of your pedal stroke.",
          'Swimming':
              "Focus on your breathing technique. Exhale underwater and inhale quickly when your face is above water.",
          'Walking':
              "Maintain good posture and take quick, short steps rather than long strides for better efficiency.",
          'Weightlifting':
              "Focus on proper form rather than lifting heavy. Gradually increase weight as you perfect your technique.",
          'HIIT':
              "Allow for adequate rest between intense intervals. The recovery periods are just as important as the work periods.",
          'Yoga':
              "Breathe deeply through your poses and never force your body into positions that cause pain.",
          'Dance':
              "Stay hydrated and focus on enjoying the movement rather than perfection.",
          'Basketball':
              "Practice your fundamental skills like dribbling, passing, and shooting regularly.",
          'Soccer':
              "Work on both your dominant and non-dominant foot to improve overall control and versatility.",
        };

        return tips[activity] ??
            "Start slow and gradually increase intensity. Listen to your body and stay hydrated.";
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              final mediaQuery = MediaQuery.of(context);
              final availableHeight = mediaQuery.size.height -
                  mediaQuery.padding.top -
                  mediaQuery.padding.bottom;
              final bottomSheetHeight = availableHeight * 0.9;

              Color primaryColor = _getCategoryColor(task.category);
              List<String> availableMuscleGroups =
                  muscleGroupsByActivity[selectedActivity] ?? [];

              return Container(
                height: bottomSheetHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.all(20),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle at the top
                        Container(
                          margin: EdgeInsets.only(top: 10),
                          width: 60,
                          height: 5,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        // Header with task title
                        Text(
                          "Exercise Tracker",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),

                        // Weight input
                        Container(
                          margin: EdgeInsets.only(bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Your Weight (kg)",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.remove),
                                            onPressed: () {
                                              setState(() {
                                                if (userWeight > 30) {
                                                  userWeight = userWeight - 1.0;
                                                  weightController.text =
                                                      userWeight.toString();
                                                  updateCalories();
                                                }
                                              });
                                            },
                                          ),
                                          Expanded(
                                            child: TextFormField(
                                              controller: weightController,
                                              textAlign: TextAlign.center,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                              ),
                                              onChanged: (value) {
                                                setState(() {
                                                  userWeight =
                                                      double.tryParse(value) ??
                                                          userWeight;
                                                  updateCalories();
                                                });
                                              },
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.add),
                                            onPressed: () {
                                              setState(() {
                                                userWeight = userWeight + 1.0;
                                                weightController.text =
                                                    userWeight.toString();
                                                updateCalories();
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10),
                                  Container(
                                    padding: EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "kg",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Activity type selector
                        Container(
                          margin: EdgeInsets.only(bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Activity Type",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Container(
                                height: 50,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: activities.map((activity) {
                                    bool isSelected =
                                        activity == selectedActivity;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedActivity = activity;
                                          selectedMuscleGroups = [];
                                          updateCalories();
                                        });
                                      },
                                      child: Container(
                                        margin: EdgeInsets.only(right: 8),
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? primaryColor
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Center(
                                          child: Text(
                                            activity,
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Duration input
                        Container(
                          margin: EdgeInsets.only(bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Duration (minutes)",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Slider(
                                      value: selectedDuration.toDouble(),
                                      min: 5,
                                      max: 120,
                                      divisions: 23,
                                      label: "$selectedDuration min",
                                      activeColor: primaryColor,
                                      onChanged: (double value) {
                                        setState(() {
                                          selectedDuration = value.round();
                                          updateCalories();
                                        });
                                      },
                                    ),
                                  ),
                                  Container(
                                    width: 60,
                                    child: Text(
                                      "$selectedDuration min",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    size: 14,
                                    color: selectedDuration >= 60
                                        ? Colors.green
                                        : Colors.orange,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    selectedDuration >= 60
                                        ? "Great! You've met the 1-hour goal."
                                        : "Try to exercise for at least 60 minutes",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: selectedDuration >= 60
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Intensity selector
                        Container(
                          margin: EdgeInsets.only(bottom: 15),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Intensity",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: intensities.map((intensity) {
                                  bool isSelected =
                                      intensity == selectedIntensity;
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        selectedIntensity = intensity;
                                        updateCalories();
                                      });
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? _getIntensityColor(intensity)
                                            : Colors.grey[200],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected
                                              ? _getIntensityColor(intensity)
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        intensity,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        // Muscle groups
                        if (availableMuscleGroups.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(bottom: 15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Targeted Muscle Groups",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: availableMuscleGroups.map((muscle) {
                                    bool isSelected =
                                        selectedMuscleGroups.contains(muscle);
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            selectedMuscleGroups.remove(muscle);
                                          } else {
                                            selectedMuscleGroups.add(muscle);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? primaryColor.withOpacity(0.2)
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.transparent,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          muscle,
                                          style: TextStyle(
                                            color: isSelected
                                                ? primaryColor
                                                : Colors.black,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),

                        // Calories burned indicator
                        Container(
                          margin: EdgeInsets.only(bottom: 20, top: 5),
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.7),
                                primaryColor.withOpacity(0.3)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Estimated Calories",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10),
                              Text(
                                "$estimatedCalories",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "calories burned",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Exercise tips
                        Container(
                          margin: EdgeInsets.only(bottom: 20),
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.blue.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    "Exercise Tip",
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6),
                              Text(
                                _getExerciseTip(selectedActivity),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[800],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action buttons in a fixed position at bottom
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 20, vertical: 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: Offset(0, -3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text("CANCEL"),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey[700],
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              SizedBox(width: 15),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    elevation: 2,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.save, size: 18),
                                      SizedBox(width: 8),
                                      Text("SAVE"),
                                    ],
                                  ),
                                  onPressed: () {
                                    // Save the exercise log data with weight
                                    _saveExerciseLog(
                                      selectedActivity,
                                      selectedDuration,
                                      estimatedCalories,
                                      selectedIntensity,
                                      selectedMuscleGroups,
                                      userWeight,
                                    );
                                    Navigator.of(context).pop();

                                    // Show achievement if relevant
                                    // if (selectedDuration >= 60 &&
                                    //     estimatedCalories > 300) {
                                    //   _showExerciseAchievement(
                                    //       selectedActivity, estimatedCalories);
                                    // }
                                  },
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
            },
          );
        },
      );
    }

    void _showExerciseProgressDialog(Project50Task task) async {
      try {
        // Create a loading state while data is being fetched
        bool isLoading = true;
        Map<String, dynamic>? exerciseData;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setState) {
                final mediaQuery = MediaQuery.of(context);
                final availableHeight = mediaQuery.size.height -
                    mediaQuery.padding.top -
                    mediaQuery.padding.bottom;
                final bottomSheetHeight = availableHeight * 0.65;
                Color primaryColor = _getCategoryColor(task.category);

                void loadExerciseData() async {
                  try {
                    final taskFromDb =
                        await _project50service.getProject50TaskById(task.id);
                    if (taskFromDb == null) {
                      throw Exception(
                          "Task with ID ${task.id} not found in database");
                    }

                    // Parse exercise data directly from the task description
                    String description = taskFromDb.description;

                    print(
                        "Description to parse: $description"); // Debugging line

                    // First try to match the format with both hours and minutes
                    final exerciseInfoRegexWithHours = RegExp(
                        r'Exercise Log: (.*?) for (\d+)h (\d+)m, Intensity: (.*?), Calories: (\d+), Muscle Groups: \[(.*?)\], Date: (.*?), Weight: (\d+\.?\d*)');

                    // Alternative regex for format with only minutes
                    final exerciseInfoRegexMinutesOnly = RegExp(
                        r'Exercise Log: (.*?) for (\d+)m, Intensity: (.*?), Calories: (\d+), Muscle Groups: \[(.*?)\], Date: (.*?), Weight: (\d+\.?\d*)');

                    var match =
                        exerciseInfoRegexWithHours.firstMatch(description);
                    bool isHourFormat = true;

                    // If no match with hours format, try minutes-only format
                    if (match == null) {
                      match =
                          exerciseInfoRegexMinutesOnly.firstMatch(description);
                      isHourFormat = false;
                    }

                    if (match != null) {
                      String exerciseType;
                      int durationMinutes;
                      String intensity;
                      int calories;
                      List<String> muscleGroups;
                      String exerciseDate;
                      double weight;

                      if (isHourFormat) {
                        exerciseType = match.group(1) ?? '';
                        final hours = match.group(2) != null
                            ? int.parse(match.group(2)!)
                            : 0;
                        final minutes = match.group(3) != null
                            ? int.parse(match.group(3)!)
                            : 0;
                        intensity = match.group(4) ?? '';
                        calories = match.group(5) != null
                            ? int.parse(match.group(5)!)
                            : 0;
                        muscleGroups = match.group(6) != null
                            ? match.group(6)!.split(', ')
                            : [];
                        exerciseDate =
                            match.group(7) ?? task.updatedAt.toIso8601String();
                        weight = match.group(8) != null
                            ? double.parse(match.group(8)!)
                            : 0.0;

                        durationMinutes = (hours * 60) + minutes;
                      } else {
                        exerciseType = match.group(1) ?? '';
                        final minutes = match.group(2) != null
                            ? int.parse(match.group(2)!)
                            : 0;
                        intensity = match.group(3) ?? '';
                        calories = match.group(4) != null
                            ? int.parse(match.group(4)!)
                            : 0;
                        muscleGroups = match.group(5) != null
                            ? match.group(5)!.split(', ')
                            : [];
                        exerciseDate =
                            match.group(6) ?? task.updatedAt.toIso8601String();
                        weight = match.group(7) != null
                            ? double.parse(match.group(7)!)
                            : 0.0;
                        durationMinutes = minutes;
                      }

                      print("Weight: $weight");

                      setState(() {
                        exerciseData = {
                          'exerciseType': exerciseType,
                          'durationMinutes': durationMinutes,
                          'intensity': intensity,
                          'calories': calories,
                          'muscleGroups': muscleGroups,
                          'date': exerciseDate,
                          'weight': weight,
                        };
                        isLoading = false;
                      });
                    } else {
                      print("No match found in description"); // Debugging line
                      setState(() {
                        isLoading = false;
                        exerciseData = null;
                      });
                    }
                  } catch (e) {
                    print("Error loading exercise data: $e");
                    setState(() {
                      isLoading = false;
                      exerciseData = null;
                    });
                  }
                }

// Load data when dialog is first shown
                if (isLoading && exerciseData == null) {
                  loadExerciseData();
                }

                // Get color based on intensity
                Color getIntensityColor(String intensity) {
                  switch (intensity.toLowerCase()) {
                    case 'high':
                      return Colors.red.shade700;
                    case 'medium':
                      return Colors.orange.shade700;
                    case 'low':
                      return Colors.green.shade600;
                    default:
                      return Colors.blue.shade600;
                  }
                }

                // Format duration
                String formatDuration(int minutes) {
                  int hours = minutes ~/ 60;
                  int mins = minutes % 60;
                  return '${hours}h ${mins}m';
                }

                return Container(
                  height: bottomSheetHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: primaryColor),
                                SizedBox(height: 16),
                                Text("Loading exercise details...")
                              ],
                            ),
                          )
                        : exerciseData == null
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.sports_score,
                                        size: 50, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      "No exercise data found for this task",
                                      style: TextStyle(fontSize: 16),
                                      textAlign: TextAlign.center,
                                    ),
                                    SizedBox(height: 20),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: Text("CLOSE"),
                                    ),
                                  ],
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Animated Header with exercise type icon
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        // Circular background
                                        Container(
                                          height: 80,
                                          width: 80,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.rectangle,
                                            color:
                                                primaryColor.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        // Icon based on exercise type
                                        Icon(
                                          getExerciseIcon(
                                              exerciseData?['exerciseType'] ??
                                                  ""),
                                          color: primaryColor,
                                          size: 32,
                                        ),
                                        // Title text positioned below
                                        Positioned(
                                          bottom: 0,
                                          child: Text(
                                            exerciseData!['exerciseType'] ??
                                                "Exercise",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                  
                                    // Compact task reference
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 15, vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color:
                                                primaryColor.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.task_alt,
                                              color: primaryColor, size: 16),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              "${task.title} (${(exerciseData!['weight'] ?? 0).toStringAsFixed(1)}kg)",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "Day ${task.day}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 20),
                  
                                    // Date and time
                                    if (exerciseData!.containsKey('date'))
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 15),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                size: 16,
                                                color: Colors.grey[700]),
                                            SizedBox(width: 8),
                                            Text(
                                              DateFormat('MMMM d, yyyy').format(
                                                  DateTime.parse(
                                                      exerciseData!['date'])),
                                              style: TextStyle(
                                                color: Colors.grey[800],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    SizedBox(height: 20),
                  
                                    // Exercise metrics in a row
                                    Row(
                                      children: [
                                        // Duration
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.all(15),
                                            decoration: BoxDecoration(
                                              color:
                                                  primaryColor.withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(Icons.timer,
                                                    color: primaryColor),
                                                SizedBox(height: 6),
                                                Text(
                                                  "Duration",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  formatDuration(exerciseData![
                                                          'durationMinutes'] ??
                                                      0),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        // Intensity
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.all(15),
                                            decoration: BoxDecoration(
                                              color: getIntensityColor(
                                                      exerciseData![
                                                              'intensity'] ??
                                                          '')
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.speed,
                                                  color: getIntensityColor(
                                                      exerciseData![
                                                              'intensity'] ??
                                                          ''),
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  "Intensity",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  exerciseData!['intensity'] ??
                                                      "N/A",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: getIntensityColor(
                                                        exerciseData![
                                                                'intensity'] ??
                                                            ''),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 10),
                                        // Calories
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.all(15),
                                            decoration: BoxDecoration(
                                              color: Colors.orange
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                    Icons.local_fire_department,
                                                    color: Colors.orange),
                                                SizedBox(height: 6),
                                                Text(
                                                  "Calories",
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  "${exerciseData!['calories'] ?? 0}",
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20),
                  
                                    // Muscle Groups
                                    if (exerciseData!['muscleGroups'][0] != '')
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(15),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius:
                                              BorderRadius.circular(15),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Muscle Groups",
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children:
                                                  (exerciseData!['muscleGroups']
                                                          as List<String>)
                                                      .map((group) {
                                                return Container(
                                                  padding: EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6),
                                                  decoration: BoxDecoration(
                                                    color: primaryColor
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                        color: primaryColor
                                                            .withOpacity(0.3)),
                                                  ),
                                                  child: Text(
                                                    group,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: primaryColor,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    SizedBox(height: 25),
                  
                                    // Bottom buttons
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          icon: Icon(Icons.edit),
                                          label: Text("LOG NEW EXERCISE"),
                                          style: TextButton.styleFrom(
                                            foregroundColor: primaryColor,
                                          ),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _showExerciseLogDialog(); // You would need to implement this
                                          },
                                        ),
                                        SizedBox(width: 10),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(30),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 12),
                                          ),
                                          child: Text("CLOSE"),
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                  ),
                );
              },
            );
          },
        );
      } catch (e) {
        print("Error showing exercise progress dialog: $e");
      }
    }

    // Main function to handle exercise task interaction
    void _showExerciseTaskOptions() {
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Exercise Task",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                OptionCard(
                  icon: Icons.fitness_center,
                  color: _getCategoryColor(task.category),
                  title: "Log Exercise",
                  description: "Record your workout and track calories burned",
                  onTap: () {
                    Navigator.pop(context);
                    _showExerciseLogDialog();
                  },
                ),
                OptionCard(
                  icon: Icons.bar_chart,
                  color: _getCategoryColor(task.category),
                  title: "View Progress",
                  description: "See your exercise history and achievements",
                  onTap: () {
                    Navigator.pop(context);
                    _showExerciseProgressDialog(task);
                  },
                ),
                OptionCard(
                  icon: Icons.tips_and_updates,
                  color: _getCategoryColor(task.category),
                  title: "Exercise Tips",
                  description: "Get workout suggestions and techniques",
                  onTap: () {
                    Navigator.pop(context);
                    _showTaskSuggestionDialog(task);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    // Entry point - call this when user interacts with exercise task
    _showExerciseTaskOptions();
  }

// 5. Read for 1 Hour
  void _handleReadingTask(Project50Task task) {
    print("Task reading ID: ${task.id}");
    Future<void> _saveReadingLog(
      Project50Task task, // Added as a parameter for clarity
      String bookTitle,
      int startPage,
      int endPage,
      String feelings,
    ) async {
      // Validate inputs
      if (bookTitle.isEmpty || startPage < 0 || endPage < startPage) {
        return;
      }

      try {
        // Get current date for the log
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);

        // Calculate pages read
        int pagesRead = endPage - startPage;

        // Reading duration in minutes (default to 60 but could be adjusted)
        int readingMinutes = 60;

        // Fetch the current task's details from sqflite
        final taskFromDb =
            await _project50service.getProject50TaskById(task.id);
        if (taskFromDb == null) {
          throw Exception("Task with ID ${task.id} not found in database");
        }

        // Create reading log data
        Map<String, dynamic> readingData = {
          'bookTitle': bookTitle,
          'startPage': startPage,
          'endPage': endPage,
          'pagesRead': pagesRead,
          'feelings': feelings,
          'readingDuration': readingMinutes,
          'date': today.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Update task description to include reading log info
        String baseDescription = taskFromDb.description;
        String updatedDescription =
            "$baseDescription\n\nReading Log: Book \"$bookTitle\", Pages $startPage-$endPage ($pagesRead pages), Duration ${readingMinutes}m, Feeling: $feelings";

        // Create updated task object
        Project50Task updatedTask = Project50Task(
          id: task.id,
          title: task.title,
          category: task.category,
          description: updatedDescription,
          time: task.time,
          isCompleted: true,
          day: task.day,
          createdAt: task.createdAt,
          updatedAt: DateTime.now(),
          orderTask: task.orderTask,
        );

        // Update task in sqflite
        await _project50service.updateProject50TaskDetails(
            task.id, updatedTask);

        _showCompletionAnimation();

        _loadProject50Data();

        // Update local state for immediate UI feedback
        setState(() {
          final index = _allTasks.indexWhere((t) => t.id == task.id);
          if (index != -1) {
            _allTasks[index] = updatedTask;
          }

          if (_tasksByDay.containsKey(task.day)) {
            final dayIndex =
                _tasksByDay[task.day]!.indexWhere((t) => t.id == task.id);
            if (dayIndex != -1) {
              _tasksByDay[task.day]![dayIndex] = updatedTask;
            }
          }

          _completedTasks = _allTasks.where((t) => t.isCompleted).length;
          _overallProgress = _completedTasks / (7 * 50);
        });

        print("Reading log saved successfully!");

        SuccessToast.show(context, "Reading log saved successfully!");

        // Optionally refresh data
        await _loadProject50Data();
      } catch (e) {
        print("Error saving reading log: $e");
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Error saving reading log: $e")),
        // );
      }
    }

    // Extract reading logs from task description
    Future<List<Map<String, dynamic>>> _extractReadingLogs(
        Project50Task task) async {
      List<Map<String, dynamic>> logs = [];

      final taskFromDB = await _project50service.getProject50TaskById(task.id);
      if (taskFromDB == null) {
        throw Exception("Task with ID ${task.id} not found in database");
      }

      // Check if document exists and has description field
      String description = taskFromDB.description;

      // Regex pattern to match reading logs
      RegExp logPattern = RegExp(
        r'Reading Log: Book \"([^\"]+)\", Pages (\d+)-(\d+) \((\d+) pages\), Duration (\d+)m(?:, Feeling: ([^,\n]+))?',
        multiLine: true,
      );

      // Find all matches
      Iterable<RegExpMatch> matches = logPattern.allMatches(description);
      for (var match in matches) {
        logs.add({
          'bookTitle': match.group(1) ?? '',
          'startPage': int.tryParse(match.group(2) ?? '0') ?? 0,
          'endPage': int.tryParse(match.group(3) ?? '0') ?? 0,
          'pagesRead': int.tryParse(match.group(4) ?? '0') ?? 0,
          'duration': match.group(5) ?? '60',
          'feeling': match.group(6) ?? 'Not specified',
        });
      }

      return logs;
    }

    // Reading log and mood
    void _showReadingLogDialog() {
      // Initialize variables for the dialog
      String bookTitle = "";
      int startPage = 0;
      int endPage = 0;
      String selectedFeeling = "Neutral";
      List<String> feelingOptions = [
        "Inspired",
        "Relaxed",
        "Enlightened",
        "Focused",
        "Excited",
        "Curious",
        "Neutral",
        "Confused",
        "Bored",
        "Distracted"
      ];

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              // Calculate pages read
              int pagesRead = endPage > startPage ? endPage - startPage : 0;

              Color primaryColor = _getCategoryColor(task.category);

              return Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                child: Container(
                  padding: EdgeInsets.all(24),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with task title
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.2),
                              child: Icon(
                                Icons.auto_stories,
                                color: primaryColor,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Reading Tracker",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Day ${task.day}",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),

                        Divider(height: 30),

                        // Book selection
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.book, color: primaryColor, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Book Title",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            TextField(
                              decoration: InputDecoration(
                                hintText: "Enter book title",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                fillColor: Colors.grey[50],
                                filled: true,
                                prefixIcon:
                                    Icon(Icons.menu_book, color: primaryColor),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  bookTitle = value;
                                });
                              },
                            ),
                          ],
                        ),

                        SizedBox(height: 20),

                        // Page tracking
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.bookmark_border,
                                    color: primaryColor, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Page Tracking",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: "Start Page",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      fillColor: Colors.grey[50],
                                      filled: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        startPage = int.tryParse(value) ?? 0;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      labelText: "End Page",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      fillColor: Colors.grey[50],
                                      filled: true,
                                      contentPadding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 16),
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (value) {
                                      setState(() {
                                        endPage = int.tryParse(value) ?? 0;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: 16),

                            // Pages read indicator
                            if (pagesRead > 0)
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primaryColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.auto_stories,
                                      color: primaryColor,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Read $pagesRead pages",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: primaryColor,
                                          ),
                                        ),
                                        // FittedBox(
                                        //   fit: BoxFit.scaleDown,
                                        //   child: Text(
                                        //     "Approximately ${(pagesRead / 20).toStringAsFixed(1)} hours of reading",
                                        //     style: TextStyle(
                                        //       fontSize: 12,
                                        //       color: Colors.grey[700],
                                        //     ),
                                        //   ),
                                        // ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),

                        SizedBox(height: 20),

                        // How did you feel about your reading
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.emoji_emotions_outlined,
                                    color: primaryColor, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Feeling of reading?",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Container(
                              height: 50,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: feelingOptions.map((feeling) {
                                  bool isSelected = selectedFeeling == feeling;
                                  return Container(
                                    margin: EdgeInsets.only(right: 10),
                                    child: InkWell(
                                      onTap: () {
                                        setState(() {
                                          selectedFeeling = feeling;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? primaryColor
                                              : Colors.grey[200],
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          feeling,
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black87,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.save),
                                label: Text("SAVE READING LOG"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                ),
                                onPressed: () {
                                  // Validate inputs
                                  if (bookTitle.isEmpty ||
                                      startPage >= endPage) {
                                    // ScaffoldMessenger.of(context).showSnackBar(
                                    //   SnackBar(
                                    //     content: Text(
                                    //       "Please enter valid book title and page numbers",
                                    //       style: TextStyle(color: Colors.white),
                                    //     ),
                                    //     backgroundColor: Colors.red,
                                    //     behavior: SnackBarBehavior.floating,
                                    //     shape: RoundedRectangleBorder(
                                    //       borderRadius:
                                    //           BorderRadius.circular(10),
                                    //     ),
                                    //   ),
                                    // );
                                    ErrorToast.show(context,
                                        "Please enter valid book title and page numbers");
                                    return;
                                  }

                                  // Save the reading log
                                  _saveReadingLog(task, bookTitle, startPage,
                                      endPage, selectedFeeling);

                                  Navigator.of(context).pop();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    }

    // Show studied book history
    void _showStudiedBooksHistory() async {
      List<Map<String, dynamic>> readingLogs = await _extractReadingLogs(task);

      showDialog(
        context: context,
        builder: (BuildContext context) {
          Color primaryColor = _getCategoryColor(task.category);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.2),
                        child: Icon(
                          Icons.history_edu,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Reading History",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "${readingLogs.length} reading sessions",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),

                  Divider(height: 30),

                  // Reading history list
                  readingLogs.isEmpty
                      ? Container(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              Icon(
                                Icons.book_outlined,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: 16),
                              Text(
                                "No reading sessions yet",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.5,
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: readingLogs.length,
                            separatorBuilder: (context, index) => Divider(),
                            itemBuilder: (context, index) {
                              final log = readingLogs[index];
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Center(
                                        child: Text(
                                          "#${index + 1}",
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${log['bookTitle']}",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.menu_book,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "Pages ${log['startPage']}-${log['endPage']} (${log['pagesRead']} pages)",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.emoji_emotions_outlined,
                                                size: 14,
                                                color: Colors.grey[600],
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                "Feeling: ${log['feeling']}",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          // SizedBox(height: 4),
                                          // Row(
                                          //   children: [
                                          //     Icon(
                                          //       Icons.timelapse,
                                          //       size: 14,
                                          //       color: Colors.grey[600],
                                          //     ),
                                          //     SizedBox(width: 4),
                                          //     Text(
                                          //       "Duration: ${log['duration']} minutes",
                                          //       style: TextStyle(
                                          //         fontSize: 14,
                                          //         color: Colors.grey[700],
                                          //       ),
                                          //     ),
                                          //   ],
                                          // ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                  SizedBox(height: 16),

                  // Action button
                  ElevatedButton.icon(
                    icon: Icon(Icons.add),
                    label: Text("ADD NEW READING SESSION"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showReadingLogDialog();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Main function to handle reading task interaction
    void _showReadingTaskOptions() {
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (BuildContext context) {
          Color primaryColor = _getCategoryColor(task.category);
          return Container(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  "Reading Task Options",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 24),

                // Option Cards with improved UI
                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showReadingLogDialog();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.auto_stories,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Log Reading Session",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Track book, pages read, and your reading experience",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: primaryColor,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showStudiedBooksHistory();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.history_edu,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "View Reading History",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "See all your previous reading sessions",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: primaryColor,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 16),

                InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    _showTaskSuggestionDialog(task);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.lightbulb_outline,
                            color: primaryColor,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Reading Tips",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                "Get strategies for building a reading habit",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: primaryColor,
                          size: 16,
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

    // Entry point - call this when user interacts with reading task
    _showReadingTaskOptions();
  }

// 6. Learn Skill
  void _handleSkillDevelopmentTask(Project50Task task) {
    print("Task skill development ID: ${task.id}");

    void _saveSkillDevelopmentLog(String skillName, String activity,
        int durationMinutes, String progress, String challenge) async {
      // Validate inputs
      if (skillName.isEmpty || activity.isEmpty || durationMinutes <= 0) {
        return;
      }

      try {
        // Get current date for the log
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);

        final taskFromDB =
            await _project50service.getProject50TaskById(task.id);
        if (taskFromDB == null) {
          throw Exception("Task with ID ${task.id} not found in database");
        }

        // Create skill development log data
        Map<String, dynamic> skillData = {
          'skillName': skillName,
          'activity': activity,
          'durationMinutes': durationMinutes,
          'progress': progress,
          'challenge': challenge,
          'date': today.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        if (progress == '') {
          progress = 'Null';
        }

        if (challenge == '') {
          challenge = 'Null';
        }

        // Get current task and update its description
        String baseDescription = taskFromDB.description;
        // Update task description to include skill development log info
        String updatedDescription =
            "$baseDescription\n\nSkill Development Log: Skill \"$skillName\", Activity \"$activity\", Duration ${durationMinutes}m, Progress: $progress, Challenge: $challenge";

        // Create updated task object
        Project50Task updatedTask = Project50Task(
          id: task.id,
          title: task.title,
          category: task.category,
          description: updatedDescription,
          time: task.time,
          isCompleted: true,
          day: task.day,
          createdAt: task.createdAt,
          updatedAt: DateTime.now(),
          orderTask: task.orderTask,
        );

        // Update task in Firestore
        await _project50service.updateProject50TaskDetails(
            task.id, updatedTask);

        _showCompletionAnimation();

        _loadProject50Data();

        print("Skill development log saved successfully!");
      } catch (e) {
        print("Error saving skill development log: $e");
      }
    }

// Extract skill development logs from task description
    Future<List<Map<String, dynamic>>> _extractSkillDevelopmentLogs(
        Project50Task task) async {
      List<Map<String, dynamic>> logs = [];

      final taskFromDb = await _project50service.getProject50TaskById(task.id);
      if (taskFromDb == null) {
        throw Exception("Task with ID ${task.id} not found in database");
      }

      // Check if document exists and has description field

      String description = taskFromDb.description;
      print("Description: ${description}");
      // Regex pattern to match skill development logs
      RegExp logPattern = RegExp(
        r'Skill Development Log: Skill \"([^\"]+)\", Activity \"([^\"]+)\", Duration (\d+)m, Progress: ([^,]+), Challenge: ([^,\n]+)',
        multiLine: true,
      );

      // Find all matches
      Iterable<RegExpMatch> matches = logPattern.allMatches(description);
      for (var match in matches) {
        logs.add({
          'skillName': match.group(1) ?? '',
          'activity': match.group(2) ?? '',
          'durationMinutes': int.tryParse(match.group(3) ?? '0') ?? 0,
          'progress': match.group(4) ?? 'Not specified',
          'challenge': match.group(5) ?? 'Not specified',
        });
      }

      return logs;
    }

    Widget _sectionTitle(IconData icon, String title, Color color) {
      return Row(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
        ],
      );
    }

// Helper widget for enhanced text fields
    Widget _enhancedTextField({
      required String hintText,
      required IconData icon,
      required Color color,
      required Function(String) onChanged,
      int maxLines = 1,
    }) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[50],
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            fillColor: Colors.grey[50],
            filled: true,
            prefixIcon: Icon(icon, color: color),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: color,
                width: 2,
              ),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: TextStyle(fontSize: 16, color: Colors.grey[800]),
          maxLines: maxLines,
          onChanged: onChanged,
        ),
      );
    }

// Time marker helper widget
    Widget _timeMarker(String label, Color color, bool isSelected) {
      return Column(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? color : Colors.grey[300],
            ),
          ),
          SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? color : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      );
    }

// Skill development log dialog
    void _showSkillDevelopmentLogDialog() {
      // Initialize variables for the dialog
      String skillName = "";
      String activity = "";
      int durationMinutes = 60; // Default to 1 hour
      String progress = "";
      String challenge = "";

      List<String> suggestionSkills = [
        "Programming",
        "Design",
        "Writing",
        "Language Learning",
        "Data Analysis",
        "Public Speaking",
        "Photography",
        "Music",
        "Drawing",
        "Marketing"
      ];

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (context, setState) {
              final mediaQuery = MediaQuery.of(context);
              final availableHeight = mediaQuery.size.height -
                  mediaQuery.padding.top -
                  mediaQuery.padding.bottom;
              final bottomSheetHeight = availableHeight * 0.9;

              Color primaryColor = _getCategoryColor(task.category);
              Color textColor = Colors.grey[800]!;

              return Container(
                height: bottomSheetHeight,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(25),
                    topRight: Radius.circular(25),
                  ),
                ),
                child: Container(
                  padding: EdgeInsets.all(0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header with gradient background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor.withOpacity(0.7),
                                primaryColor.withOpacity(0.3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                          ),
                          padding: EdgeInsets.fromLTRB(24, 24, 24, 28),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: Icon(
                                  Icons.psychology,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Skill Development",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      "Day ${task.day} • Track your growth",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.close, color: Colors.white),
                                onPressed: () {
                                  Navigator.of(context).pop();
                                },
                              ),
                            ],
                          ),
                        ),

                        // Main content with padding
                        // Main content with padding
                        Container(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Section Title Widget
                              _sectionTitle(Icons.build_circle_outlined,
                                  "Skill Name (If Others)", primaryColor),
                              SizedBox(height: 12),

                              // Enhanced text field with animation and controller
                              AnimatedContainer(
                                duration: Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: Colors.grey[50],
                                  boxShadow: [
                                    BoxShadow(
                                      color: skillName.isEmpty
                                          ? Colors.transparent
                                          : primaryColor.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: TextField(
                                  controller:
                                      _skillTextController, // Added controller for text field
                                  decoration: InputDecoration(
                                    hintText: "Skill you developing?",
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: Colors.grey[300]!),
                                    ),
                                    fillColor: Colors.grey[50],
                                    filled: true,
                                    prefixIcon:
                                        Icon(Icons.build, color: primaryColor),
                                    suffixIcon: skillName.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.clear,
                                                color: Colors.grey[600]),
                                            onPressed: () {
                                              _skillTextController.clear();
                                              setState(() {
                                                skillName = "";
                                              });
                                            },
                                          )
                                        : null,
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 16, horizontal: 16),
                                  ),
                                  style:
                                      TextStyle(fontSize: 16, color: textColor),
                                  onChanged: (value) {
                                    setState(() {
                                      skillName = value;
                                    });
                                  },
                                ),
                              ),

                              // Custom animated indicator for skill selection
                              AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                height: skillName.isEmpty ? 0 : 4,
                                margin: EdgeInsets.only(
                                    top: 8, left: 12, right: 12),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),

                              // Suggested skills chips with improved design
                              SizedBox(height: 16),
                              Text(
                                "Suggested Skills",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 10,
                                children: suggestionSkills.map((skill) {
                                  bool isSelected = skillName == skill;
                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        skillName = skill;
                                        _skillTextController.text =
                                            skill; // Auto-fill text field
                                        // Optional: Show visual feedback that chip was selected
                                        // _showChipSelectionFeedback(skill);
                                      });
                                    },
                                    child: AnimatedContainer(
                                      duration: Duration(milliseconds: 200),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primaryColor
                                            : primaryColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: isSelected
                                            ? [
                                                BoxShadow(
                                                  color: primaryColor
                                                      .withOpacity(0.2),
                                                  blurRadius: 4,
                                                  offset: Offset(0, 2),
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isSelected)
                                            Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                          if (isSelected) SizedBox(width: 6),
                                          Text(
                                            skill,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Colors.white
                                                  : primaryColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),

                              SizedBox(height: 28),

                              // Activity Section
                              _sectionTitle(Icons.lightbulb_outline,
                                  "Today's Activity", primaryColor),
                              SizedBox(height: 12),
                              _enhancedTextField(
                                hintText: "What did you work on today?",
                                icon: Icons.edit_note,
                                color: primaryColor,
                                maxLines: 2,
                                onChanged: (value) {
                                  setState(() {
                                    activity = value;
                                  });
                                },
                              ),

                              SizedBox(height: 28),

                              // Time Spent Section with improved slider
                              _sectionTitle(Icons.timer_outlined, "Time Spent",
                                  primaryColor),
                              SizedBox(height: 16),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 20),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        _timeMarker("15 min", primaryColor,
                                            durationMinutes == 15),
                                        _timeMarker("30 min", primaryColor,
                                            durationMinutes == 30),
                                        _timeMarker("45 min", primaryColor,
                                            durationMinutes == 45),
                                        _timeMarker("1 hour", primaryColor,
                                            durationMinutes == 60),
                                        _timeMarker("1.5 hr", primaryColor,
                                            durationMinutes == 90),
                                        _timeMarker("2 hr", primaryColor,
                                            durationMinutes == 120),
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: primaryColor,
                                        inactiveTrackColor:
                                            primaryColor.withOpacity(0.2),
                                        thumbColor: Colors.white,
                                        thumbShape: RoundSliderThumbShape(
                                          enabledThumbRadius: 12,
                                          elevation: 4,
                                        ),
                                        overlayColor:
                                            primaryColor.withOpacity(0.1),
                                        trackHeight: 6,
                                      ),
                                      child: Slider(
                                        value: durationMinutes.toDouble(),
                                        min: 15,
                                        max: 120,
                                        divisions: 7,
                                        onChanged: (value) {
                                          setState(() {
                                            durationMinutes = value.round();
                                          });
                                        },
                                      ),
                                    ),
                                    SizedBox(height: 10),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(30),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                primaryColor.withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        "$durationMinutes minutes",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 28),

                              // Progress Made
                              _sectionTitle(Icons.trending_up, "Progress Made",
                                  primaryColor),
                              SizedBox(height: 12),
                              _enhancedTextField(
                                hintText: "What did you achieve or learn?",
                                icon: Icons.emoji_events_outlined,
                                color: primaryColor,
                                maxLines: 2,
                                onChanged: (value) {
                                  setState(() {
                                    progress = value;
                                  });
                                },
                              ),

                              SizedBox(height: 28),

                              // Challenges Faced
                              _sectionTitle(Icons.fitness_center_outlined,
                                  "Challenges Faced", primaryColor),
                              SizedBox(height: 12),
                              _enhancedTextField(
                                hintText: "What obstacles did you encounter?",
                                icon: Icons.warning_amber_outlined,
                                color: primaryColor,
                                maxLines: 2,
                                onChanged: (value) {
                                  setState(() {
                                    challenge = value;
                                  });
                                },
                              ),

                              SizedBox(height: 32),

                              // Animated validation indicator
                              AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (skillName.isEmpty || activity.isEmpty)
                                      ? Colors.red[50]
                                      : Colors.green[50],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        (skillName.isEmpty || activity.isEmpty)
                                            ? Colors.red[200]!
                                            : Colors.green[200]!,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: 12),
                                    Icon(
                                      (skillName.isEmpty || activity.isEmpty)
                                          ? Icons.info_outline
                                          : Icons.check_circle_outline,
                                      color: (skillName.isEmpty ||
                                              activity.isEmpty)
                                          ? Colors.red[400]
                                          : Colors.green[600],
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      (skillName.isEmpty || activity.isEmpty)
                                          ? "Skill name and activity are required"
                                          : "Ready to save your progress",
                                      style: TextStyle(
                                        color: (skillName.isEmpty ||
                                                activity.isEmpty)
                                            ? Colors.red[400]
                                            : Colors.green[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 28),

                              // Action button with animation
                              AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                width: double.infinity,
                                height: 60,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: (skillName.isEmpty ||
                                            activity.isEmpty)
                                        ? [Colors.grey[400]!, Colors.grey[500]!]
                                        : [
                                            primaryColor,
                                            primaryColor.withOpacity(0.8)
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: (skillName.isEmpty ||
                                          activity.isEmpty)
                                      ? []
                                      : [
                                          BoxShadow(
                                            color:
                                                primaryColor.withOpacity(0.3),
                                            blurRadius: 10,
                                            offset: Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      // Validate inputs
                                      if (skillName.isEmpty ||
                                          activity.isEmpty) {
                                        // ScaffoldMessenger.of(context)
                                        //     .showSnackBar(
                                        //   SnackBar(
                                        //     content: Row(
                                        //       children: [
                                        //         Icon(Icons.error_outline,
                                        //             color: Colors.white),
                                        //         SizedBox(width: 12),
                                        //         Text(
                                        //           "Please enter skill name and activity",
                                        //           style: TextStyle(
                                        //               color: Colors.white),
                                        //         ),
                                        //       ],
                                        //     ),
                                        //     backgroundColor: Colors.red,
                                        //     behavior: SnackBarBehavior.floating,
                                        //     margin: EdgeInsets.all(16),
                                        //     shape: RoundedRectangleBorder(
                                        //       borderRadius:
                                        //           BorderRadius.circular(10),
                                        //     ),
                                        //   ),
                                        // );
                                        return;
                                      }

                                      // Save the skill development log
                                      _saveSkillDevelopmentLog(
                                          skillName,
                                          activity,
                                          durationMinutes,
                                          progress,
                                          challenge);

                                      Navigator.of(context).pop();

                                      // Show success message
                                      SuccessToast.show(context,
                                          "Skill log saved successfully!");
                                    },
                                    child: Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.save_alt,
                                            color: Colors.white,
                                            size: 22,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            "SAVE SKILL PROGRESS",
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
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
            },
          );
        },
      );
    }

    void _showSkillHistoryDialog(List<Map<String, dynamic>> logs) {
      if (logs.isEmpty) {
        // Show message if no logs exist
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(
        //     content: Text(
        //       "No skill development logs found for this task",
        //       style: TextStyle(color: Colors.white),
        //     ),
        //     backgroundColor: Colors.grey[700],
        //     behavior: SnackBarBehavior.floating,
        //     shape: RoundedRectangleBorder(
        //       borderRadius: BorderRadius.circular(10),
        //     ),
        //   ),
        // );
        ErrorToast.show(
            context, "No skill development logs found for this task");
        return;
      }

      // Group logs by skill name for better organization
      Map<String, List<Map<String, dynamic>>> groupedLogs = {};
      for (var log in logs) {
        String skillName = log['skillName'];
        if (!groupedLogs.containsKey(skillName)) {
          groupedLogs[skillName] = [];
        }
        groupedLogs[skillName]!.add(log);
      }

      // Calculate total time spent on each skill
      Map<String, int> totalTimeBySkill = {};
      groupedLogs.forEach((skill, skillLogs) {
        totalTimeBySkill[skill] = skillLogs.fold(
            0, (sum, log) => sum + (log['durationMinutes'] as int));
      });

      showDialog(
        context: context,
        builder: (BuildContext context) {
          Color primaryColor = _getCategoryColor(task.category);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8),
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.2),
                        child: Icon(
                          Icons.history,
                          color: primaryColor,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Skill Development History",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Day ${task.day} | ${logs.length} logs",
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),

                  Divider(height: 30),

                  // Skills summary section
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Skills Summary",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: groupedLogs.keys.map((skill) {
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: primaryColor.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.build_circle,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    skill,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      "${totalTimeBySkill[skill]} min",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16),

                  Text(
                    "Detailed Activity Logs",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  SizedBox(height: 12),

                  // Log entries (scrollable)
                  Expanded(
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Card(
                          elevation: 1,
                          margin: EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Skill and duration header
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        log['skillName'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                    Spacer(),
                                    Icon(
                                      Icons.timer,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      "${log['durationMinutes']} min",
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12),

                                // Activity
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 16,
                                      color: Colors.amber[700],
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Activity",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          Text(
                                            log['activity'],
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                SizedBox(height: 12),

                                // Progress
                                if (log['progress'].isNotEmpty)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.trending_up,
                                        size: 16,
                                        color: Colors.green[700],
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Progress",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              log['progress'],
                                              style: TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                if (log['progress'].isNotEmpty)
                                  SizedBox(height: 12),

                                // Challenge
                                if (log['challenge'].isNotEmpty)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.fitness_center,
                                        size: 16,
                                        color: Colors.red[700],
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Challenge",
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            Text(
                                              log['challenge'],
                                              style: TextStyle(
                                                fontSize: 14,
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
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 16),

                  // Action button
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.add),
                          label: Text("ADD NEW LOG"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showSkillDevelopmentLogDialog();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

// Main function to handle skill development task interaction
    void _showSkillDevelopmentTaskOptions() {
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Skill Development Task",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                OptionCard(
                  icon: Icons.psychology,
                  color: _getCategoryColor(task.category),
                  title: "Log Skill Progress",
                  description:
                      "Track your skill development activities and progress",
                  onTap: () {
                    Navigator.pop(context);
                    _showSkillDevelopmentLogDialog();
                  },
                ),
                OptionCard(
                  icon: Icons.insights,
                  color: _getCategoryColor(task.category),
                  title: "View Skill History",
                  description:
                      "See your past skill development logs and progress",
                  onTap: () async {
                    Navigator.pop(context);
                    List<Map<String, dynamic>> logs =
                        await _extractSkillDevelopmentLogs(task);
                    _showSkillHistoryDialog(logs);
                  },
                ),
                OptionCard(
                  icon: Icons.tips_and_updates,
                  color: _getCategoryColor(task.category),
                  title: "View Build Skill Tips",
                  description: "Get tips for building skill`",
                  onTap: () {
                    Navigator.pop(context);
                    _showTaskSuggestionDialog(task);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    _showSkillDevelopmentTaskOptions();
  }

  // 7. Track Your Progress
  void _handleDailyProgressTask(Project50Task task) {
    print("Progress Tracking Task ID: " + task.id);

    // Function to save progress log
    void _saveProgressLog(String mood, int rating, String comment) async {
      // Validate inputs
      if (mood.isEmpty || comment.isEmpty) {
        return;
      }

      try {
        // Get current date for the log
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);

        // Create progress log data
        Map<String, dynamic> progressData = {
          'mood': mood,
          'rating': rating,
          'comment': comment,
          'date': today.toIso8601String(),
          'createdAt': DateTime.now().toIso8601String(),
        };

        // Get current task and update its description
        if (task != null && task.id.isNotEmpty) {
          // Clean up old progress log if it exists
          String baseDescription = task.description;
          if (baseDescription.contains("Progress Log:")) {
            baseDescription = baseDescription.split("Progress Log:")[0].trim();
          }

          // Create nicely formatted progress log info
          String progressLogInfo = """

Progress Log:
- Mood: $mood
- Rating: $rating/5
- Comment: $comment
- Recorded on ${DateFormat('MMM dd, yyyy').format(now)}""";

          // Update task description to include progress log info
          String updatedDescription = baseDescription + progressLogInfo;

          // Create updated task object
          Project50Task updatedTask = Project50Task(
            id: task.id,
            title: task.title,
            category: task.category,
            description: updatedDescription,
            time: task.time,
            isCompleted: true, // Mark as completed if progress is recorded
            day: task.day,
            createdAt: task.createdAt,
            updatedAt: DateTime.now(),
            orderTask: task.orderTask,
          );

          // Update task in the database
          await _project50service.updateProject50TaskDetails(
              task.id, updatedTask);

          _showCompletionAnimation();

          print("Progress log saved successfully!");
        }
      } catch (e) {
        print("Error saving progress log: $e");
      }
    }

    // Function to show progress tracking dialog
    void _showProgressTrackingDialog(Project50Task task) async {
      try {
        // Create loading state while data is being fetched
        bool isLoading = true;
        Map<String, dynamic>? progressData;

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return StatefulBuilder(
              builder: (context, setState) {
                final mediaQuery = MediaQuery.of(context);
                final availableHeight = mediaQuery.size.height -
                    mediaQuery.padding.top -
                    mediaQuery.padding.bottom;
                final bottomSheetHeight = availableHeight * 0.9;
                // Get the category color for styling
                Color primaryColor = _getCategoryColor(task.category);

                // Function to load progress data from database
                void loadProgressData() async {
                  try {
                    final tasks = await _project50service.getProject50Tasks();
                    final taskFromDb = tasks.firstWhere(
                      (t) => t.id == task.id,
                      orElse: () =>
                          throw Exception("Task not found in database"),
                    );

                    final description = taskFromDb.description ?? '';

                    // Extract progress data using regex if available
                    RegExp moodRegex = RegExp(r'Mood: (.+)');
                    RegExp ratingRegex = RegExp(r'Rating: (\d+)/5');
                    RegExp commentRegex = RegExp(r'Comment: (.+)');

                    Match? moodMatch = moodRegex.firstMatch(description);
                    Match? ratingMatch = ratingRegex.firstMatch(description);
                    Match? commentMatch = commentRegex.firstMatch(description);

                    String? extractedMood;
                    int extractedRating = 3; // Default value
                    String? extractedComment;

                    if (moodMatch != null) {
                      extractedMood = moodMatch.group(1);
                    }

                    if (ratingMatch != null) {
                      extractedRating = int.parse(ratingMatch.group(1) ?? '3');
                    }

                    if (commentMatch != null) {
                      extractedComment = commentMatch.group(1);
                    }

                    setState(() {
                      progressData = {
                        'mood': extractedMood ?? 'Good',
                        'rating': extractedRating,
                        'comment': extractedComment ?? '',
                        'description':
                            description.split("Progress Log:")[0].trim(),
                      };
                      isLoading = false;
                    });
                  } catch (e) {
                    print("Error loading progress data: $e");
                    setState(() {
                      isLoading = false;
                      progressData = {
                        'mood': 'Good',
                        'rating': 3,
                        'comment': '',
                        'description':
                            task.description ?? 'Track your daily progress',
                      };
                    });
                  }
                }

                // Load data when dialog is first shown
                if (isLoading && progressData == null) {
                  loadProgressData();
                }

                // Define available mood options
                List<String> moodOptions = [
                  'Great',
                  'Good',
                  'Okay',
                  'Tired',
                  'Stressed',
                  'Motivated',
                  'Proud',
                  'Frustrated'
                ];

                return Container(
                  height: bottomSheetHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Container(
                    padding: EdgeInsets.all(20),
                    child: isLoading
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: primaryColor),
                                SizedBox(height: 16),
                                Text("Loading progress details...")
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header with nice progress icon
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.track_changes,
                                      color: primaryColor,
                                      size: 28,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      "Daily Progress Tracker",
                                      style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 15),

                                // Task details container
                                Container(
                                  margin: EdgeInsets.only(bottom: 15),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.task_alt,
                                              color: primaryColor, size: 18),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 6),
                                      Text(
                                        progressData!['description'] ?? '',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today,
                                              size: 14,
                                              color: Colors.grey[600]),
                                          SizedBox(width: 5),
                                          Text(
                                            "Day ${task.day}",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Mood selection
                                Container(
                                  margin: EdgeInsets.only(bottom: 15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "How are you feeling today?",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: moodOptions.map((mood) {
                                          return ChoiceChip(
                                            label: Text(mood),
                                            selected:
                                                progressData!['mood'] == mood,
                                            selectedColor:
                                                primaryColor.withOpacity(0.7),
                                            labelStyle: TextStyle(
                                              color:
                                                  progressData!['mood'] == mood
                                                      ? Colors.white
                                                      : Colors.black,
                                            ),
                                            onSelected: (selected) {
                                              if (selected) {
                                                setState(() {
                                                  progressData!['mood'] = mood;
                                                });
                                              }
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),

                                // Overall day rating
                                Container(
                                  margin: EdgeInsets.only(bottom: 15),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Rate your day (1-5):",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: List.generate(5, (index) {
                                          return GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                progressData!['rating'] =
                                                    index + 1;
                                              });
                                            },
                                            child: Container(
                                              padding: EdgeInsets.all(12),
                                              child: Icon(
                                                index < progressData!['rating']
                                                    ? Icons.star
                                                    : Icons.star_border,
                                                color: index <
                                                        progressData!['rating']
                                                    ? Colors.amber
                                                    : Colors.grey,
                                                size: 32,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  ),
                                ),

                                // Daily reflection input
                                Container(
                                  margin: EdgeInsets.only(bottom: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Daily Reflection:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      TextFormField(
                                        initialValue: progressData!['comment'],
                                        maxLines: 5,
                                        decoration: InputDecoration(
                                          hintText:
                                              "Share your thoughts on today's progress...",
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide:
                                                BorderSide(color: Colors.grey),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                                color: primaryColor, width: 2),
                                          ),
                                        ),
                                        onChanged: (value) {
                                          progressData!['comment'] = value;
                                        },
                                      ),
                                    ],
                                  ),
                                ),

                                // Helpful prompts
                                Container(
                                  margin: EdgeInsets.only(bottom: 15),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.grey[300]!, width: 1),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Reflection Prompts:",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        "• What went well today?\n• What challenged you most?\n• What are you grateful for?\n• How can you improve tomorrow?",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Bottom buttons
                                Row(
                                  children: [
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.grey[200],
                                          foregroundColor: Colors.black87,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                        ),
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Text("CANCEL"),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(30),
                                          ),
                                        ),
                                        onPressed: () {
                                          // Validate and save the progress data
                                          if (progressData!['comment']
                                              .toString()
                                              .trim()
                                              .isEmpty) {
                                            ErrorToast.show(context,
                                                "Please add a reflection comment");
                                            return;
                                          }

                                          // Save the progress log
                                          _saveProgressLog(
                                            progressData!['mood'],
                                            progressData!['rating'],
                                            progressData!['comment'],
                                          );

                                          // Close dialog and refresh
                                          Navigator.of(context).pop();
                                          // Optionally refresh UI
                                          _loadProject50Data();
                                        },
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              vertical: 12),
                                          child: Text("SAVE"),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                );
              },
            );
          },
        );
      } catch (e) {
        print("Error showing progress tracking dialog: $e");
      }
    }

    // Helper function to get color based on mood
    Color _getMoodColor(String mood) {
      switch (mood.toLowerCase()) {
        case 'great':
          return Colors.green[600]!;
        case 'good':
          return Colors.teal[500]!;
        case 'okay':
          return Colors.blue[500]!;
        case 'tired':
          return Colors.orange[500]!;
        case 'stressed':
          return Colors.red[500]!;
        case 'motivated':
          return Colors.purple[500]!;
        case 'proud':
          return Colors.indigo[500]!;
        case 'frustrated':
          return Colors.deepOrange[500]!;
        default:
          return Colors.grey[600]!;
      }
    }

    // Function to show progress summary
    void _showProgressSummary(Project50Task task) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: EdgeInsets.all(20),
                child: FutureBuilder<List<Project50Task>>(
                  future: _project50service.getProject50TasksByDay(task.day),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator());
                    }

                    List<Project50Task> dayTasks = snapshot.data!;
                    int completedTasks =
                        dayTasks.where((t) => t.isCompleted).length;
                    double completionRate =
                        (completedTasks / dayTasks.length) * 100;

                    // Load progress data from the task
                    Map<String, dynamic>? progressData;
                    try {
                      final description = task.description ?? '';

                      // Extract progress data using regex
                      RegExp moodRegex = RegExp(r'Mood: (.+)');
                      RegExp ratingRegex = RegExp(r'Rating: (\d+)/5');
                      RegExp commentRegex = RegExp(r'Comment: (.+)');
                      RegExp dateRegex = RegExp(r'Recorded on (.+)');

                      Match? moodMatch = moodRegex.firstMatch(description);
                      Match? ratingMatch = ratingRegex.firstMatch(description);
                      Match? commentMatch =
                          commentRegex.firstMatch(description);
                      Match? dateMatch = dateRegex.firstMatch(description);

                      if (description.contains("Progress Log:")) {
                        progressData = {
                          'mood': moodMatch?.group(1) ?? 'Not recorded',
                          'rating':
                              int.tryParse(ratingMatch?.group(1) ?? '0') ?? 0,
                          'comment':
                              commentMatch?.group(1) ?? 'No comment recorded',
                          'date': dateMatch?.group(1) ?? '',
                          'hasProgressData': true,
                        };
                      } else {
                        progressData = {
                          'hasProgressData': false,
                        };
                      }
                    } catch (e) {
                      print("Error parsing progress data: $e");
                      progressData = {
                        'hasProgressData': false,
                      };
                    }

                    return ListView(
                      controller: scrollController,
                      children: [
                        // Header
                        Center(
                          child: Text(
                            "Day ${task.day} Summary",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _getCategoryColor(task.category),
                            ),
                          ),
                        ),
                        SizedBox(height: 5),
                        Center(
                          child: Text(
                            "Project 50 Challenge",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        Divider(height: 30),

                        // Progress Ring
                        Container(
                          height: 180,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                height: 160,
                                width: 160,
                                child: CircularProgressIndicator(
                                  value: completionRate / 100,
                                  strokeWidth: 15,
                                  backgroundColor: Colors.grey[300],
                                  color: _getCategoryColor(task.category),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "${completionRate.toStringAsFixed(0)}%",
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: _getCategoryColor(task.category),
                                    ),
                                  ),
                                  Text(
                                    "$completedTasks of ${dayTasks.length}",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Progress Data Section (New)
                        if (progressData != null &&
                            progressData['hasProgressData'] == true)
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _getCategoryColor(task.category)
                                      .withOpacity(0.1),
                                  Colors.white,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _getCategoryColor(task.category)
                                    .withOpacity(0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with date
                                Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _getCategoryColor(task.category)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(15),
                                      topRight: Radius.circular(15),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.psychology,
                                        color: _getCategoryColor(task.category),
                                        size: 24,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        "Daily Reflection",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color:
                                              _getCategoryColor(task.category),
                                        ),
                                      ),
                                      Spacer(),
                                      if (progressData['date'].isNotEmpty)
                                        Text(
                                          progressData['date'],
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                // Mood and rating
                                Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Mood indicator
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                "Mood",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _getMoodColor(
                                                      progressData['mood']),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  progressData['mood'],
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      SizedBox(width: 12),

                                      // Rating indicator
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                              color: Colors.grey[300]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Text(
                                                "Day Rating",
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                              SizedBox(height: 8),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children:
                                                    List.generate(5, (index) {
                                                  return Icon(
                                                    index <
                                                            progressData?[
                                                                'rating']
                                                        ? Icons.star
                                                        : Icons.star_border,
                                                    color: index <
                                                            progressData?[
                                                                'rating']
                                                        ? Colors.amber
                                                        : Colors.grey[400],
                                                    size: 20,
                                                  );
                                                }),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Comment/reflection
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Reflection:",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Container(
                                        padding: EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[50],
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          progressData['comment'],
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: Colors.grey[800],
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: 16),
                              ],
                            ),
                          )
                        else
                          Container(
                            margin: EdgeInsets.symmetric(vertical: 20),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.grey[300]!, width: 1),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.edit_note,
                                  size: 42,
                                  color: Colors.grey[500],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "No Reflection Recorded",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "Track your progress by adding a daily reflection",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _showProgressTrackingDialog(task);
                                  },
                                  child: Text("Add Reflection"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        _getCategoryColor(task.category),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Tasks Breakdown
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 15),
                          child: Text(
                            "Daily Tasks",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        // List of all day's tasks
                        ...dayTasks.map((dayTask) {
                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: dayTask.isCompleted
                                    ? Colors.green.withOpacity(0.3)
                                    : Colors.grey.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: ListTile(
                              leading: Icon(
                                dayTask.isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: dayTask.isCompleted
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              title: Text(
                                dayTask.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  decoration: dayTask.isCompleted
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                  color: dayTask.isCompleted
                                      ? Colors.grey[600]
                                      : Colors.black,
                                ),
                              ),
                              subtitle: Text(
                                dayTask.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _getCategoryColor(dayTask.category)
                                      .withOpacity(0.8),
                                ),
                              ),
                            ),
                          );
                        }).toList(),

                        SizedBox(height: 20),

                        // Motivational message
                        Container(
                          padding: EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _getCategoryColor(task.category)
                                    .withOpacity(0.7),
                                _getCategoryColor(task.category)
                                    .withOpacity(0.3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                completionRate > 80
                                    ? Icons.emoji_events
                                    : (completionRate > 50
                                        ? Icons.thumb_up
                                        : Icons.directions_run),
                                color: Colors.white,
                                size: 32,
                              ),
                              SizedBox(height: 10),
                              Text(
                                completionRate > 80
                                    ? "Amazing job today!"
                                    : (completionRate > 50
                                        ? "Good progress! Keep it up."
                                        : "Don't give up! Tomorrow is a new day."),
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 30),

                        // Close button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[200],
                            foregroundColor: Colors.black87,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text("CLOSE"),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          );
        },
      );
    }

    // Main function to handle progress tracking task interaction
    void _showProgressTrackingOptions() {
      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (BuildContext context) {
          return Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Track Your Progress",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                OptionCard(
                  icon: Icons.edit_note,
                  color: _getCategoryColor(task.category),
                  title: "Log Daily Progress",
                  description:
                      "Record your emotions and reflections for the day",
                  onTap: () {
                    Navigator.pop(context);
                    _showProgressTrackingDialog(task);
                  },
                ),
                OptionCard(
                  icon: Icons.bar_chart,
                  color: _getCategoryColor(task.category),
                  title: "View Day Summary",
                  description: "See your overall progress for today",
                  onTap: () {
                    Navigator.pop(context);
                    _showProgressSummary(task);
                  },
                ),
                OptionCard(
                  icon: Icons.tips_and_updates,
                  color: _getCategoryColor(task.category),
                  title: "Tips Daily Progress",
                  description: "Track your progress effectively",
                  onTap: () {
                    Navigator.pop(context);
                    _showTaskSuggestionDialog(task);
                  },
                ),
              ],
            ),
          );
        },
      );
    }

    // Entry point - call this when user interacts with progress tracking task
    _showProgressTrackingOptions();
  }

// Helper methods to support the enhanced UI

  Widget _getDayStatusIndicator() {
    if (!_tasksByDay.containsKey(_selectedDay)) {
      return SizedBox.shrink();
    }

    bool allCompleted =
        _tasksByDay[_selectedDay]!.every((task) => task.isCompleted);
    int completedCount =
        _tasksByDay[_selectedDay]!.where((task) => task.isCompleted).length;
    int totalCount = _tasksByDay[_selectedDay]!.length;

    print(completedCount);

    if (allCompleted) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'Complete',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (completedCount > 0 || completedCount < 7) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.hourglass_top, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'In Progress',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else if (completedCount == 7) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'Completed',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_arrow, color: Colors.white, size: 14),
            SizedBox(width: 4),
            Text(
              'Not Started',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
  }

  Color _getDayProgressColor() {
    if (!_tasksByDay.containsKey(_currentDay)) {
      return Colors.grey;
    }

    int completedCount =
        _tasksByDay[_currentDay]!.where((task) => task.isCompleted).length;
    int totalCount = _tasksByDay[_currentDay]!.length;
    double progress = completedCount / totalCount;

    if (progress >= 1.0) {
      return Colors.green;
    } else if (progress >= 0.5) {
      return Colors.orange;
    } else {
      return Theme.of(context).primaryColor;
    }
  }

  Widget _buildCategorySummary() {
    // Group tasks by category
    Map<String, int> tasksByCategory = {};
    Map<String, int> completedByCategory = {};

    for (var task in _tasksByDay[_selectedDay] ?? []) {
      if (!tasksByCategory.containsKey(task.category)) {
        tasksByCategory[task.category] = 0;
        completedByCategory[task.category] = 0;
      }

      tasksByCategory[task.category] = tasksByCategory[task.category]! + 1;
      if (task.isCompleted) {
        completedByCategory[task.category] =
            completedByCategory[task.category]! + 1;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: tasksByCategory.entries.map((entry) {
        return Column(
          children: [
            CircularPercentIndicator(
              radius: 20.0,
              lineWidth: 4.0,
              percent: completedByCategory[entry.key]! / entry.value,
              center: Icon(
                _getCategoryIcon(entry.key),
                size: 16,
                color: _getCategoryColor(entry.key),
              ),
              progressColor: _getCategoryColor(entry.key),
              backgroundColor: Colors.grey[200]!,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            SizedBox(height: 4),
            Text(
              entry.key,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '${completedByCategory[entry.key]!}/${entry.value}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

// Helper method to find the first incomplete day
  int _findFirstIncompleteDay() {
    for (int i = 1; i <= 50; i++) {
      if (_tasksByDay.containsKey(i)) {
        bool allCompleted = _tasksByDay[i]!.every((task) => task.isCompleted);
        if (!allCompleted) {
          return i;
        }
      } else if (i > 1) {
        // If we don't have data for this day and we've passed day 1,
        // we'll assume this is the next day to tackle
        return i;
      }
    }
    return 1; // Default to day 1 if all are complete or no data
  }

  Widget OptionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Morning':
        return Icons.wb_sunny;
      case 'Health':
        return Icons.fitness_center;
      case 'Learning':
        return Icons.book;
      case 'Growth':
        return Icons.trending_up;
      case 'Accountability':
        return Icons.check_circle;
      default:
        return Icons.star;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }
}

class StringBuilder {
  final List<String> _parts = [];

  void write(String part) {
    _parts.add(part);
  }

  @override
  String toString() {
    return _parts.join();
  }
}
