import 'package:firebase_auth/firebase_auth.dart';
import 'package:planit_schedule_manager/models/project50task.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';

class Project50Service {
  Database? _database;
  User user = FirebaseAuth.instance.currentUser!;

  Project50Service() {
    _initDatabase(); // Start initialization in constructor
  }

  Future<void> _initDatabase() async {
    try {
      String path =
          join(await getDatabasesPath(), '${user.email}_project50.db');
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // Create project50_details table
          await db.execute('''
            CREATE TABLE project50_details (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              streakActive INTEGER,
              currentDay INTEGER,
              completedDays INTEGER,
              lastActivityDate TEXT,
              totalCompletedTasks INTEGER,
              progressPercentage REAL,
              challengeStartDate TEXT,
              challengeEndDate TEXT,
              isChallengeCompleted INTEGER,
              failedAttempts INTEGER
            )
          ''');

          // Create project50_tasks table
          await db.execute('''
            CREATE TABLE project50_tasks (
              id TEXT PRIMARY KEY,
              title TEXT,
              category TEXT,
              description TEXT,
              time TEXT,
              isCompleted INTEGER,
              day INTEGER,
              createdAt TEXT,
              updatedAt TEXT,
              orderTask INTEGER
            )
          ''');
        },
      );
    } catch (e) {
      print("Error initializing database: $e");
    }
  }

  // Helper to ensure database is ready
  Future<Database> getDatabase() async {
    if (_database == null) {
      await _initDatabase();
      if (_database == null) {
        throw Exception("Failed to initialize database");
      }
    }
    return _database!;
  }

  Future<void> addProject50Task({Project50Task? task}) async {
    final db = await getDatabase();
    if (task == null) throw Exception("Task is null!");
    await db.insert('project50_tasks', task.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> isProject50init() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result =
        await db.query('project50_tasks', limit: 1);
    return result.isNotEmpty;
  }

  Future<void> initializeProject50IfNeeded() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> details =
        await db.query('project50_details', limit: 1);
    if (details.isNotEmpty) return; // Already initialized

    final DateTime startDate = DateTime.now().add(Duration(days: 1)).copyWith(
        hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0);

    await db.insert('project50_details', {
      'streakActive': 0,
      'currentDay': 0,
      'completedDays': 0,
      'lastActivityDate': DateTime.now().toIso8601String(),
      'totalCompletedTasks': 0,
      'progressPercentage': 0.0,
      'challengeStartDate': startDate.toIso8601String(),
      'challengeEndDate': startDate.add(Duration(days: 50)).toIso8601String(),
      'isChallengeCompleted': 0,
      'failedAttempts': 0,
    });

    await _initializeProject50Tasks(startDate);
    print("Project 50 initialized successfully!");
  }

  Future<void> _initializeProject50Tasks(DateTime startDate) async {
    final db = await getDatabase();
    final batch = db.batch();
    for (int day = 1; day <= 50; day++) {
      final dayDate = startDate.add(Duration(days: day - 1));
      final List<Map<String, String>> rules = [
        {'title': 'Wake up by 8am', 'category': 'Morning'},
        {'title': '1 hour morning routine', 'category': 'Morning'},
        {'title': 'Exercise for 1 hour', 'category': 'Health'},
        {'title': 'Read 10 pages', 'category': 'Learning'},
        {'title': '1 hour towards new skill/goal', 'category': 'Growth'},
        {'title': 'Follow a healthy diet', 'category': 'Health'},
        {'title': 'Track your progress', 'category': 'Accountability'}
      ];

      for (int i = 0; i < rules.length; i++) {
        final rule = rules[i];
        final task = Project50Task(
          id: '${day}_${i + 1}',
          title: rule['title']!,
          category: rule['category']!,
          description: 'Day $day: ${rule['title']}',
          time: dayDate,
          isCompleted: false,
          day: day,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          orderTask: i + 1,
        );
        batch.insert('project50_tasks', task.toMap());
      }
    }
    await batch.commit();
  }

  Future<Map<String, dynamic>?> getProject50Details() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result =
        await db.query('project50_details', limit: 1);
    return result.isNotEmpty ? result.first : null;
  }

  Future<List<Project50Task>> getProject50Tasks() async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result = await db.query(
      'project50_tasks',
      orderBy: 'day ASC, "order" ASC',
    );
    return result.map((map) => Project50Task.fromMap(map['id'], map)).toList();
  }

  Future<Project50Task?> getProject50TaskById(String taskId) async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result = await db.query(
      'project50_tasks',
      where: 'id = ?',
      whereArgs: [taskId],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return Project50Task.fromMap(result.first['id'], result.first);
    }
    return null;
  }

  Future<void> updateProject50Details(Map<String, dynamic> updates) async {
    final db = await getDatabase();
    updates['lastActivityDate'] = DateTime.now().toIso8601String();
    await db.update(
      'project50_details',
      updates,
      where: 'id = ?',
      whereArgs: [1],
    );
  }

  Future<void> updateProject50TaskDetails(
      String taskID, Project50Task updatedTask) async {
    final db = await getDatabase();
    Map<String, dynamic> updatedFields = updatedTask.toMap();
    updatedFields['updatedAt'] = DateTime.now().toIso8601String();
    await db.update(
      'project50_tasks',
      updatedFields,
      where: 'id = ?',
      whereArgs: [taskID],
    );
  }

  Future<List<Project50Task>> getProject50TasksByDay(int day) async {
    final db = await getDatabase();
    final List<Map<String, dynamic>> result = await db.query(
      'project50_tasks',
      where: 'day = ?',
      whereArgs: [day],
      orderBy: 'orderTask ASC',
    );
    return result.map((map) => Project50Task.fromMap(map['id'], map)).toList();
  }
}
