
class Project50Task {
  String id;
  String title;
  String category;
  String description;
  DateTime time;
  bool isCompleted;
  int day;
  DateTime createdAt;
  DateTime updatedAt;
  int orderTask;

  Project50Task({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.time,
    required this.isCompleted,
    required this.day,
    required this.createdAt,
    required this.updatedAt,
    required this.orderTask,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'time': time.toIso8601String(),
      'isCompleted': isCompleted ? 1 : 0,
      'day': day,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'orderTask': orderTask,
    };
  }

  factory Project50Task.fromMap(String id, Map<String, dynamic> map) {
    return Project50Task(
      id: id,
      title: map['title'],
      category: map['category'],
      description: map['description'],
      time: DateTime.parse(map['time']),
      isCompleted: map['isCompleted'] == 1,
      day: map['day'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: DateTime.parse(map['updatedAt']),
      orderTask: map['orderTask'],
    );
  }
}