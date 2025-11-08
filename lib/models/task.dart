import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:planit_schedule_manager/models/subtask.dart';
import 'package:planit_schedule_manager/models/task_file.dart';


class Task {
  final String id;
  final String title;
  final DateTime time;
  final String category;
  final String url;
  final String placeURL;
  final DateTime? createdAt;
  final bool done;
  final DateTime? completedAt;
  final List<SubTask> subtasks;
  final String priority;
  final bool isRepeated;
  final String repeatInterval;
  final int? repeatedIntervalTime;
  final String? emotion;
  final String? groupID;
  final List<TaskFile> files;
  final int? notificationId;
  final bool? favourite;

  Task({
    required this.id,
    required this.title,
    required this.time,
    required this.category,
    this.placeURL = '',
    this.url = '',
    this.createdAt,
    this.done = false,
    this.completedAt,
    required this.subtasks,
    required this.priority,
    required this.isRepeated,
    required this.repeatInterval,
    this.repeatedIntervalTime,
    this.emotion,
    this.groupID,
    this.files = const [],
    this.notificationId,
    this.favourite = false,
  });

  // Factory constructor to create a Task from a Map (usually from Firestore)
  factory Task.fromMap(String id, Map<String, dynamic> map) {
    return Task(
      id: id,
      title: map['title'] ?? '',
      time: (map['time'] as Timestamp).toDate(),
      category: map['category'] ?? '',
      url: map['url'] ?? '',
      placeURL: map['placeURL'] ?? '',
      createdAt: map['createdAt'] != null 
          ? (map['createdAt'] as Timestamp).toDate() 
          : null,
      done: map['done'] ?? false,
      completedAt: map['completedAt'] != null 
          ? (map['completedAt'] as Timestamp).toDate() 
          : null,
      subtasks: (map['subtasks'] as List<dynamic>?)
          ?.map((subtask) => SubTask.fromMap(subtask as Map<String, dynamic>))
          .toList() ?? [],
      priority: map['priority'] ?? 'medium',
      isRepeated: map['isRepeated'] ?? false,
      repeatInterval: map['repeatInterval'] ?? 'none',
      repeatedIntervalTime: map['repeatedIntervalTime'],
      emotion: map['emotion'],
      groupID: map['groupID'],
      files: (map['files'] as List? ?? [])
          .map((file) => TaskFile.fromMap(file as Map<String, dynamic>))
          .toList(),
      notificationId: map['notificationId'] as int?,
      favourite: map['favourite'] ?? false,
    );
  }

  // Convert Task to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'time': Timestamp.fromDate(time),
      'category': category,
      'url': url,
      'placeURL': placeURL,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'done': done,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'subtasks': subtasks.map((subtask) => subtask.toMap()).toList(),
      'priority': priority,
      'isRepeated': isRepeated,
      'repeatInterval': repeatInterval,
      'repeatedIntervalTime': repeatedIntervalTime,
      'emotion': emotion,
      'groupID': groupID,
      'files': files.map((file) => file.toMap()).toList(),
      if (notificationId != null) 'notificationId': notificationId,
      'favourite': favourite,
    };
  }
  // Create a copy of Task with modified fields
  Task copyWith({
    String? title,
    DateTime? time,
    String? category,
    String? url,
    String? placeURL,
    DateTime? createdAt,
    bool? done,
    DateTime? completedAt,
    List<SubTask>? subtasks,
    String? priority,
    bool? isRepeated,
    String? repeatInterval,
    int? repeatedIntervalTime,
    String? emotion,
    String? groupID,
    List<TaskFile>? files, 
    int? notificationId,
    bool clearNotificationId = false,
    bool? favourite,


  }) {
    return Task(
      id: this.id,
      title: title ?? this.title,
      time: time ?? this.time,
      category: category ?? this.category,
      url: url ?? this.url,
      placeURL: placeURL ?? this.placeURL,
      createdAt: createdAt ?? this.createdAt,
      done: done ?? this.done,
      completedAt: completedAt ?? this.completedAt,
      subtasks: subtasks ?? this.subtasks,
      priority: priority ?? this.priority,
      isRepeated: isRepeated ?? this.isRepeated,
      repeatInterval: repeatInterval ?? this.repeatInterval,
      repeatedIntervalTime: repeatedIntervalTime ?? this.repeatedIntervalTime,
      emotion: emotion ?? this.emotion,
      groupID: groupID ?? this.groupID,
      files: files ?? this.files,
      notificationId: clearNotificationId ? null : (notificationId ?? this.notificationId),
      favourite: favourite ?? this.favourite,
    );
  }

}