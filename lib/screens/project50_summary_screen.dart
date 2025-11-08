import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:planit_schedule_manager/models/project50task.dart';
import 'package:planit_schedule_manager/screens/project50_screen.dart';
import 'package:planit_schedule_manager/services/project50_service.dart';

class Project50SummaryPage extends StatefulWidget {
  const Project50SummaryPage({Key? key}) : super(key: key);

  @override
  State<Project50SummaryPage> createState() => _Project50SummaryPageState();
}

class _Project50SummaryPageState extends State<Project50SummaryPage>
    with SingleTickerProviderStateMixin {
  bool isLoading = true;
  late TabController _tabController;
  late List<Project50Task> tasks = [];
  late Map<String, dynamic> summaryData = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadSummaryData();
  }

  Future<void> _loadSummaryData() async {
    setState(() {
      isLoading = true;
    });

    // Load all Project50 tasks
    Project50Service _project50service = Project50Service();
    tasks = await _project50service.getProject50Tasks();

    // Process data for each category
    summaryData = await _processSummaryData(tasks);

    setState(() {
      isLoading = false;
    });
  }

  Future<Map<String, dynamic>> _processSummaryData(
      List<Project50Task> tasks) async {
    Map<String, dynamic> data = {
      'wakeUp': _processWakeUpData(tasks),
      'diet': _processDietData(tasks),
      'exercise': _processExerciseData(tasks),
      'skill': _processSkillData(tasks),
      'reading': _processReadingData(tasks),
      'progress': _processProgressData(tasks),
    };

    return data;
  }

  Map<String, dynamic> _processWakeUpData(List<Project50Task> tasks) {
    List<Map<String, dynamic>> sleepData = [];

    for (var task in tasks.where((t) => t.title.contains('Wake up'))) {
      if (task.description != null) {
        RegExp bedtimeRegex = RegExp(r'Bedtime (\d{2}:\d{2})');
        RegExp wakeupRegex = RegExp(r'Wakeup (\d{2}:\d{2})');

        Match? bedtimeMatch = bedtimeRegex.firstMatch(task.description!);
        Match? wakeupMatch = wakeupRegex.firstMatch(task.description!);

        if (bedtimeMatch != null && wakeupMatch != null) {
          String bedtime = bedtimeMatch.group(1) ?? '';
          String wakeup = wakeupMatch.group(1) ?? '';

          // Calculate sleep duration
          DateTime bedtimeDateTime = _parseTimeString(bedtime);
          DateTime wakeupDateTime = _parseTimeString(wakeup);

          // If wakeup is earlier in the day than bedtime, add a day
          if (wakeupDateTime.isBefore(bedtimeDateTime)) {
            wakeupDateTime = wakeupDateTime.add(const Duration(days: 1));
          }

          Duration sleepDuration = wakeupDateTime.difference(bedtimeDateTime);

          sleepData.add({
            'day': task.day,
            'date': task.time,
            'bedtime': bedtime,
            'wakeup': wakeup,
            'sleepDuration': sleepDuration.inMinutes / 60.0, // in hours
            'isCompleted': task.isCompleted,
          });
        }
      }
    }

    // Calculate average sleep duration
    double totalSleepHours = 0;
    for (var entry in sleepData) {
      totalSleepHours += entry['sleepDuration'];
    }
    double avgSleepHours =
        sleepData.isNotEmpty ? totalSleepHours / sleepData.length : 0;

    // Calculate on-time wakeup rate
    int onTimeWakeups = 0;
    for (var entry in sleepData) {
      String wakeup = entry['wakeup'];
      DateTime wakeupTime = _parseTimeString(wakeup);
      if (wakeupTime.hour < 8 ||
          (wakeupTime.hour == 8 && wakeupTime.minute == 0)) {
        onTimeWakeups++;
      }
    }
    double onTimeRate =
        sleepData.isNotEmpty ? (onTimeWakeups / sleepData.length) * 100 : 0;

    return {
      'sleepData': sleepData,
      'avgSleepHours': avgSleepHours,
      'onTimeRate': onTimeRate,
    };
  }

  Map<String, dynamic> _processDietData(List<dynamic> tasks) {
    List<Map<String, dynamic>> mealLogs = [];
    Map<String, List<int>> scoresByMealType = {};
    double totalScore = 0;
    int totalMeals = 0;

    for (var task in tasks.where((t) => t.title.contains('healthy diet'))) {
      if (task.description != null && task.description.contains('Meal Log:')) {
        // Extract sections using line-by-line approach instead of regex
        Map<String, String> sections = {};
        String currentSection = "";
        List<String> lines = task.description.split('\n');

        String mealType = "";
        String statusText = "";
        int healthScore = 0;
        bool isHealthy = false;

        for (int i = 0; i < lines.length; i++) {
          String line = lines[i].trim();

          if (line.isEmpty) continue;

          // Check if this line starts a new section
          if (line.startsWith('Meal Log:')) {
            currentSection = 'mealLog';

            // Extract the meal type and status
            final mealTypeStatusRegex = RegExp(r'Meal Log: (.*?) - (.+?)$');
            final mealTypeStatusMatch = mealTypeStatusRegex.firstMatch(line);

            if (mealTypeStatusMatch != null) {
              mealType = mealTypeStatusMatch.group(1) ?? '';
              statusText = mealTypeStatusMatch.group(2) ?? '';

              // Extract score from status text
              final scoreRegex = RegExp(r'Score: (\d+)%');
              final scoreMatch = scoreRegex.firstMatch(statusText);
              healthScore =
                  scoreMatch != null ? int.parse(scoreMatch.group(1)!) : 0;
              isHealthy = statusText.contains('✓ Healthy');
            }
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
            sections['protein'] = line.substring('Protein:'.length).trim();
            continue;
          } else if (line.startsWith('Carbs:')) {
            sections['carbs'] = line.substring('Carbs:'.length).trim();
            continue;
          } else if (line.startsWith('Fat:')) {
            sections['fat'] = line.substring('Fat:'.length).trim();
            continue;
          } else if (line.startsWith('Details:')) {
            currentSection = 'details';
            sections[currentSection] = line.substring('Details:'.length).trim();
            continue;
          } else if (line.startsWith('Image:')) {
            currentSection = 'image';
            sections[currentSection] = line.substring('Image:'.length).trim();
            continue;
          } else if (line.startsWith('Logged:')) {
            currentSection = 'logged';
            sections[currentSection] = line.substring('Logged:'.length).trim();
            continue;
          } else if (line.startsWith('NutritionJSON:')) {
            currentSection = 'nutritionJSON';
            // Start collecting all JSON content until we find another section
            StringBuilder jsonContent = StringBuilder();
            jsonContent.write(line.substring('NutritionJSON:'.length).trim());

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
            i = j - 1; // Update outer loop counter to skip processed lines
            continue;
          } else if (currentSection.isNotEmpty) {
            // Append to current section if we're collecting multi-line content
            sections[currentSection] =
                (sections[currentSection] ?? '') + ' ' + line;
          }
        }

        // Initialize nutrition data map
        Map<String, dynamic> nutritionData = {
          'data': {'nutrition': {}}
        };

        // Try to parse the JSON nutrition data first (most complete way)
        if (sections.containsKey('nutritionJSON') &&
            sections['nutritionJSON']!.isNotEmpty) {
          try {
            String jsonStr = sections['nutritionJSON']!;

            // Try to fix common JSON issues
            if (!jsonStr.endsWith('}')) {
              // If JSON is truncated, try to close it properly
              int openBraces = jsonStr.split('{').length - 1;
              int closeBraces = jsonStr.split('}').length - 1;

              // Add missing closing braces
              for (int i = 0; i < (openBraces - closeBraces); i++) {
                jsonStr += '}';
              }
            }

            nutritionData = jsonDecode(jsonStr);
          } catch (e) {
            // Continue with manual parsing as fallback
          }
        }

        // If JSON parsing failed or wasn't available, build nutrition data from individual fields
        if (nutritionData['data'] == null || nutritionData['data'].isEmpty) {
          nutritionData = {
            'data': {'nutrition': {}}
          };

          // Extract food name and calories if available
          if (sections.containsKey('nutrition')) {
            final nameCaloriesRegex = RegExp(r'(.*?), (\d+) calories');
            final nameCalMatch =
                nameCaloriesRegex.firstMatch(sections['nutrition']!);

            if (nameCalMatch != null) {
              nutritionData['data']['name'] = nameCalMatch.group(1)?.trim();
              nutritionData['data']['nutrition']['calories'] =
                  nameCalMatch.group(2);
            } else {
              // Just use whatever is in the nutrition section as the name
              nutritionData['data']['name'] = sections['nutrition']!.trim();
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
            final carbsMatch = RegExp(r'(\d+)g').firstMatch(sections['carbs']!);
            if (carbsMatch != null) {
              nutritionData['data']['nutrition']['carbs'] = carbsMatch.group(1);
            }
          }

          if (sections.containsKey('fat')) {
            final fatMatch = RegExp(r'(\d+)g').firstMatch(sections['fat']!);
            if (fatMatch != null) {
              nutritionData['data']['nutrition']['fat'] = fatMatch.group(1);
            }
          }

          // Process benefits
          if (sections.containsKey('benefits') &&
              sections['benefits']!.isNotEmpty) {
            final benefits =
                sections['benefits']!.split(',').map((b) => b.trim()).toList();
            nutritionData['data']['healthBenefits'] = benefits;
          }

          // Process cautions
          if (sections.containsKey('cautions') &&
              sections['cautions']!.isNotEmpty) {
            final cautions =
                sections['cautions']!.split(',').map((c) => c.trim()).toList();
            nutritionData['data']['cautions'] = cautions;
          }
        }

        mealLogs.add({
          'day': task.day,
          'date': task.time,
          'mealType': mealType,
          'description': sections['details'] ?? '',
          'nutritionData': nutritionData,
          'healthScore': healthScore,
          'isHealthy': isHealthy,
          'isCompleted': task.isCompleted,
          'imagePath': sections['image'] ?? '',
          'loggedTime': sections['logged'] ?? '',
          'nutrition': sections['nutrition'] ?? '',
          'details': sections['details'] ?? '',
        });

        // Update aggregate statistics
        totalScore += healthScore;
        totalMeals++;

        // Collect scores by meal type
        if (mealType.isNotEmpty) {
          if (!scoresByMealType.containsKey(mealType)) {
            scoresByMealType[mealType] = [];
          }
          scoresByMealType[mealType]!.add(healthScore);
        }
      }
    }

    // Calculate average score
    double avgScore = totalMeals > 0 ? totalScore / totalMeals : 0;

    // Calculate average score by meal type
    Map<String, double> avgByMealType = {};
    scoresByMealType.forEach((mealType, scores) {
      double sum = scores.fold(0, (prev, score) => prev + score);
      avgByMealType[mealType] = sum / scores.length;
    });

    return {
      'mealLogs': mealLogs,
      'avgScore': avgScore,
      'avgByMealType': avgByMealType,
    };
  }

  Map<String, dynamic> _processExerciseData(List<Project50Task> tasks) {
    List<Map<String, dynamic>> exerciseLogs = [];

    for (var task in tasks.where((t) => t.title.contains('Exercise'))) {
      if (task.description != null) {
        // Parse exercise data with both regex patterns
        final exerciseInfoRegexWithHours = RegExp(
            r'Exercise Log: (.*?) for (\d+)h (\d+)m, Intensity: (.*?), Calories: (\d+), Muscle Groups: \[(.*?)\], Date: (.*?), Weight: (\d+\.?\d*)');

        final exerciseInfoRegexMinutesOnly = RegExp(
            r'Exercise Log: (.*?) for (\d+)m, Intensity: (.*?), Calories: (\d+), Muscle Groups: \[(.*?)\], Date: (.*?), Weight: (\d+\.?\d*)');

        var match = exerciseInfoRegexWithHours.firstMatch(task.description!);
        bool isHourFormat = true;

        // If no match with hours format, try minutes-only format
        if (match == null) {
          match = exerciseInfoRegexMinutesOnly.firstMatch(task.description!);
          isHourFormat = false;
        }

        if (match != null) {
          String exerciseType;
          int durationMinutes;
          String intensity;
          int calories;
          List<String> muscleGroups;
          DateTime exerciseDate;
          double weight;

          if (isHourFormat) {
            exerciseType = match.group(1) ?? '';
            final hours =
                match.group(2) != null ? int.parse(match.group(2)!) : 0;
            final minutes =
                match.group(3) != null ? int.parse(match.group(3)!) : 0;
            intensity = match.group(4) ?? '';
            calories = match.group(5) != null ? int.parse(match.group(5)!) : 0;
            muscleGroups =
                match.group(6) != null ? match.group(6)!.split(', ') : [];
            exerciseDate = DateTime.parse(
                match.group(7) ?? task.updatedAt.toIso8601String());
            weight =
                match.group(8) != null ? double.parse(match.group(8)!) : 0.0;

            durationMinutes = (hours * 60) + minutes;
          } else {
            exerciseType = match.group(1) ?? '';
            final minutes =
                match.group(2) != null ? int.parse(match.group(2)!) : 0;
            intensity = match.group(3) ?? '';
            calories = match.group(4) != null ? int.parse(match.group(4)!) : 0;
            muscleGroups =
                match.group(5) != null ? match.group(5)!.split(', ') : [];
            exerciseDate = DateTime.parse(
                match.group(6) ?? task.updatedAt.toIso8601String());
            weight =
                match.group(7) != null ? double.parse(match.group(7)!) : 0.0;
            durationMinutes = minutes;
          }

          exerciseLogs.add({
            'day': task.day,
            'date': exerciseDate,
            'exerciseType': exerciseType,
            'durationMinutes': durationMinutes,
            'intensity': intensity,
            'calories': calories,
            'muscleGroups': muscleGroups,
            'weight': weight,
            'isCompleted': task.isCompleted,
          });
        }
      }
    }

    // Calculate statistics
    Map<String, int> exerciseTypeCount = {};
    Map<String, int> muscleGroupsCount = {};
    double totalCalories = 0;
    int totalMinutes = 0;

    // Track weight changes
    List<Map<String, dynamic>> weightData = [];
    double? initialWeight;
    double? currentWeight;

    for (var log in exerciseLogs) {
      // Count exercise types
      String type = log['exerciseType'];
      exerciseTypeCount[type] = (exerciseTypeCount[type] ?? 0) + 1;

      // Count muscle groups worked
      for (var muscle in log['muscleGroups']) {
        muscleGroupsCount[muscle] = (muscleGroupsCount[muscle] ?? 0) + 1;
      }

      // Sum calories and minutes
      totalCalories += log['calories'] as num;
      totalMinutes += log['durationMinutes'] as int;

      // Track weight
      double weight = log['weight'] as double;
      DateTime date = log['date'] as DateTime;

      print('Weight: ${weight}');

      if (weight > 0) {
        weightData.add({
          'date': date,
          'weight': weight,
          'day': log['day'],
        });
      }
    }

    // Sort weight data by date
    weightData.sort((a, b) => a['date'].compareTo(b['date']));

// Only after sorting, determine initial and current weights
    initialWeight = weightData.isNotEmpty ? weightData.first['weight'] : 0;
    currentWeight = weightData.isNotEmpty ? weightData.last['weight'] : 0;

    print('Initial Weight: $initialWeight');
    print('Current Weight: $currentWeight');

// Calculate weight change
    double weightChange = initialWeight != 0 && currentWeight != 0
        ? currentWeight! - initialWeight!
        : 0;

    print("Weight Change: ${weightChange}");

    return {
      'exerciseLogs': exerciseLogs,
      'exerciseTypeCount': exerciseTypeCount,
      'muscleGroupsCount': muscleGroupsCount,
      'totalCalories': totalCalories,
      'totalMinutes': totalMinutes,
      'weightData': weightData,
      'initialWeight': initialWeight,
      'currentWeight': currentWeight,
      'weightChange': weightChange,
    };
  }

  Map<String, dynamic> _processSkillData(List<Project50Task> tasks) {
    List<Map<String, dynamic>> skillLogs = [];

    for (var task in tasks.where((t) => t.title.contains('skill'))) {
      if (task.description != null) {
        RegExp logPattern = RegExp(
          r'Skill Development Log: Skill \"([^\"]+)\", Activity \"([^\"]+)\", Duration (\d+)m, Progress: ([^,]+), Challenge: ([^,\n]+)',
          multiLine: true,
        );

        Iterable<RegExpMatch> matches =
            logPattern.allMatches(task.description!);
        for (var match in matches) {
          skillLogs.add({
            'day': task.day,
            'date': task.time,
            'skillName': match.group(1) ?? '',
            'activity': match.group(2) ?? '',
            'durationMinutes': int.tryParse(match.group(3) ?? '0') ?? 0,
            'progress': match.group(4) ?? 'Not specified',
            'challenge': match.group(5) ?? 'Not specified',
            'isCompleted': task.isCompleted,
          });
        }
      }
    }

    // Group by skill name
    Map<String, List<Map<String, dynamic>>> skillsGrouped = {};
    Map<String, int> totalMinutesBySkill = {};

    for (var log in skillLogs) {
      String skillName = log['skillName'];

      if (!skillsGrouped.containsKey(skillName)) {
        skillsGrouped[skillName] = [];
        totalMinutesBySkill[skillName] = 0;
      }

      skillsGrouped[skillName]!.add(log);
      totalMinutesBySkill[skillName] =
          ((totalMinutesBySkill[skillName] ?? 0) + log['durationMinutes'])
              .toInt();
    }

    return {
      'skillLogs': skillLogs,
      'skillsGrouped': skillsGrouped,
      'totalMinutesBySkill': totalMinutesBySkill,
    };
  }

  Map<String, dynamic> _processReadingData(List<Project50Task> tasks) {
    List<Map<String, dynamic>> readingLogs = [];

    for (var task in tasks.where((t) => t.title.contains('Read'))) {
      if (task.description != null && task.description!.isNotEmpty) {
        RegExp logPattern = RegExp(
          r'Reading Log: Book \"([^\"]+)\", Pages (\d+)-(\d+) \((\d+) pages\), Duration (\d+)m(?:, Feeling: ([^,\n]+))?',
          multiLine: true,
        );

        Iterable<RegExpMatch> matches =
            logPattern.allMatches(task.description!);
        for (var match in matches) {
          // Validate that we have the essential data
          String bookTitle = match.group(1)?.trim() ?? '';
          int startPage = int.tryParse(match.group(2) ?? '') ?? 0;
          int endPage = int.tryParse(match.group(3) ?? '') ?? 0;
          int pagesRead = int.tryParse(match.group(4) ?? '') ?? 0;
          int duration = int.tryParse(match.group(5) ?? '') ?? 0;

          // Only add log if we have valid data
          if (bookTitle.isNotEmpty && pagesRead > 0) {
            readingLogs.add({
              'day': task.day,
              'date': task.time,
              'bookTitle': bookTitle,
              'startPage': startPage,
              'endPage': endPage,
              'pagesRead': pagesRead,
              'duration': duration,
              'feeling': match.group(6)?.trim() ?? 'Not specified',
              'isCompleted': task.isCompleted,
            });
          }
        }
      }
    }

    // Group by book using normalized titles for consistent grouping
    Map<String, List<Map<String, dynamic>>> booksGroupedByNormalizedTitle = {};
    int totalPages = 0;
    int totalMinutes = 0;

    for (var log in readingLogs) {
      // Use normalized title for grouping (uppercase and trimmed)
      String normalizedBookTitle =
          (log['bookTitle'] as String).toUpperCase().trim();

      if (!booksGroupedByNormalizedTitle.containsKey(normalizedBookTitle)) {
        booksGroupedByNormalizedTitle[normalizedBookTitle] = [];
      }

      booksGroupedByNormalizedTitle[normalizedBookTitle]!.add(log);
      totalPages += (log['pagesRead'] as int);
      totalMinutes += (log['duration'] as int);
    }

    // Helper function to get the most common capitalization of a book title
    String getMostCommonCapitalization(List<Map<String, dynamic>> logs) {
      Map<String, int> titleCounts = {};

      for (var log in logs) {
        String title = log['bookTitle'] as String;
        titleCounts[title] = (titleCounts[title] ?? 0) + 1;
      }

      if (titleCounts.isEmpty) return '';

      // Return the title with the highest count (most common capitalization)
      return titleCounts.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;
    }

    // Transform the grouped data into the final maps with consistent, user-friendly keys
    Map<String, List<Map<String, dynamic>>> finalBooksGrouped = {};
    Map<String, int> totalPagesByBook = {};

    booksGroupedByNormalizedTitle.forEach((normalizedTitle, logs) {
      if (logs.isNotEmpty) {
        // Use the most common capitalization as the canonical, user-facing key
        String canonicalTitle = getMostCommonCapitalization(logs);
        finalBooksGrouped[canonicalTitle] = logs;

        // Calculate total pages for this specific book
        int bookTotalPages =
            logs.fold(0, (sum, log) => sum + (log['pagesRead'] as int));
        totalPagesByBook[canonicalTitle] = bookTotalPages;
      }
    });

    // Calculate reading rate safely
    double pagesPerMinute = 0.0;
    if (totalMinutes > 0 && totalPages > 0) {
      pagesPerMinute = totalPages / totalMinutes;
    }

    return {
      'readingLogs': readingLogs,
      'booksGrouped': finalBooksGrouped,
      'totalPagesByBook': totalPagesByBook,
      'totalPages': totalPages,
      'totalMinutes': totalMinutes,
      'pagesPerMinute': pagesPerMinute,
    };
  }

  Map<String, dynamic> _processProgressData(List<Project50Task> tasks) {
    List<Map<String, dynamic>> progressLogs = [];

    for (var task
        in tasks.where((t) => t.title.contains('Track your progress'))) {
      if (task.description != null &&
          task.description!.contains("Progress Log:")) {
        RegExp moodRegex = RegExp(r'Mood: (.+)');
        RegExp ratingRegex = RegExp(r'Rating: (\d+)/5');
        RegExp commentRegex = RegExp(r'Comment: (.+)');
        RegExp dateRegex = RegExp(r'Recorded on (.+)');

        Match? moodMatch = moodRegex.firstMatch(task.description!);
        Match? ratingMatch = ratingRegex.firstMatch(task.description!);
        Match? commentMatch = commentRegex.firstMatch(task.description!);
        Match? dateMatch = dateRegex.firstMatch(task.description!);

        if (moodMatch != null) {
          progressLogs.add({
            'day': task.day,
            'date': task.time,
            'mood': moodMatch.group(1) ?? 'Not recorded',
            'rating': int.tryParse(ratingMatch?.group(1) ?? '0') ?? 0,
            'comment': commentMatch?.group(1) ?? 'No comment recorded',
            'logDate': dateMatch?.group(1) ?? task.time.toString(),
            'isCompleted': task.isCompleted,
          });
        }
      }
    }

    // Calculate mood frequency
    Map<String, int> moodFrequency = {};
    double avgRating = 0;

    for (var log in progressLogs) {
      String mood = log['mood'];
      moodFrequency[mood] = (moodFrequency[mood] ?? 0) + 1;
      avgRating += log['rating'];
    }

    if (progressLogs.isNotEmpty) {
      avgRating = avgRating / progressLogs.length;
    }

    return {
      'progressLogs': progressLogs,
      'moodFrequency': moodFrequency,
      'avgRating': avgRating,
    };
  }

  DateTime _parseTimeString(String timeString) {
    final now = DateTime.now();
    final parts = timeString.split(':');
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Assuming you have a TabController _tabController initialized in initState
    return Scaffold(
      extendBodyBehindAppBar: true, // Allows body to go behind AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.brown.shade700),
        flexibleSpace: ClipRect(
          child: Container(
            color: Colors.white.withOpacity(0.1),
          ),
        ),
        title: Row(
          children: [
            Image.asset('assets/images/tree.png', height: 24),
            SizedBox(width: 8),
            Text(
              "Project 50 Summary",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.green.shade900, // Color for selected tab text
          unselectedLabelColor:
              Colors.brown.shade700, // Color for unselected tabs
          indicator: BoxDecoration(
            // Modern pill-shaped indicator
            borderRadius: BorderRadius.circular(50),
            color: Colors.green.withOpacity(0.3),
          ),
          tabs: [
            Tab(text: 'Sleep'),
            Tab(text: 'Diet'),
            Tab(text: 'Exercise'),
            Tab(text: 'Skill'),
            Tab(text: 'Reading'),
            Tab(text: 'Progress'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/background.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSleepTab(),
              _buildDietTab(),
              _buildExerciseTab(),
              _buildSkillTab(),
              _buildReadingTab(),
              _buildProgressTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSleepTab() {
    final sleepData = summaryData['wakeUp'];
    final avgSleepHours = sleepData['avgSleepHours'] ?? 0;
    final onTimeRate = sleepData['onTimeRate'];
    final sleepLogs = sleepData['sleepData'] as List<Map<String, dynamic>>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.rotationY(3.1416), // flipped left side
                child: Lottie.asset(
                  'assets/lotties/sleeping.json',
                  height: 130,
                ),
              ),
              Lottie.asset(
                'assets/lotties/sleeping.json',
                height: 130,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Average Sleep',
                  '${avgSleepHours.toStringAsFixed(1)} hrs',
                  Colors.indigo,
                  Icons.nightlight_round,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  context,
                  'On-Time Wakeups',
                  '${onTimeRate.toStringAsFixed(1)}%',
                  Colors.teal,
                  Icons.alarm,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Sleep Duration Trend',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildSleepDurationChart(sleepLogs),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Sleep Logs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          sleepLogs.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                      SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: sleepLogs.length > 50 ? 50 : sleepLogs.length,
                  itemBuilder: (context, index) {
                    final log = sleepLogs[sleepLogs.length - 1 - index];
                    final date = log['date'] as DateTime;
                    final formattedDate = DateFormat('MMM d').format(date);

                    return Card(
                      color: Colors.white.withOpacity(0.75),
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          log['isCompleted']
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: log['isCompleted'] ? Colors.green : Colors.red,
                        ),
                        title: Text('Day ${log['day']} ($formattedDate)'),
                        subtitle: Text(
                          'Bedtime: ${log['bedtime']} | Wakeup: ${log['wakeup']}',
                        ),
                        trailing: Text(
                          '${log['sleepDuration'].toStringAsFixed(1)} hrs',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: log['sleepDuration'] >= 7
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildDietTab() {
    final dietData = summaryData['diet'];
    final avgScore = dietData['avgScore'];
    final mealLogs = dietData['mealLogs'] as List<Map<String, dynamic>>;
    final avgByMealType = dietData['avgByMealType'] as Map<String, double>;

    // Create a map for the last 50 days of food images
    // The key is the day number, and the value is the image path
    final Map<int, String?> foodImagesMap = {};

    // Populate the map with available images from meal logs
    for (final log in mealLogs) {
      final int day = log['day'] as int;
      if (day <= 50 &&
          log['imagePath'] != null &&
          log['imagePath'].isNotEmpty) {
        foodImagesMap[day] = log['imagePath'];
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Diet Score Card
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 3,
                  color: Colors.white.withOpacity(0.75),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 12),
                    child: Row(
                      children: [
                        // Progress Indicator and Score
                        SizedBox(
                          height: 100,
                          width: 100,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: avgScore / 100,
                                strokeWidth: 10,
                                backgroundColor: Colors.grey[200],
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  avgScore >= 80
                                      ? Colors.green
                                      : avgScore >= 60
                                          ? Colors.amber
                                          : Colors.red,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${avgScore.toStringAsFixed(0)}%',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    'Score',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Diet Score Label and Description
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Overall Diet Score',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                avgScore >= 80
                                    ? 'Excellent diet habits!'
                                    : avgScore >= 60
                                        ? 'Good progress, keep improving'
                                        : 'Needs improvement',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Animation Section
              Expanded(
                flex: 2,
                child: Lottie.asset(
                  'assets/lotties/diet.json',
                  height: 120,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // New Fixed 50-day Food Memory Wall
          Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '50-Day Food Journey',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visual memory of your nutrition habits',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFoodMemoryWall(foodImagesMap),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Score by Meal Type',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildMealScoreChart(avgByMealType),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Meal Logs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: mealLogs.length > 50 ? 50 : mealLogs.length,
            itemBuilder: (context, index) {
              final log = mealLogs[mealLogs.length - 1 - index];
              final date = log['date'] as DateTime;
              final formattedDate = DateFormat('MMM d').format(date);
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: Colors.white.withOpacity(0.75),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Meal image - more compact
                      if (log['imagePath'] != null &&
                          log['imagePath'].isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: SizedBox(
                            width: 60,
                            height: 60,
                            child: Image.file(
                              File(log['imagePath']),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 24,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                        )
                      else
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[200],
                            child: const Center(
                              child: Icon(
                                Icons.no_food,
                                size: 24,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(width: 12),

                      // Middle section with title and details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Title row with meal type and day
                            Row(
                              children: [
                                Icon(
                                  _getMealIcon(log['mealType']),
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${log['mealType']} (Day ${log['day']})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // Nutrition info in one line (truncated if needed)
                            if (log['nutrition'] != null &&
                                log['nutrition'].isNotEmpty)
                              Text(
                                log['nutrition'],
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),

                            // Meal details in compact format
                            if (log['details'] != null &&
                                log['details'].isNotEmpty)
                              Text(
                                'Details: ' + log['details'],
                                style: const TextStyle(fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),

                      // Right section with score and date
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Health score in small circle
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: log['healthScore'] >= 80
                                ? Colors.green
                                : log['healthScore'] >= 60
                                    ? Colors.amber
                                    : Colors.red,
                            child: Text(
                              '${log['healthScore']}%',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Date in smaller text
                          Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
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
        ],
      ),
    );
  }

// Add this method to build the fixed 50-day food memory wall
  Widget _buildFoodMemoryWall(Map<int, String?> foodImagesMap) {
    // Colors for empty blocks based on position
    final List<Color> emptyBlockColors = [
      Color(0xFFE0F2F1), // Light teal
      Color(0xFFE1F5FE), // Light blue
      Color(0xFFF3E5F5), // Light purple
      Color(0xFFFCE4EC), // Light pink
      Color(0xFFFFF3E0), // Light orange
    ];

    // Food-related icons for empty blocks
    final List<IconData> foodIcons = [
      Icons.restaurant,
      Icons.local_cafe,
      Icons.breakfast_dining,
      Icons.lunch_dining,
      Icons.emoji_food_beverage,
      Icons.bakery_dining,
      Icons.dinner_dining,
      Icons.set_meal,
      Icons.local_pizza,
      Icons.fastfood,
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5, // 5 images per row
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0, // Square tiles
      ),
      itemCount: 50, // Fixed 50 blocks
      itemBuilder: (context, index) {
        final int day = index + 1;
        final bool hasImage = foodImagesMap.containsKey(day);
        final String? imagePath = foodImagesMap[day];

        // Select a color and icon based on position for empty blocks
        final Color emptyColor =
            emptyBlockColors[index % emptyBlockColors.length];
        final IconData emptyIcon = foodIcons[index % foodIcons.length];

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Image or placeholder
                hasImage && imagePath != null
                    ? Image.file(
                        File(imagePath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildEmptyBlock(
                          day,
                          emptyColor,
                          emptyIcon,
                        ),
                      )
                    : _buildEmptyBlock(day, emptyColor, emptyIcon),

                // Day number overlay
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$day',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
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

// Helper method to build empty blocks with different designs
  Widget _buildEmptyBlock(int day, Color color, IconData icon) {
    return Container(
      color: color,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: Colors.black38,
            ),
            const SizedBox(height: 2),
            Text(
              'Day $day',
              style: TextStyle(
                fontSize: 10,
                color: Colors.black45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper function to get appropriate icon for meal type
  IconData _getMealIcon(String mealType) {
    final type = mealType.toLowerCase();
    if (type.contains('breakfast')) return Icons.breakfast_dining;
    if (type.contains('lunch')) return Icons.lunch_dining;
    if (type.contains('dinner')) return Icons.dinner_dining;
    if (type.contains('snack')) return Icons.cookie;
    return Icons.restaurant;
  }

  Widget _buildExerciseTab() {
    final exerciseData = summaryData['exercise'];
    final exerciseLogs =
        exerciseData['exerciseLogs'] as List<Map<String, dynamic>>;
    final totalCalories = exerciseData['totalCalories'];
    final totalMinutes = exerciseData['totalMinutes'];
    final weightData = exerciseData['weightData'] as List<Map<String, dynamic>>;
    final weightChange = exerciseData['weightChange'];
    final initialWeight = exerciseData['initialWeight'];
    final currentWeight = exerciseData['currentWeight'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            color: Colors.white.withOpacity(0.75),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.local_fire_department,
                          color: Colors.orange, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Total Calories',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        totalCalories.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Icon(Icons.timer, color: Colors.blue, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'Total Minutes',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        totalMinutes.toString(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Icon(
                        weightChange <= 0
                            ? Icons.trending_down
                            : Icons.trending_up,
                        color: weightChange <= 0 ? Colors.green : Colors.red,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Weight Change',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        '${weightChange.abs().toStringAsFixed(1)} kg',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Weight Trend',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          weightData.isNotEmpty
              ? SizedBox(
                  height: 200,
                  child: _buildWeightChart(weightData),
                )
              : Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                    ],
                  ),
                ),
          if (weightData.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Starting: ${initialWeight?.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                Text(
                  'Current: ${currentWeight?.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Exercise Type Distribution',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 24),
          exerciseLogs.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  height: 200,
                  child: _buildExerciseTypeChart(
                      exerciseData['exerciseTypeCount']),
                ),
          const SizedBox(height: 24),
          Text(
            'Recent Exercise Logs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          exerciseLogs.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      exerciseLogs.length > 50 ? 50 : exerciseLogs.length,
                  itemBuilder: (context, index) {
                    final log = exerciseLogs[exerciseLogs.length - 1 - index];
                    final minutes = log['durationMinutes'];
                    final hours = minutes ~/ 60;
                    final remainingMinutes = minutes % 60;
                    final duration = hours > 0
                        ? '$hours h ${remainingMinutes > 0 ? "$remainingMinutes m" : ""}'
                        : '$minutes m';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white.withOpacity(0.75),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(
                            _getExerciseIcon(log['exerciseType']),
                            color: Colors.white,
                          ),
                        ),
                        title:
                            Text('${log['exerciseType']} (Day ${log['day']})'),
                        subtitle: Text(
                          'Intensity: ${log['intensity']} • Duration: $duration',
                        ),
                        trailing: Text('${log['calories']} cal'),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildSkillTab() {
    final skillData = summaryData['skill'];
    final skillLogs = skillData['skillLogs'] as List<Map<String, dynamic>>;
    final skillsGrouped =
        skillData['skillsGrouped'] as Map<String, List<Map<String, dynamic>>>;
    final totalMinutesBySkill =
        skillData['totalMinutesBySkill'] as Map<String, int>;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            color: Colors.white.withOpacity(0.75),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Skills Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'You are developing ${skillsGrouped.length} skills',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: skillsGrouped.length,
                    itemBuilder: (context, index) {
                      final skillName = skillsGrouped.keys.elementAt(index);
                      final logs = skillsGrouped[skillName]!;
                      final totalMinutes = totalMinutesBySkill[skillName] ?? 0;
                      final hours = totalMinutes ~/ 60;
                      final minutes = totalMinutes % 60;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  skillName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  hours > 0
                                      ? '$hours h ${minutes > 0 ? "$minutes m" : ""}'
                                      : '$minutes m',
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: totalMinutes / 3000, // ~50 hours as target
                              minHeight: 6,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.purple),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Time Spent per Skill',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildSkillTimeChart(totalMinutesBySkill),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Skill Logs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          skillLogs.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: skillLogs.length > 50 ? 50 : skillLogs.length,
                  itemBuilder: (context, index) {
                    final log = skillLogs[skillLogs.length - 1 - index];
                    final date = log['date'] as DateTime;
                    final formattedDate = DateFormat('MMM d').format(date);

                    // Generate a consistent color based on skill name
                    final int colorValue = log['skillName'].toString().hashCode;
                    final Color accentColor =
                        Color(colorValue).withOpacity(0.8);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 6,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${log['skillName']}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            'Day ${log['day']}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: accentColor,
                                            ),
                                          ),
                                          Container(
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 8),
                                            width: 3,
                                            height: 3,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade400,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: 14,
                                        color: Colors.grey.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${log['durationMinutes']} mins',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Activity section
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.fitness_center,
                                  size: 16,
                                  color: Colors.grey.shade500,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${log['activity']}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade800,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Progress section - showcase the details
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up,
                                      size: 14,
                                      color: accentColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Progress',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: accentColor,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  log['progress'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildReadingTab() {
    final readingData = summaryData['reading'];
    final readingLogs =
        readingData['readingLogs'] as List<Map<String, dynamic>>;
    final booksGrouped =
        readingData['booksGrouped'] as Map<String, List<Map<String, dynamic>>>;
    final totalPagesByBook =
        readingData['totalPagesByBook'] as Map<String, int>;
    final totalPages = readingData['totalPages'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            color: Colors.white.withOpacity(0.75),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'Reading Summary',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.menu_book,
                              color: Colors.teal, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Books',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            booksGrouped.length.toString(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.description,
                              color: Colors.blue, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Pages Read',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            totalPages.toString(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.auto_stories,
                              color: Colors.amber, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            'Reading Days',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            readingLogs.length.toString(),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Books Progress',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          booksGrouped.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: booksGrouped.length,
                  itemBuilder: (context, index) {
                    final bookTitle = booksGrouped.keys.elementAt(index);
                    final logs = booksGrouped[bookTitle]!;
                    final totalPages = totalPagesByBook[bookTitle] ?? 0;

                    // Find start and end pages
                    int minPage = logs
                        .map((log) => log['startPage'] as int)
                        .reduce((value, element) =>
                            value < element ? value : element);
                    int maxPage = logs
                        .map((log) => log['endPage'] as int)
                        .reduce((value, element) =>
                            value > element ? value : element);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white.withOpacity(0.75),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.book, color: Colors.teal),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    bookTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                                'Pages $minPage-$maxPage ($totalPages pages read)'),
                            const SizedBox(height: 8),
                            if (maxPage - minPage + 1 > 0) ...[
                              LinearProgressIndicator(
                                value: totalPages / (maxPage - minPage + 1),
                                minHeight: 8,
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    Colors.teal),
                              ),
                              // const SizedBox(height: 4),
                              // Text(
                              //   '${(totalPages / (maxPage - minPage + 1) * 100).toStringAsFixed(0)}% complete',
                              //   style: const TextStyle(fontSize: 12),
                              // ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 24),
          Text(
            'Recent Reading Logs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          readingLogs.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: readingLogs.length > 50 ? 50 : readingLogs.length,
                  itemBuilder: (context, index) {
                    final log = readingLogs[readingLogs.length - 1 - index];
                    final date = log['date'] as DateTime;
                    final formattedDate = DateFormat('MMM d').format(date);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white.withOpacity(0.75),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.auto_stories, color: Colors.white),
                        ),
                        title: Text('${log['bookTitle']} (Day ${log['day']})'),
                        subtitle: Text(
                          'Pages ${log['startPage']}-${log['endPage']} (${log['pagesRead']} pages) • ${log['duration']} mins',
                        ),
                        trailing: Text(formattedDate),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    final progressData = summaryData['progress'];
    final progressLogs =
        progressData['progressLogs'] as List<Map<String, dynamic>>;
    final moodFrequency = progressData['moodFrequency'] as Map<String, int>;
    final avgRating = progressData['avgRating'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            color: Colors.white.withOpacity(0.75),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Overall Satisfaction',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        size: 40,
                        color: index < avgRating.floor()
                            ? Colors.amber
                            : (index == avgRating.floor() &&
                                    avgRating - avgRating.floor() >= 0.5)
                                ? Colors.amber
                                : Colors.grey[300],
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${avgRating.toStringAsFixed(1)}/5',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mood Distribution',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          moodFrequency.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                    ],
                  ),
                )
              : SizedBox(
                  height: 200,
                  child: _buildMoodDistributionChart(moodFrequency),
                ),
          const SizedBox(height: 24),
          Text(
            'Rating Over Time',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: _buildRatingOverTimeChart(progressLogs),
          ),
          const SizedBox(height: 24),
          Text(
            'Recent Progress Logs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          progressLogs.isEmpty
              ? Center(
                  child: Column(
                    children: [
                      Lottie.asset(
                        'assets/lotties/noData.json',
                        height: 120,
                      ),
                      SizedBox(
                        height: 20,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount:
                      progressLogs.length > 50 ? 50 : progressLogs.length,
                  itemBuilder: (context, index) {
                    final log = progressLogs[progressLogs.length - 1 - index];
                    final date = log['date'] as DateTime;
                    final formattedDate = DateFormat('MMM d').format(date);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: Colors.white.withOpacity(0.75),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getMoodColor(log['mood']),
                          child: Text(
                            log['rating'].toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text('Day ${log['day']} • Mood: ${log['mood']}'),
                        subtitle: Text(log['comment']),
                        trailing: Text(formattedDate),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value,
      Color color, IconData icon) {
    return Card(
      elevation: 4,
      color: Colors.white.withOpacity(0.75),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildCategoryCompletionChart(Map<String, int> completedByCategory) {
  //   final data = completedByCategory.entries.map((entry) {
  //     return BarChartGroupData(
  //       x: _getCategoryIndex(entry.key),
  //       barRods: [
  //         BarChartRodData(
  //           toY: entry.value.toDouble(),
  //           color: _getCategoryColor(entry.key),
  //           width: 16,
  //           borderRadius: const BorderRadius.only(
  //             topLeft: Radius.circular(4),
  //             topRight: Radius.circular(4),
  //           ),
  //         ),
  //       ],
  //     );
  //   }).toList();

  //   return BarChart(
  //     BarChartData(
  //       alignment: BarChartAlignment.center,
  //       maxY: 50, // Assuming max 50 tasks per category
  //       barGroups: data,
  //       titlesData: FlTitlesData(
  //         show: true,
  //         bottomTitles: AxisTitles(
  //           sideTitles: SideTitles(
  //             showTitles: true,
  //             getTitlesWidget: (value, meta) {
  //               String text = '';
  //               switch (value.toInt()) {
  //                 case 0:
  //                   text = 'Morning';
  //                   break;
  //                 case 1:
  //                   text = 'Health';
  //                   break;
  //                 case 2:
  //                   text = 'Learning';
  //                   break;
  //                 case 3:
  //                   text = 'Growth';
  //                   break;
  //                 case 4:
  //                   text = 'Acct';
  //                   break;
  //               }
  //               return Padding(
  //                 padding: const EdgeInsets.only(top: 8),
  //                 child: Text(
  //                   text,
  //                   style: const TextStyle(
  //                     fontSize: 10,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //               );
  //             },
  //             reservedSize: 30,
  //           ),
  //         ),
  //         leftTitles: AxisTitles(
  //           sideTitles: SideTitles(
  //             showTitles: true,
  //             reservedSize: 30,
  //             getTitlesWidget: (value, meta) {
  //               if (value % 10 == 0) {
  //                 return Text(
  //                   value.toInt().toString(),
  //                   style: const TextStyle(fontSize: 10),
  //                 );
  //               }
  //               return Container();
  //             },
  //           ),
  //         ),
  //         rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
  //         topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
  //       ),
  //       borderData: FlBorderData(show: false),
  //       gridData: FlGridData(show: true, horizontalInterval: 10),
  //     ),
  //   );
  // }

  // int _getCategoryIndex(String category) {
  //   switch (category) {
  //     case 'Morning':
  //       return 0;
  //     case 'Health':
  //       return 1;
  //     case 'Learning':
  //       return 2;
  //     case 'Growth':
  //       return 3;
  //     case 'Accountability':
  //       return 4;
  //     default:
  //       return 0;
  //   }
  // }

  // Color _getCategoryColor(String category) {
  //   switch (category) {
  //     case 'Morning':
  //       return Colors.amber;
  //     case 'Health':
  //       return Colors.green;
  //     case 'Learning':
  //       return Colors.blue;
  //     case 'Growth':
  //       return Colors.purple;
  //     case 'Accountability':
  //       return Colors.red;
  //     default:
  //       return Colors.grey;
  //   }
  // }

  Widget _buildSleepDurationChart(List<Map<String, dynamic>> sleepLogs) {
    // Take the most recent 50 logs, or fewer if sleepLogs.length < 50
    final logsToShow = sleepLogs.length > 50
        ? sleepLogs.sublist(sleepLogs.length - 50)
        : sleepLogs;

    final spots = logsToShow.asMap().entries.map((entry) {
      final index = entry.key;
      final log = entry.value;
      return FlSpot(
        index.toDouble(), // Use index instead of day for consistent spacing
        log['sleepDuration'],
      );
    }).toList();

    // Calculate optimal interval for bottom titles based on available space
    int getTitleInterval() {
      if (logsToShow.length <= 10) return 1;
      if (logsToShow.length <= 20) return 2;
      if (logsToShow.length <= 30) return 5;
      if (logsToShow.length <= 50) return 7;
      return 10;
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.indigo,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.indigo.withOpacity(0.2),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: logsToShow[index]['isCompleted']
                      ? Colors.green
                      : Colors.red,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
          ),
        ],
        minX: 0,
        maxX: (logsToShow.length - 1).toDouble(),
        minY: 0,
        maxY: 10, // Most people sleep less than 10 hours
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: getTitleInterval().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < logsToShow.length) {
                  final day = logsToShow[index]['day'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'D$day',
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                }
                return Container();
              },
              reservedSize: 35,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() == value && value >= 0 && value <= 10) {
                  return Text(
                    '${value.toInt()}h',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return Container();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 2,
          verticalInterval: getTitleInterval().toDouble(),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.indigo.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                final log = logsToShow[index];
                return LineTooltipItem(
                  'Day ${log['day']}: ${log['sleepDuration'].toStringAsFixed(1)}h\n'
                  'Bedtime: ${log['bedtime']}, Wakeup: ${log['wakeup']}',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMealScoreChart(Map<String, double> avgByMealType) {
    final data = avgByMealType.entries.map((entry) {
      return BarChartGroupData(
        x: _getMealTypeIndex(entry.key),
        barRods: [
          BarChartRodData(
            toY: entry.value,
            color: _getMealScoreColor(entry.value),
            width: 12, // Reduced from 16 to create more space
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment:
            BarChartAlignment.spaceAround, // Changed from center to spaceAround
        maxY: 100,
        barGroups: data,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                String text = '';
                switch (value.toInt()) {
                  case 0:
                    text = 'Brkfst'; // Shortened labels
                    break;
                  case 1:
                    text = 'Lunch';
                    break;
                  case 2:
                    text = 'Dinner';
                    break;
                  case 3:
                    text = 'Snack'; // Removed plural
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: RotatedBox(
                    // Rotate text by -45 degrees
                    quarterTurns: -1,
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 9, // Reduced from 10
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
              reservedSize: 40, // Increased from 30 to accommodate rotated text
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value % 20 == 0) {
                  return Text(
                    '${value.toInt()}%',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return Container();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: true, horizontalInterval: 20),
        barTouchData: BarTouchData(
            enabled:
                false), // Optional: disable touch to prevent overlap with tooltips
      ),
    );
  }

  int _getMealTypeIndex(String mealType) {
    switch (mealType) {
      case 'Breakfast':
        return 0;
      case 'Lunch':
        return 1;
      case 'Dinner':
        return 2;
      case 'Snack':
        return 3;
      default:
        return 4;
    }
  }

  Color _getMealScoreColor(double score) {
    if (score >= 80) {
      return Colors.green;
    } else if (score >= 60) {
      return Colors.amber;
    } else {
      return Colors.red;
    }
  }

  Widget _buildWeightChart(List<Map<String, dynamic>> weightData) {
    // Create spots using array index for consistent spacing
    final spots = weightData.asMap().entries.map((entry) {
      final index = entry.key;
      final data = entry.value;
      return FlSpot(
        index.toDouble(), // Use index instead of day for consistent spacing
        data['weight'],
      );
    }).toList();

    // Calculate optimal interval for bottom titles based on available space
    int getTitleInterval() {
      if (weightData.length <= 10) return 1;
      if (weightData.length <= 20) return 2;
      if (weightData.length <= 30) return 5;
      if (weightData.length <= 50) return 7;
      return 10;
    }

    // Calculate weight range for better Y-axis scaling
    double getMinWeight() {
      if (weightData.isEmpty) return 0;
      final weights = weightData.map((e) => e['weight'] as double).toList();
      final minWeight = weights.reduce((a, b) => a < b ? a : b);
      return (minWeight - 5)
          .clamp(0, double.infinity); // 5kg buffer below minimum
    }

    double getMaxWeight() {
      if (weightData.isEmpty) return 100;
      final weights = weightData.map((e) => e['weight'] as double).toList();
      final maxWeight = weights.reduce((a, b) => a > b ? a : b);
      return maxWeight + 5; // 5kg buffer above maximum
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
            ),
            dotData: FlDotData(show: true),
          ),
        ],
        minX: 0,
        maxX: weightData.isNotEmpty ? (weightData.length - 1).toDouble() : 0,
        minY: getMinWeight(),
        maxY: getMaxWeight(),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: getTitleInterval().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < weightData.length) {
                  final day = weightData[index]['day'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'D$day', // Shorter label format
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                }
                return Container();
              },
              reservedSize: 35, // Increased reserved space
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45, // Increased reserved space for weight labels
              interval: (getMaxWeight() - getMinWeight()) / 5, // 5 intervals
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toStringAsFixed(1)}kg',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        gridData: FlGridData(
          show: true,
          horizontalInterval: (getMaxWeight() - getMinWeight()) / 5,
          verticalInterval: getTitleInterval().toDouble(),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blue.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                final data = weightData[index];
                final date = DateFormat('MMM d').format(data['date']);
                return LineTooltipItem(
                  'Day ${data['day']} ($date)\nWeight: ${data['weight'].toStringAsFixed(1)} kg',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExerciseTypeChart(Map<String, int> exerciseTypeCount) {
    final pieData = exerciseTypeCount.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        color: _getExerciseTypeColor(entry.key),
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: pieData,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Color _getExerciseTypeColor(String exerciseType) {
    exerciseType = exerciseType.toLowerCase();
    if (exerciseType.contains('run') || exerciseType.contains('cardio')) {
      return Colors.redAccent;
    } else if (exerciseType.contains('weight') ||
        exerciseType.contains('strength')) {
      return Colors.blueAccent;
    } else if (exerciseType.contains('yoga') ||
        exerciseType.contains('stretch')) {
      return Colors.purpleAccent;
    } else if (exerciseType.contains('swim')) {
      return Colors.cyanAccent;
    } else if (exerciseType.contains('walk')) {
      return Colors.greenAccent;
    } else {
      // Generate a random color for unknown exercise types
      return Colors.primaries[exerciseType.hashCode % Colors.primaries.length];
    }
  }

  IconData _getExerciseIcon(String exerciseType) {
    exerciseType = exerciseType.toLowerCase();
    if (exerciseType.contains('run') || exerciseType.contains('jog')) {
      return Icons.directions_run;
    } else if (exerciseType.contains('weight') ||
        exerciseType.contains('strength')) {
      return Icons.fitness_center;
    } else if (exerciseType.contains('yoga') ||
        exerciseType.contains('stretch')) {
      return Icons.self_improvement;
    } else if (exerciseType.contains('swim')) {
      return Icons.pool;
    } else if (exerciseType.contains('walk')) {
      return Icons.directions_walk;
    } else if (exerciseType.contains('bike') ||
        exerciseType.contains('cycling')) {
      return Icons.directions_bike;
    } else {
      return Icons.sports;
    }
  }

  Widget _buildSkillTimeChart(Map<String, int> totalMinutesBySkill) {
  // Handle empty data case
  if (totalMinutesBySkill.isEmpty) {
    return Container(
      height: 200,
      child: Center(
        child: Text(
          'No skill data available',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
        ),
      ),
    );
  }

  // Sort skills by time spent (descending) for better visualization
  final sortedEntries = totalMinutesBySkill.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  // Create bar chart data with consistent indexing
  final data = <BarChartGroupData>[];
  final skillNameMap = <int, String>{};
  
  for (int i = 0; i < sortedEntries.length; i++) {
    final entry = sortedEntries[i];
    skillNameMap[i] = entry.key;
    
    data.add(BarChartGroupData(
      x: i,
      barRods: [
        BarChartRodData(
          toY: entry.value / 60.0, // Convert minutes to hours
          color: Colors.primaries[i % Colors.primaries.length],
          width: 16,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
          ),
        ),
      ],
    ));
  }

  // Calculate max Y value for better chart scaling
  final maxMinutes = sortedEntries.first.value;
  final maxHours = (maxMinutes / 60.0) * 1.2; // Add 20% padding

  return Container(
    height: 300, // Fixed height for consistency
    child: BarChart(
      BarChartData(
        alignment: BarChartAlignment.center,
        maxY: maxHours,
        barGroups: data,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= skillNameMap.length) {
                  return const SizedBox.shrink();
                }
                
                String skillName = skillNameMap[index] ?? '';
                
                // Smart truncation based on available space
                if (skillName.length > 8) {
                  // Try to break at word boundaries for better readability
                  final words = skillName.split(' ');
                  if (words.length > 1 && words[0].length <= 8) {
                    skillName = words[0];
                  } else {
                    skillName = '${skillName.substring(0, 6)}...';
                  }
                }
                
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    skillName,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
              reservedSize: 35,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return const Text('0h', style: TextStyle(fontSize: 10));
                }
                
                // Show titles at reasonable intervals
                final interval = _calculateYAxisInterval(maxHours);
                if (value % interval == 0) {
                  return Text(
                    '${value.toInt()}h',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          horizontalInterval: _calculateYAxisInterval(maxHours),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey[300],
              strokeWidth: 1,
            );
          },
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final skillName = skillNameMap[group.x] ?? '';
              final hours = rod.toY;
              final minutes = (hours * 60).round();
              
              return BarTooltipItem(
                '$skillName\n${hours.toStringAsFixed(1)}h (${minutes}m)',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

// Helper function to calculate appropriate Y-axis intervals
double _calculateYAxisInterval(double maxValue) {
  if (maxValue <= 5) return 1;
  if (maxValue <= 10) return 2;
  if (maxValue <= 25) return 5;
  if (maxValue <= 50) return 10;
  return 20;
}

  Widget _buildMoodDistributionChart(Map<String, int> moodFrequency) {
    final pieData = moodFrequency.entries.map((entry) {
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${entry.key}\n${entry.value}',
        color: _getMoodColor(entry.key),
        radius: 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: pieData,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  Color _getMoodColor(String mood) {
    mood = mood.toLowerCase();
    if (mood.contains('happy') ||
        mood.contains('great') ||
        mood.contains('excellent')) {
      return Colors.green;
    } else if (mood.contains('good') || mood.contains('positive')) {
      return Colors.lightGreen;
    } else if (mood.contains('neutral') ||
        mood.contains('okay') ||
        mood.contains('fine')) {
      return Colors.amber;
    } else if (mood.contains('tired') || mood.contains('exhausted')) {
      return Colors.orange;
    } else if (mood.contains('sad') ||
        mood.contains('bad') ||
        mood.contains('negative')) {
      return Colors.redAccent;
    } else if (mood.contains('stress') || mood.contains('anxious')) {
      return Colors.deepPurple;
    } else {
      // Default color for other moods
      return Colors.grey;
    }
  }

  Widget _buildRatingOverTimeChart(List<Map<String, dynamic>> progressLogs) {
    // Create spots using array index for consistent spacing
    final spots = progressLogs.asMap().entries.map((entry) {
      final index = entry.key;
      final log = entry.value;
      return FlSpot(
        index.toDouble(), // Use index instead of day for consistent spacing
        log['rating'].toDouble(),
      );
    }).toList();

    // Calculate optimal interval for bottom titles based on available space
    int getTitleInterval() {
      if (progressLogs.length <= 10) return 1;
      if (progressLogs.length <= 20) return 2;
      if (progressLogs.length <= 30) return 5;
      if (progressLogs.length <= 50) return 7;
      return 10;
    }

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.purple,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.purple.withOpacity(0.2),
            ),
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final log = progressLogs[index];
                return FlDotCirclePainter(
                  radius: 4,
                  color: _getMoodColor(log['mood']),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
          ),
        ],
        minX: 0,
        maxX:
            progressLogs.isNotEmpty ? (progressLogs.length - 1).toDouble() : 0,
        minY: 0,
        maxY: 5,
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: getTitleInterval().toDouble(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < progressLogs.length) {
                  final day = progressLogs[index]['day'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'D$day', // Shorter label format
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                }
                return Container();
              },
              reservedSize: 35, // Increased reserved space
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1, // Show every rating level (1, 2, 3, 4, 5)
              getTitlesWidget: (value, meta) {
                if (value.toInt() == value && value >= 0 && value <= 5) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return Container();
              },
            ),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        gridData: FlGridData(
          show: true,
          horizontalInterval: 1,
          verticalInterval: getTitleInterval().toDouble(),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.purple.withOpacity(0.8),
            getTooltipItems: (List<LineBarSpot> touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.spotIndex;
                final log = progressLogs[index];
                final date = DateFormat('MMM d').format(log['date']);
                return LineTooltipItem(
                  'Day ${log['day']} ($date)\nMood: ${log['mood']}\nRating: ${log['rating']}/5',
                  const TextStyle(color: Colors.white),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}
