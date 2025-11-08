import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:collection/collection.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:flutter/material.dart';

class AnalyticsData {
    final double completionRate;
    final Map<String, int> categoryDistribution;
    final Map<String, int> priorityDistribution;
    final Map<String, double> emotionalTrends;
    final double averageProductivity;
    final Map<String, int> timeOfDayDistribution;
    final List<Task> recentTasks;
    final Map<DateTime, int> taskTrends;
    final double averageCompletionTime;
    final Map<String, double> emotionalProductivity;

    AnalyticsData({
      required this.completionRate,
      required this.categoryDistribution,
      required this.priorityDistribution,
      required this.emotionalTrends,
      required this.averageProductivity,
      required this.timeOfDayDistribution,
      required this.recentTasks,
      required this.taskTrends,
      required this.averageCompletionTime,
      required this.emotionalProductivity,
    });
  }

class TaskAnalytics {
  // Emotion categories for better sentiment grouping
  static const Map<String, Map<String, double>> emotionScores = {
    '😆': {'positivity': 0.7, 'energy': 0.8}, // High enjoyment, high energy
    '😍': {'positivity': 0.8, 'energy': 0.6}, // High passion, good energy
    '🥳': {'positivity': 0.7, 'energy': 0.9}, // High positivity, maximum energy
    '🥴': {
      'positivity': 0.3,
      'energy': 0.3
    }, // Lower positivity, low energy due to overwhelm
    '😡': {
      'positivity': 0.1,
      'energy': 0.7
    }, // Low positivity, high energy from frustration
    '😢': {'positivity': 0.2, 'energy': 0.2}, // Low positivity, low energy
    '😫': {'positivity': 0.1, 'energy': 0.1}, // Low positivity, very low energy
    '🚀': {
      'positivity': 0.8,
      'energy': 0.8
    }, // High positivity, high energy for progress
  };
  final List<String> standardCategories = [
    'HEALTH',
    'WORK',
    'OTHER',
    'PERSONAL',
    'ENTERTAINMENT'
  ];

  

  Future<AnalyticsData> calculateAnalytics(List<Task> tasks) async {
    // Basic completion metrics
    final completedTasks = tasks.where((t) => t.done).toList();
    final completionRate = tasks.isEmpty ? 0.0 : completedTasks.length / tasks.length * 100;


    // Category and priority distribution
    final categoryDist = _calculateCategoryDistribution(tasks, (t) => t.category);
    final priorityDist = _calculateDistribution(tasks, (t) => t.priority);

    // Emotional analysis
    final emotionalTrends = _analyzeEmotionalTrends(tasks);
    final emotionalProductivity = _analyzeEmotionalProductivity(tasks);

    // Time-based analytics
    final timeOfDayDist = _analyzeTimeOfDay(tasks);
    final taskTrends = _analyzeTaskTrends(tasks);
    final avgCompletionTime = _calculateAverageCompletionTime(completedTasks);

    // Productivity score
    final avgProductivity = calculateProductivityScore(tasks);

    return AnalyticsData(
      completionRate: completionRate,
      categoryDistribution: categoryDist,
      priorityDistribution: priorityDist,
      emotionalTrends: emotionalTrends,
      averageProductivity: avgProductivity,
      timeOfDayDistribution: timeOfDayDist,
      recentTasks: tasks.take(5).toList(),
      taskTrends: taskTrends,
      averageCompletionTime: avgCompletionTime,
      emotionalProductivity: emotionalProductivity,
    );
  }

  Map<String, int> _calculateDistribution(List<Task> tasks, String Function(Task) getter) {
    return tasks.fold<Map<String, int>>({}, (map, task) {
      final key = getter(task).toUpperCase();
      map[key] = (map[key] ?? 0) + 1;
      return map;
    });
  }

  Map<String, int> _calculateCategoryDistribution(List<Task> tasks, String Function(Task) getter) {
  // First calculate the raw distribution
  final rawDistribution = tasks.fold<Map<String, int>>({}, (map, task) {
    final key = getter(task).toUpperCase();
    map[key] = (map[key] ?? 0) + 1;
    return map;
  });
  
  // Now preprocess to standardize categories
  final standardizedDistribution = <String, int>{};
  
  // Combine categories
  rawDistribution.forEach((category, count) {
    if (standardCategories.contains(category)) {
      // If it's already a standard category, add directly
      standardizedDistribution[category] = (standardizedDistribution[category] ?? 0) + count;
    } else {
      // Otherwise add to OTHER
      standardizedDistribution['OTHER'] = (standardizedDistribution['OTHER'] ?? 0) + count;
    }
  });
  
  return standardizedDistribution;
}

  Map<String, double> _analyzeEmotionalTrends(List<Task> tasks) {
    final emotionCounts = <String, int>{};
    final emotionScores = <String, double>{};
    
    for (var task in tasks) {
      if (task.emotion != null) {
        emotionCounts[task.emotion!] = (emotionCounts[task.emotion!] ?? 0) + 1;
      }
    }

    final totalTasks = tasks.length;
    emotionCounts.forEach((emotion, count) {
      emotionScores[emotion] = count / totalTasks * 100;
    });

    return emotionScores;
  }

  Map<String, double> _analyzeEmotionalProductivity(List<Task> tasks) {
    final emotionProductivity = <String, List<double>>{};

    for (var task in tasks) {
      if (task.emotion != null && task.done) {
        final completionTime = task.completedAt!.difference(task.createdAt!).inMinutes;
        emotionProductivity.putIfAbsent(task.emotion!, () => []).add(completionTime.toDouble());
      }
    }

    return emotionProductivity.map((emotion, times) {
      final avg = times.isEmpty ? 0.0 : times.average;
      return MapEntry(emotion, avg);
    });
  }

  Map<String, int> _analyzeTimeOfDay(List<Task> tasks) {
    final timeDistribution = {
      'Morning (6-12)': 0,
      'Afternoon (12-17)': 0,
      'Evening (17-22)': 0,
      'Night (22-6)': 0,
    };

    // Return default distribution if tasks list is empty
    if (tasks.isEmpty) {
      return timeDistribution;
    }

    for (var task in tasks) {
      final hour = task.time.hour;
      if (hour >= 6 && hour < 12) timeDistribution['Morning (6-12)'] = (timeDistribution['Morning (6-12)'] ?? 0) + 1;
      else if (hour >= 12 && hour < 17) timeDistribution['Afternoon (12-17)'] = (timeDistribution['Afternoon (12-17)'] ?? 0) + 1;
      else if (hour >= 17 && hour < 22) timeDistribution['Evening (17-22)'] = (timeDistribution['Evening (17-22)'] ?? 0) + 1;
      else timeDistribution['Night (22-6)'] = (timeDistribution['Night (22-6)'] ?? 0) + 1;
    }

    return timeDistribution;
  }

  Map<DateTime, int> _analyzeTaskTrends(List<Task> tasks) {
    final trends = <DateTime, int>{};
    
    for (var task in tasks) {
      final date = DateTime(task.createdAt!.year, task.createdAt!.month, task.createdAt!.day);
      trends[date] = (trends[date] ?? 0) + 1;
    }

    return trends;
  }

  double _calculateAverageCompletionTime(List<Task> completedTasks) {
    if (completedTasks.isEmpty) return 0.0;

    final totalTime = completedTasks
        .where((task) => task.completedAt != null && task.createdAt != null)
        .map((task) => task.completedAt!.difference(task.createdAt!).inHours)
        .fold<int>(0, (sum, time) => sum + time);

    return totalTime / completedTasks.length;
  }

  double calculateProductivityScore(List<Task> tasks) {
    if (tasks.isEmpty) return 0.0;

    double totalPossibleScore = 0.0;
    double actualScore = 0.0;

    // Define priority weights
    const Map<String, double> priorityWeights = {
      'high': 3.0,
      'medium': 2.0,
      'low': 1.0,
      'none': 0.5,
    };

    for (var task in tasks) {
      // Calculate the maximum possible score for this task
      double maxTaskScore = priorityWeights[task.priority.toLowerCase()] ?? 1.0;

      // Add subtask potential
      if (task.subtasks.isNotEmpty) {
        maxTaskScore *= 1.3; // Max 30% bonus for subtasks
      }

      totalPossibleScore += maxTaskScore;

      // Skip if not done
      if (!task.done) continue;

      // Base score based on priority
      double taskScore = priorityWeights[task.priority.toLowerCase()] ?? 1.0;

      // Completion time multiplier
      if (task.completedAt != null && task.createdAt != null) {
        final completionHours =
            task.completedAt!.difference(task.createdAt!).inHours;

        // Tiered time bonus
        if (completionHours <= 8) {
          taskScore *= 1.3; // Completed very quickly
        } else if (completionHours <= 24) {
          taskScore *= 1.2; // Completed same day
        } else if (completionHours <= 48) {
          taskScore *= 1.1; // Completed within two days
        }

        // Penalty for overdue tasks (if you have a dueDate property)
        if (task.time != null && task.completedAt!.isAfter(task.time)) {
          final overdueDays = task.completedAt!.difference(task.time).inDays;
          taskScore *=
              math.max(0.5, 1.0 - (overdueDays * 0.1)); // Cap at 50% reduction
        }

      }

      // Subtasks multiplier - more nuanced approach
      if (task.subtasks.isNotEmpty) {
        final completedSubtasks = task.subtasks.where((st) => st.isDone).length;
        final completionRatio = completedSubtasks / task.subtasks.length;

        // Provide partial credit for partial completion
        taskScore *= (1.0 + completionRatio * 0.3);
      }

      actualScore += taskScore;
    }

    // Prevent division by zero
    if (totalPossibleScore == 0) return 0.0;

    // Calculate percentage of possible score achieved
    return (actualScore / totalPossibleScore) * 100;
  }
}
