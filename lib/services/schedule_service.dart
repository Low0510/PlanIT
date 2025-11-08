import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/models/subtask.dart';
import 'package:planit_schedule_manager/models/task_file.dart';
import 'package:planit_schedule_manager/services/file_upload_service.dart';
import 'package:planit_schedule_manager/services/notification_service.dart';
import 'package:uuid/uuid.dart';
import 'package:string_similarity/string_similarity.dart';

// 1. Create Schedules
// 2. Delete Schedules
// 3. Update Schedules
// 4. Get Schedules
// 5. Subtask Management

class ScheduleService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FileUploadService _fileUploadService = FileUploadService();

  ScheduleService() {
    _firestore.settings = Settings(persistenceEnabled: true);
  }

  // ------------------------------ 1. Create Schedules Part ------------------------------

  // ------------------------------ Create Schedules ------------------------------
  // Add Schedule
  Future<void> addSchedule({
    required String title,
    required String category,
    required String url,
    required String placeURL,
    required DateTime time,
    required List<String> subtasks,
    required String priority,
    required bool isRepeated,
    required String repeatInterval,
    required int repeatedIntervalTime,
    List<File?> files = const [],
    String? emotion,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Create a temporary task ID for file uploads
    String tempTaskId = const Uuid().v4();

    // Upload files if provided
    List<TaskFile> uploadedFiles = [];
    if (files != null && files.isNotEmpty) {
      // Filter out null values from the files list
      List<File> nonNullFiles = files.whereType<File>().toList();
      uploadedFiles =
          await _fileUploadService.uploadFiles(nonNullFiles, tempTaskId);
    }

    // Convert simple subtask strings to Subtask objects with guaranteed unique IDs
    List<SubTask> subtasksList = subtasks.asMap().entries.map((entry) {
      int index = entry.key;
      String title = entry.value;
      
      // Generate unique ID using UUID for each subtask
      String uniqueId = const Uuid().v4();
      
      
      return SubTask(
        id: uniqueId,
        title: title,
      );
    }).toList();

    // If the task is set to repeat, generate multiple task instances
    if (isRepeated) {
      print('isRepeated');
      await _createRepeatedTasks(
        user: user,
        title: title,
        category: category,
        url: url,
        placeURL: placeURL,
        initialTime: time,
        subtasks: subtasksList,
        priority: priority,
        repeatInterval: repeatInterval,
        repeatedIntervalTime: repeatedIntervalTime,
        files: uploadedFiles,
        emotion: emotion,
      );
    } else {
      // Create a single non-repeated task
      print('None repeated');
      int? notificationId;

      Duration notificationOffset = _calculateNotificationOffset(priority);
      DateTime notificationTime = time.subtract(notificationOffset);

      // Ensure the difference is positive
      if (notificationTime.isAfter(DateTime.now())) {
        try {
          // Store the returned notificationId
          notificationId = await NotificationService.showScheduledNotification(
            'Task Reminder',
            title,
            notificationTime,
            priority,
          );
          print(
              "Reminder scheduled for: $notificationTime with ID: $notificationId");
        } catch (e) {
          print("Failed to schedule notification: $e");
        }
      } else {
        print("Notification time is in the past, not scheduling");
      }
      
      await _createSingleTask(
        user: user,
        title: title,
        category: category,
        url: url,
        placeURL: placeURL,
        time: time,
        subtasks: subtasksList,
        priority: priority,
        files: uploadedFiles,
        notificationId: notificationId,
        emotion: emotion,
      );
    }
  }

  Duration _calculateNotificationOffset(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return const Duration(minutes: 15);
      case 'medium':
        return const Duration(minutes: 10);
      case 'low':
        return const Duration(minutes: 5);
      case 'none':
      default:
        return Duration.zero; // No advance notification
    }
  }

  Future<void> _createRepeatedTasks({
    required User user,
    required String title,
    required String category,
    required String url,
    required String placeURL,
    required DateTime initialTime,
    required List<SubTask> subtasks,
    required String priority,
    required String
        repeatInterval, // e.g., "Daily", "Weekly,1,3,5" (1=Mon, 7=Sun)
    required int repeatedIntervalTime, // Number of occurrences or weeks
    required List<TaskFile> files,
    String? emotion,
  }) async {
    List<int> weekdays = []; // For "Weekly,1,3,5" type intervals
    if (repeatInterval.toLowerCase().startsWith('weekly,')) {
      try {
        weekdays = repeatInterval.split(',').skip(1).map(int.parse).toList();
        if (weekdays.any((d) => d < 1 || d > 7)) {
          print(
              "Warning: Invalid weekday numbers in repeatInterval. Falling back to simple weekly.");
          weekdays = []; // Invalidate if days are out of 1-7 range
        }
      } catch (e) {
        print(
            "Error parsing weekdays from repeatInterval: $e. Falling back to simple weekly.");
        weekdays = [];
      }
    }

    final String groupID =
        const Uuid().v4(); // Unique ID for this entire series of tasks
    final WriteBatch batch = _firestore.batch();
    final CollectionReference scheduleCollection =
        _firestore.collection('users').doc(user.uid).collection('schedules');

    // Helper for weekday names (1=Monday, ..., 7=Sunday)
    String getWeekdayName(int day) {
      const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      if (day >= 1 && day <= 7) return names[day - 1];
      return "Day $day";
    }

    if (weekdays.isNotEmpty) {
      // Case: Specific weekdays selected (e.g., "Weekly,1,3,5" for Mon, Wed, Fri)
      // repeatedIntervalTime here means number of weeks to repeat for
      int totalOccurrences = repeatedIntervalTime * weekdays.length;
      int currentOccurrenceNum = 0;

      for (int week = 0; week < repeatedIntervalTime; week++) {
        for (int targetWeekday in weekdays) {
          currentOccurrenceNum++;
          // Calculate the specific date for this weekday in the current week iteration
          DateTime taskTime = _findNextWeekday(initialTime, targetWeekday)
              .add(Duration(days: 7 * week));

          // --- Notification Scheduling ---
          int? notificationIdForThisInstance;
          Duration notificationOffset = _calculateNotificationOffset(priority);
          DateTime notificationScheduledAt =
              taskTime.subtract(notificationOffset);

          String notificationBody = "$title (${getWeekdayName(targetWeekday)})";
          if (repeatedIntervalTime > 1 || weekdays.length > 1) {
            // If it's part of a larger series
            notificationBody =
                "$title (${getWeekdayName(targetWeekday)}, Week ${week + 1}) - ${currentOccurrenceNum}/${totalOccurrences}";
          }

          if (notificationScheduledAt.isAfter(DateTime.now())) {
            try {
              notificationIdForThisInstance =
                  await NotificationService.showScheduledNotification(
                      'Task Reminder',
                      notificationBody,
                      notificationScheduledAt,
                      priority);
              print(
                  "Repeated task (weekday specific) instance notification scheduled for $taskTime with ID: $notificationIdForThisInstance");
            } catch (e) {
              print(
                  "Failed to schedule notification for repeated task (weekday specific) at $taskTime: $e");
            }
          } else {
            print(
                "Notification time for repeated task (weekday specific) at $taskTime is in the past, not scheduling.");
          }
          // --- End Notification Scheduling ---

          final DocumentReference docRef =
              scheduleCollection.doc(); // Auto-generate ID for this instance
          Map<String, dynamic> taskData = {
            'id': docRef.id, // Store the instance's own document ID
            'title': title,
            'time': Timestamp.fromDate(taskTime),
            'category': category,
            'url': url,
            'placeURL': placeURL,
            'createdAt': FieldValue
                .serverTimestamp(), // Use server timestamp for consistency
            'subtasks':
                subtasks.map((s) => {'id': s.id, 'title': s.title, }).toList(),
            'priority': priority,
            'isRepeated': true,
            'repeatInterval': repeatInterval,
            'repeatedIntervalTime': repeatedIntervalTime, // Original config
            'groupID': groupID,
            'files': files.map((f) => f.toMap()).toList(),
            'done': false,
            if (emotion != null) 'emotion': emotion,
          };
          if (notificationIdForThisInstance != null) {
            taskData['notificationId'] = notificationIdForThisInstance;
          }
          batch.set(docRef, taskData);
        }
      }
    } else {
      // Case: Daily, simple Weekly (every X weeks), Monthly, Yearly
      // repeatedIntervalTime here means number of occurrences
      DateTime currentTaskTime = initialTime; // Start with the initial time

      for (int i = 0; i < repeatedIntervalTime; i++) {
        if (i > 0) {
          // For the second occurrence onwards, increment the time
          currentTaskTime = _incrementTime(currentTaskTime, repeatInterval);
        }
        // For i == 0, currentTaskTime is initialTime

        // --- Notification Scheduling ---
        int? notificationIdForThisInstance;
        Duration notificationOffset = _calculateNotificationOffset(priority);
        DateTime notificationScheduledAt =
            currentTaskTime.subtract(notificationOffset);

        String notificationBody = title;
        if (repeatedIntervalTime > 1) {
          notificationBody =
              "$title (Occurrence ${i + 1}/${repeatedIntervalTime})";
        }

        if (notificationScheduledAt.isAfter(DateTime.now())) {
          try {
            notificationIdForThisInstance =
                await NotificationService.showScheduledNotification(
              'Task Reminder',
              notificationBody,
              notificationScheduledAt,
              priority,
            );
            print(
                "Repeated task instance ${i + 1} notification scheduled for $currentTaskTime with ID: $notificationIdForThisInstance");
          } catch (e) {
            print(
                "Failed to schedule notification for repeated task instance ${i + 1} at $currentTaskTime: $e");
          }
        } else {
          print(
              "Notification time for repeated task instance ${i + 1} at $currentTaskTime is in the past, not scheduling.");
        }
        // --- End Notification Scheduling ---

        final DocumentReference docRef =
            scheduleCollection.doc(); // Auto-generate ID
        Map<String, dynamic> taskData = {
          'id': docRef.id, // Store the instance's own document ID
          'title': title,
          'time': Timestamp.fromDate(
              currentTaskTime), // Use the calculated time for THIS instance
          'category': category,
          'url': url,
          'placeURL': placeURL,
          'createdAt': FieldValue.serverTimestamp(),
          'subtasks':
              subtasks.map((s) => {'id': s.id, 'title': s.title}).toList(),
          'priority': priority,
          'isRepeated': true,
          'repeatInterval':
              repeatInterval, // Original config (e.g. "Daily", "Weekly")
          'repeatedIntervalTime':
              repeatedIntervalTime, // Original config (number of occurrences)
          'groupID': groupID,
          'files': files.map((f) => f.toMap()).toList(),
          'done': false,
          if (emotion != null) 'emotion': emotion,
        };
        if (notificationIdForThisInstance != null) {
          taskData['notificationId'] = notificationIdForThisInstance;
        }
        batch.set(docRef, taskData);
      }
    }
    await batch.commit();
    print("Batch committed for repeated tasks with groupID: $groupID");
  }

  // Helper function to find the next occurrence of a specific weekday
  DateTime _findNextWeekday(DateTime start, int targetWeekday) {
    int daysToAdd = (targetWeekday - start.weekday + 7) % 7;
    return start.add(Duration(days: daysToAdd));
  }

  // Time increment function to handle edge cases
  DateTime _incrementTime(DateTime currentTime, String repeatInterval) {
    switch (repeatInterval) {
      case 'Daily':
        return currentTime.add(Duration(days: 1));

      case 'Weekly':
        return currentTime.add(Duration(days: 7));

      case 'Monthly':
        // Calculate the next month
        int year = currentTime.year;
        int month = currentTime.month + 1;
        if (month > 12) {
          month = 1;
          year++;
        }

        // Handle month length differences
        int day = currentTime.day;
        int lastDayOfMonth = DateTime(year, month + 1, 0).day;
        if (day > lastDayOfMonth) {
          day = lastDayOfMonth;
        }

        return DateTime(
          year,
          month,
          day,
          currentTime.hour,
          currentTime.minute,
          currentTime.second,
        );

      case 'Yearly':
        // Calculate the next year
        int year = currentTime.year + 1;
        int month = currentTime.month;
        int day = currentTime.day;

        // Handle February 29 in leap years
        if (month == 2 && day == 29 && !_isLeapYear(year)) {
          day = 28;
        }

        return DateTime(
          year,
          month,
          day,
          currentTime.hour,
          currentTime.minute,
          currentTime.second,
        );

      default:
        return currentTime;
    }
  }

// Helper to check if a year is a leap year
  bool _isLeapYear(int year) {
    return (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0));
  }

  Future<void> _createSingleTask({
    required User user,
    required String title,
    required String category,
    required String url,
    required String placeURL,
    required DateTime time,
    required List<SubTask> subtasks,
    required String priority,
    required List<TaskFile> files,
    int? notificationId,
    String? emotion,
  }) async {
    String taskId = const Uuid().v4(); // Or however you generate task IDs

    Map<String, dynamic> taskData = {
      'id': taskId,
      'title': title,
      'category': category,
      'url': url,
      'placeURL': placeURL,
      'time': Timestamp.fromDate(time),
      'subtasks': subtasks
          .map((s) => s.toMap())
          .toList(), // Assuming SubTask has a toMap()
      'priority': priority,
      'isRepeated': false, // For single task
      'files': files
          .map((f) => f.toMap())
          .toList(), // Assuming TaskFile has a toMap()
      'createdAt': FieldValue.serverTimestamp(),
      if (notificationId != null) 'notificationId': notificationId,
      'done': false,
      if (emotion != null) 'emotion': emotion,
    };

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .doc(taskId) // Use the generated taskId
        .set(taskData);
    print(
        "Single task created with ID: $taskId and Notification ID: $notificationId");
  }

  Future<void> addSchedulesBatch(List<Map<String, dynamic>> schedules) async {
    User? user = FirebaseAuth.instance.currentUser;
    final batch = _firestore.batch();
    final userRef =
        _firestore.collection('users').doc(user?.uid).collection('schedules');
    for (var schedule in schedules) {
      final ref = userRef.doc();
      batch.set(ref, {
        'title': schedule['title'],
        'category': schedule['category'],
        'url': schedule['url'],
        'placeURL': schedule['placeURL'],
        'time': Timestamp.fromDate(schedule['time']),
        'subtasks':
            (schedule['subtasks'] as List).map((e) => e.toMap()).toList(),
        'priority': schedule['priority'],
        'isRepeated': schedule['isRepeated'],
        'repeatInterval': schedule['repeatInterval'],
        'repeatedIntervalTime': schedule['repeatedIntervalTime'] != null
            ? Timestamp.fromDate(schedule['repeatedIntervalTime'])
            : null,
        'done': false,
        'createdAt':
            Timestamp.now(), // Adding creation timestamp for consistency
      });
    }
    await batch.commit();
  }

  // ------------------------------ Delete Schedules ------------------------------

  Future<void> deleteSchedule(String taskId) async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      DocumentReference taskRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(taskId);

      DocumentSnapshot taskDoc = await taskRef.get();

      if (taskDoc.exists) {
        Map<String, dynamic> taskData = taskDoc.data() as Map<String, dynamic>;

        // Check if the task has files and delete them
        if (taskData.containsKey('files') && taskData['files'] is List) {
          List<dynamic> filesData = taskData['files'];
          for (var fileEntry in filesData) {
            if (fileEntry is Map<String, dynamic>) {
              // Assuming TaskFile.fromMap or similar exists if you need the object
              // For deletion, only the URL is essential if your deleteFile takes a URL
              String? fileUrl = fileEntry['url'] as String?;
              if (fileUrl != null) {
                try {
                  await _fileUploadService.deleteFile(fileUrl);
                  print("Deleted file: $fileUrl");
                } catch (e) {
                  print("Error deleting file $fileUrl: $e");
                  // Decide if this error should stop the whole process or just be logged
                }
              }
            }
          }
        }

        // Retrieve and cancel the notification
        if (taskData.containsKey('notificationId')) {
          int? notificationId =
              taskData['notificationId'] as int?; // Use as int? for safety
          if (notificationId != null) {
            try {
              await NotificationService.cancelNotification(notificationId);
            } catch (e) {
              print("Error cancelling notification $notificationId: $e");
              // Log error, but don't necessarily stop task deletion
            }
          }
        } else {
          print("Not notification ID");
        }
      } else {
        print("Task document with ID $taskId not found.");
        // Optionally throw an error or return if task not found
        // throw Exception('Task not found');
      }

      // Finally, delete the task document
      await taskRef.delete();
      print("Deleted task with ID: $taskId");
    } catch (e) {
      // It's good practice to rethrow with more specific context or handle
      print('Failed to delete schedule: $e');
      throw Exception('Failed to delete schedule: $e');
    }
  }

  Future<void> deleteRepeatedTasks(String groupId) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('groupID', isEqualTo: groupId)
          .get();

      if (querySnapshot.docs.isEmpty) {
        print("No tasks found with groupID: $groupId");
        return;
      }

      final WriteBatch batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        Map<String, dynamic> taskData = doc.data() as Map<String, dynamic>;

        // 1. Cancel Notification
        if (taskData.containsKey('notificationId')) {
          int? notificationId = taskData['notificationId'] as int?;
          if (notificationId != null) {
            try {
              await NotificationService.cancelNotification(notificationId);
              print(
                  "Cancelled notification $notificationId for task ${doc.id}");
            } catch (e) {
              print(
                  "Error cancelling notification $notificationId for task ${doc.id}: $e");
              // Decide if you want to stop or continue
            }
          }
        }

        // 2. Delete Associated Files
        if (taskData.containsKey('files') && taskData['files'] is List) {
          List<dynamic> filesData = taskData['files'];
          for (var fileEntry in filesData) {
            if (fileEntry is Map<String, dynamic>) {
              String? fileUrl = fileEntry['url'] as String?;
              if (fileUrl != null) {
                try {
                  await _fileUploadService.deleteFile(fileUrl);
                  print("Deleted file $fileUrl for task ${doc.id}");
                } catch (e) {
                  print("Error deleting file $fileUrl for task ${doc.id}: $e");
                  // Decide if you want to stop or continue
                }
              }
            }
          }
        }
        // 3. Add document deletion to batch
        batch.delete(doc.reference);
      }

      await batch.commit();
      print(
          "Successfully deleted tasks, notifications, and files for groupID: $groupId");
    } catch (e) {
      print('Failed to delete repeated tasks for groupID $groupId: $e');
      throw Exception('Failed to delete repeated tasks: $e');
    }
  }

  // ------------------------------ 2. Update Schedules Part ------------------------------

  // ------------------------------ Update Schedules ------------------------------

  Future<void> updateSchedule({
    required String id,
    required String title,
    required String category,
    required String url,
    required String placeURL,
    required DateTime time,
    required String priority,
    required bool isRepeated,
    required String repeatInterval,
    required int repeatedIntervalTime,
    required List<SubTask> subtasks,
    required List<TaskFile> files,
    String? emotion,
  }) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    final taskRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .doc(id);

    final existingTask = await taskRef.get();
    if (!existingTask.exists) {
      throw Exception('Task not found');
    }

    final oldTask = Task.fromMap(id, existingTask.data()!);

    // **STEP 1: Cancel existing notifications**
    await _cancelExistingNotifications(oldTask);

    // **STEP 2: Handle different update scenarios**
    if (isRepeated &&
        (!oldTask.isRepeated ||
            oldTask.repeatInterval != repeatInterval ||
            oldTask.repeatedIntervalTime != repeatedIntervalTime ||
            oldTask.time != time)) {
      // Converting to repeated OR changing repeat settings

      // Delete existing task(s)
      if (oldTask.isRepeated && oldTask.groupID != null) {
        await deleteRepeatedTasks(oldTask.groupID!);
      } else {
        await taskRef.delete();
      }

      // Create new repeated tasks with notifications
      await _createRepeatedTasks(
        user: user,
        title: title,
        category: category,
        url: url,
        placeURL: placeURL,
        initialTime: time,
        subtasks: subtasks,
        priority: priority,
        repeatInterval: repeatInterval,
        repeatedIntervalTime: repeatedIntervalTime,
        files: files,
        emotion: emotion,
      );
    } else if (!isRepeated && oldTask.isRepeated) {
      // Converting from repeated to single task

      // Delete all related repeated tasks
      if (oldTask.groupID != null) {
        await deleteRepeatedTasks(oldTask.groupID!);
      }

      // Create new single task with notification
      await _createSingleTask(
        user: user,
        title: title,
        category: category,
        url: url,
        placeURL: placeURL,
        time: time,
        subtasks: subtasks,
        priority: priority,
        files: files,
        emotion: emotion,
      );
    } else {
      // **STEP 3: Simple update - schedule new notification**
      int? newNotificationId;

      // Only schedule notification if it's a single task (not repeated)
      if (!isRepeated) {
        Duration notificationOffset = _calculateNotificationOffset(priority);
        DateTime notificationTime = time.subtract(notificationOffset);

        if (notificationTime.isAfter(DateTime.now())) {
          try {
            newNotificationId =
                await NotificationService.showScheduledNotification(
              'Task Reminder',
              title,
              notificationTime,
              priority,
            );
            print(
                "Updated task notification scheduled for: $notificationTime with ID: $newNotificationId");
          } catch (e) {
            print("Failed to schedule updated notification: $e");
          }
        } else {
          print("Updated notification time is in the past, not scheduling");
        }
      }

      // Update the task document
      Map<String, dynamic> updateData = {
        'title': title,
        'category': category,
        'url': url,
        'placeURL': placeURL,
        'time': Timestamp.fromDate(time),
        'priority': priority,
        'isRepeated': isRepeated,
        'repeatInterval': repeatInterval,
        'repeatedIntervalTime': repeatedIntervalTime,
        'subtasks': subtasks.map((s) => s.toMap()).toList(),
        'files': files.map((f) => f.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add notification ID if scheduled
      if (newNotificationId != null) {
        updateData['notificationId'] = newNotificationId;
      } else {
        // Remove notification ID if no notification was scheduled
        updateData['notificationId'] = FieldValue.delete();
      }

      // Add emotion if provided
      if (emotion != null) {
        updateData['emotion'] = emotion;
      }

      await taskRef.update(updateData);
      print(
          "Task updated with ID: $id and new notification ID: $newNotificationId");
    }
  }

// **Helper function to cancel existing notifications**
  Future<void> _cancelExistingNotifications(Task oldTask) async {
    try {
      if (oldTask.isRepeated && oldTask.groupID != null) {
        // Cancel notifications for all tasks in the group
        User? user = _auth.currentUser;
        if (user != null) {
          final groupTasks = await _firestore
              .collection('users')
              .doc(user.uid)
              .collection('schedules')
              .where('groupID', isEqualTo: oldTask.groupID)
              .get();

          for (var doc in groupTasks.docs) {
            final taskData = doc.data();
            if (taskData.containsKey('notificationId')) {
              int? notificationId = taskData['notificationId'] as int?;
              if (notificationId != null) {
                try {
                  await NotificationService.cancelNotification(notificationId);
                  print(
                      "Cancelled notification $notificationId for task ${doc.id}");
                } catch (e) {
                  print("Error cancelling notification $notificationId: $e");
                }
              }
            }
          }
        }
      } else {
        // Cancel notification for single task
        if (oldTask.notificationId != null) {
          try {
            await NotificationService.cancelNotification(
                oldTask.notificationId!);
            print(
                "Cancelled notification ${oldTask.notificationId} for task ${oldTask.id}");
          } catch (e) {
            print(
                "Error cancelling notification ${oldTask.notificationId}: $e");
          }
        }
      }
    } catch (e) {
      print("Error in _cancelExistingNotifications: $e");
    }
  }

  Future<void> updateTaskPriority(String taskId, String priority) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        final taskRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('schedules')
            .doc(taskId);

        final existingTask = await taskRef.get();
        if (!existingTask.exists) {
          throw Exception('Task not found');
        }

        await taskRef.update({
          'priority': priority,
        });
      } catch (e) {
        throw Exception('Failed to update task priority: $e');
      }
    } else {
      throw Exception('User not logged in');
    }
  }

  // ------------------------------ Mark Schedules as Done ------------------------------

  Future<void> updateTaskCompletion(String taskId, bool markAsDone) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        final taskRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('schedules')
            .doc(taskId);

        final existingTask = await taskRef.get();
        if (!existingTask.exists) {
          throw Exception('Task not found');
        }

        final Map<String, dynamic> updateData = {
          'done': markAsDone,
          'completedAt': markAsDone ? DateTime.now() : null,
        };

        await taskRef.update(updateData);
      } catch (e) {
        throw Exception('Failed to update task completion: $e');
      }
    } else {
      throw Exception('User not logged in');
    }
  }

  Future<void> updateTaskEmotion(String taskId, String? emotion) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        final taskRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('schedules')
            .doc(taskId);

        final existingTask = await taskRef.get();
        if (!existingTask.exists) {
          throw Exception('Task not found');
        }

        // Create updated task with new emotion
        final updatedTask = Task.fromMap(taskId, existingTask.data()!).copyWith(
          emotion: emotion,
        );

        // Update only the emotion field in Firestore
        await taskRef.update({
          'emotion': emotion,
        });
      } catch (e) {
        throw Exception('Failed to update task emotion: $e');
      }
    } else {
      throw Exception('User not logged in');
    }
  }

  Future<void> updateFavouriteTask(String taskId, bool? favourite) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        final taskRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('schedules')
            .doc(taskId);

        final existingTask = await taskRef.get();
        if (!existingTask.exists) {
          throw Exception('Task not found');
        }

        final updatedTask = Task.fromMap(taskId, existingTask.data()!).copyWith(
          favourite: favourite,
        );

        await taskRef.update({
          'favourite': favourite,
        });
      } catch (e) {
        throw Exception('Failed to update task favourite: $e');
      }
    } else {
      throw Exception('User not logged in');
    }
  }

  Future<void> updateTaskTime({
    required String taskId,
    required DateTime newDateTime,
  }) async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        final taskRef = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('schedules')
            .doc(taskId);

        final existingTask = await taskRef.get();
        if (!existingTask.exists) {
          throw Exception('Task not found');
        }

        await taskRef.update({
          'time': Timestamp.fromDate(newDateTime),
        });
      } catch (e) {
        throw Exception('Failed to update task time: $e');
      }
    } else {
      throw Exception('User not logged in');
    }
  }

  // ------------------------------ Readd Schedules ------------------------------

  Future<void> reAddSchedule(Task task) async {
    User? user = _auth.currentUser;
    if (user != null) {
      final taskRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(task.id);

      // Convert task data to a Map
      Map<String, dynamic> taskData = task.toMap();

      // Clear the 'files' field
      taskData['files'] = [];

      // Re-add the task with cleared 'files' field
      await taskRef.set(taskData, SetOptions(merge: true));
    } else {
      throw Exception('User not logged in');
    }
  }

  // ------------------------------ 4. Get Schedules part ------------------------------

  // ------------------------------ Get Schedules ------------------------------

  // Stream of Task objects instead of QuerySnapshot
  Stream<List<Task>> getSchedules() {
    print('DEBUG: getSchedules() called');
    User? user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromMap(doc.id, doc.data()))
              .toList());
    }
    return Stream.value([]);
  }

  Future<Task> getScheduleById(String taskId) async {
    print('DEBUG: getScheduleById($taskId) called');
    User? user = _auth.currentUser;
    if (user != null) {
      final taskDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(taskId)
          .get();

      if (taskDoc.exists) {
        return Task.fromMap(taskDoc.id, taskDoc.data()!);
      } else {
        throw Exception('Task not found');
      }
    } else {
      throw Exception('User not logged in');
    }
  }

  // Check Conflict Time Task
  Future<List<Task>> getConflictTasks({required DateTime newTaskTime}) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("User does not login");
    }

    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .where('time', isEqualTo: newTaskTime)
        .where('done', isEqualTo: false)
        .get();

    return querySnapshot.docs
        .map((doc) => Task.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ------------------------------ Get Completed Task For Today ONLY ------------------------------

  Stream<List<Task>> getCompletedSchedulesForToday() {
    User? user = _auth.currentUser;
    if (user != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));

      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('done', isEqualTo: true)
          .where('completedAt', isGreaterThanOrEqualTo: today)
          .where('completedAt', isLessThan: tomorrow)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromMap(doc.id, doc.data()))
              .toList());
    }
    return Stream.value([]);
  }

  Stream<List<Task>> getAllCompletedTasks() {
    User? user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('done', isEqualTo: true)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromMap(doc.id, doc.data()))
              .toList());
    }
    return Stream.value([]);
  }

  Stream<List<Task>> getInCompletedSchedulesForToday() {
    User? user = _auth.currentUser;
    if (user != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));

      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('done', isEqualTo: false)
          .where('completedAt', isGreaterThanOrEqualTo: today)
          .where('completedAt', isLessThan: tomorrow)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromMap(doc.id, doc.data()))
              .toList());
    }
    return Stream.value([]);
  }

  Stream<List<Task>> getCompletedTasksForDate(DateTime date) {
    User? user = _auth.currentUser;
    if (user != null) {
      // Create date range for the specified date (from 00:00:00 to 23:59:59)
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(Duration(days: 1));

      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('done', isEqualTo: true)
          .where('completedAt', isGreaterThanOrEqualTo: startOfDay)
          .where('completedAt', isLessThan: endOfDay)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromMap(doc.id, doc.data()))
              .toList());
    }
    return Stream.value([]);
  }

  Future<Task?> getNearestUpcomingTask() async {
    User? user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final now = DateTime.now();
    final next24h = now.add(Duration(hours: 24)); // You'll still use this

    final querySnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('schedules')
        .where('done', isEqualTo: false)
        .where('time', isGreaterThan: now) // Filter out past tasks
        .where('time',
            isLessThanOrEqualTo:
                next24h) // Only consider tasks within the next 24h
        .orderBy('time',
            descending: false) // Sort by time ascending (earliest first)
        .limit(1) // Crucial: Only fetch the first document after sorting
        .get();

    if (querySnapshot.docs.isEmpty) {
      // No tasks found matching the criteria
      return null;
    }

    final taskDoc = querySnapshot.docs.first;
    return Task.fromMap(taskDoc.id, taskDoc.data());
  }
  // ------------------------------ Get Schedules By Completion Status ------------------------------

  Stream<List<Task>> getSchedulesByCompletionStatus(
      {required bool isCompleted}) {
    User? user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('done', isEqualTo: isCompleted)
          .orderBy('completedAt', descending: false)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => Task.fromMap(doc.id, doc.data()))
              .toList()
              .reversed
              .toList());
    }
    return Stream.value([]);
  }

  // ------------------------------ Get Schedules Based On Date / Date & Time  ------------------------------

  Future<List<Task>> getSchedulesForDate(DateTime date) async {
    User? user = _auth.currentUser;
    if (user != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('time', isGreaterThanOrEqualTo: startOfDay)
          .where('time', isLessThan: endOfDay)
          .orderBy('time', descending: false)
          .get();

      return snapshot.docs
          .map(
              (doc) => Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Task>> getSchedulesForDateTime(DateTime dateTime) async {
    User? user = _auth.currentUser;
    if (user != null) {
      final exactTime = DateTime(
        dateTime.year,
        dateTime.month,
        dateTime.day,
        dateTime.hour,
        dateTime.minute,
      );
      final oneHourLater = exactTime.add(const Duration(minutes: 60));

      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('time', isGreaterThanOrEqualTo: exactTime)
          .where('time', isLessThan: oneHourLater)
          .orderBy('time', descending: false)
          .get();

      return snapshot.docs
          .map(
              (doc) => Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<List<Task>> getCreatedSchedulesDate(DateTime date) async {
    User? user = _auth.currentUser;
    if (user != null) {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
          .where('createdAt', isLessThan: endOfDay)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map(
              (doc) => Task.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

// ------------------------------ Get Schedules By Completion Status and Query (FOR CHATBOT SEARCHING) ------------------------------

  Stream<List<Task>> getSchedulesByCompletionStatusAndQuery({
    required bool isCompleted,
    required String searchQuery,
  }) {
    User? user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .where('done', isEqualTo: isCompleted)
          .orderBy('completedAt', descending: false)
          .snapshots()
          .asyncMap((snapshot) async {
        final tasks = snapshot.docs
            .map((doc) => Task.fromMap(doc.id, doc.data()))
            .toList();
        return searchTasksWithRelevance(searchQuery, tasks);
      });
    }
    return Stream.value([]);
  }

  // ------------------------------ Search Schedules with highest similarity result ------------------------------

  Future<List<Task>> searchTasksWithRelevance(
    String searchQuery,
    List<Task> tasks, {
    bool limitOne = false,
  }) async {
    if (tasks.isEmpty || searchQuery.isEmpty) {
      return [];
    }

    final normalizedQuery = searchQuery.toLowerCase().trim();
    final queryWords = normalizedQuery
        .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();

    if (queryWords.isEmpty) return [];

    final tasksWithScores = tasks.map((task) {
      final normalizedTitle = task.title.toLowerCase();
      final titleWords = normalizedTitle
          .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
          .split(' ')
          .where((word) => word.isNotEmpty)
          .toList();

      double wordMatchScore = 0;
      int exactWordMatches = 0;
      int matchedWordsCount = 0;

      // More precise word matching
      for (final queryWord in queryWords) {
        bool queryWordMatched = false;

        // Check for exact matches first (highest priority)
        if (titleWords.contains(queryWord)) {
          exactWordMatches++;
          wordMatchScore += 1.0;
          queryWordMatched = true;
        } else {
          // Only do fuzzy matching if no exact match found
          for (final titleWord in titleWords) {
            final similarity =
                StringSimilarity.compareTwoStrings(queryWord, titleWord);
            if (similarity > 0.95) {
              // Much stricter threshold
              wordMatchScore += similarity;
              queryWordMatched = true;
              break; // Take only the best match
            }
          }
        }

        if (queryWordMatched) matchedWordsCount++;
      }

      // Calculate query word coverage
      double queryWordCoverage = matchedWordsCount / queryWords.length;

      // Early exit for poor coverage
      if (queryWordCoverage < 0.7) {
        return (task: task, score: 0.0);
      }

      // Full phrase similarity with stricter evaluation
      final titleSimilarity = StringSimilarity.compareTwoStrings(
        normalizedQuery,
        normalizedTitle,
      );

      // Base score calculation with emphasis on exact matches
      double score = (wordMatchScore * 0.5) + (titleSimilarity * 0.3);

      // Strong bonus for exact word matches
      score += exactWordMatches * 0.4;

      // Very strong bonus for exact substring match
      if (normalizedTitle.contains(normalizedQuery)) {
        score += 0.8;
      }

      // Bonus for complete query word coverage
      if (queryWordCoverage == 1.0) {
        score += 0.3;
      }

      // Length penalty for titles much longer than query
      if (normalizedTitle.length > normalizedQuery.length * 2.5) {
        score *= 0.7;
      }

      return (task: task, score: score);
    }).toList();

    // Sort by score
    tasksWithScores.sort((a, b) => b.score.compareTo(a.score));

    // Apply stricter filtering
    double minThreshold = normalizedQuery.length <= 3 ? 0.8 : 0.6;

    final relevantTasksWithScores =
        tasksWithScores.where((item) => item.score > minThreshold).toList();

    if (relevantTasksWithScores.isEmpty) {
      return [];
    }

    if (limitOne) {
      return [relevantTasksWithScores.first.task];
    }

    return relevantTasksWithScores.map((item) => item.task).toList();
  }

  // ------------------------------ 5. Subtask Management Part ------------------------------

  Future<SubTask> addSubtask(String taskId, String title) async {
    User? user = _auth.currentUser;
    if (user != null) {
      final taskRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(taskId);

      final taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }

      final task = Task.fromMap(taskId, taskDoc.data()!);

      final newSubtask = SubTask(
        id: '${DateTime.now().millisecondsSinceEpoch}-${title.hashCode}',
        title: title,
      );

      final updatedSubtasks = [...task.subtasks, newSubtask];

      await taskRef.update({
        'subtasks': updatedSubtasks.map((s) => s.toMap()).toList(),
      });

      return newSubtask;
    }
    throw Exception('User not logged in');
  }

  Future<void> deleteSubtask(String taskId, String subtaskId) async {
    User? user = _auth.currentUser;
    if (user != null) {
      final taskRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(taskId);

      final taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }

      final task = Task.fromMap(taskId, taskDoc.data()!);
      final updatedSubtasks =
          task.subtasks.where((s) => s.id != subtaskId).toList();

      await taskRef.update({
        'subtasks': updatedSubtasks.map((s) => s.toMap()).toList(),
      });
    } else {
      throw Exception('User not logged in');
    }
  }

  Future<void> updateSubtaskOrder(
      String taskId, List<String> subtaskIds) async {
    User? user = _auth.currentUser;
    if (user != null) {
      final taskRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(taskId);

      final taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }

      final task = Task.fromMap(taskId, taskDoc.data()!);

      // Create a map for quick lookup
      final subtaskMap = {
        for (var subtask in task.subtasks) subtask.id: subtask
      };

      // Create new ordered list while preserving all subtask data
      final reorderedSubtasks =
          subtaskIds.map((id) => subtaskMap[id]).whereType<SubTask>().toList();

      await taskRef.update({
        'subtasks': reorderedSubtasks.map((s) => s.toMap()).toList(),
      });
    } else {
      throw Exception('User not logged in');
    }
  }

  Future<void> updateSubtaskStatus(
      String taskId, String subtaskId, bool isDone) async {
    User? user = _auth.currentUser;
    if (user != null) {
      final taskRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('schedules')
          .doc(taskId);

      final taskDoc = await taskRef.get();
      if (!taskDoc.exists) {
        throw Exception('Task not found');
      }

      final task = Task.fromMap(taskId, taskDoc.data()!);
      final updatedSubtasks = task.subtasks.map((subtask) {
        if (subtask.id == subtaskId) {
          return SubTask(
            id: subtask.id,
            title: subtask.title,
            isDone: isDone,
            completedAt: isDone ? DateTime.now() : null,
          );
        }
        return subtask;
      }).toList();

      final allSubtasksCompleted = updatedSubtasks.every((s) => s.isDone);

      await taskRef.update({
        'subtasks': updatedSubtasks.map((s) => s.toMap()).toList(),
        'allSubtasksCompleted': allSubtasksCompleted,
      });
    } else {
      throw Exception('User not logged in');
    }
  }
}
