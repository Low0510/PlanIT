class SubTask {
  String id;
  String title;
  bool isDone;
  DateTime? completedAt;

  SubTask({
    required this.id,
    required this.title,
    this.isDone = false,
    this.completedAt,
  });

  SubTask copyWith({
    String? id,
    String? title,
    bool? isDone,
    DateTime? completedAt,
  }) {
    return SubTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isDone': isDone,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory SubTask.fromMap(Map<String, dynamic> map) {
    return SubTask(
      id: map['id'],
      title: map['title'],
      isDone: map['isDone'] ?? false,
      completedAt:
          map['completedAt'] != null ? DateTime.parse(map['completedAt']) : null,
    );
  }
}