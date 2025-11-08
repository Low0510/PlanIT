import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show TimeOfDay;

class SmartDateParserService {
  static DateTime? parseText(String input) {
    final text = input.toLowerCase().trim();
    final now = DateTime.now();
    DateTime? date;
    bool isTimeSpecified = false;

    // Handle relative dates
    if (_containsAny(text, ['today', 'tonight'])) {
      date = DateTime(now.year, now.month, now.day);
    } else if (_containsAny(text, ['tomorrow'])) {
      date = now.add(const Duration(days: 1));
    } else if (_containsAny(text, ['day after tomorrow'])) {
      date = now.add(const Duration(days: 2));
    }
    
    // Handle weekdays (both "next" and this week's)
    final weekdays = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    for (var entry in weekdays.entries) {
      if (text.contains('next ${entry.key}')) {
        date = _getNextWeekday(entry.value);
        break;
      } else if (text.contains(entry.key)) {
        // If just weekday is mentioned (without "next"), get the closest upcoming one
        date = _getClosestWeekday(entry.value);
        break;
      }
    }

    // Handle relative expressions
    final relativeDays = {
      'in 2 days': 2,
      'in 3 days': 3,
      'in 4 days': 4,
      'in 5 days': 5,
      'in a week': 7,
      'in 1 week': 7,
      'next week': 7,
    };

    for (var entry in relativeDays.entries) {
      if (text.contains(entry.key)) {
        date = now.add(Duration(days: entry.value));
        break;
      }
    }

    // If no date was detected, use today
    date ??= DateTime(now.year, now.month, now.day);

    // Handle different time formats
    final timePatterns = [
      // 10:30am, 10:30 am, 10:30 PM
      RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)', caseSensitive: false),
      // 10.30am, 10.30 am, 10.30 PM
      RegExp(r'(\d{1,2})\.(\d{2})\s*(am|pm)', caseSensitive: false),
      // 10am, 10 am, 10PM, 3pm, 2pm, 8am
      RegExp(r'(\d{1,2})\s*(am|pm)', caseSensitive: false),
      // 23:30, military time
      RegExp(r'(\d{2}):(\d{2})'),
      // at 3, at 15
      RegExp(r'at\s+(\d{1,2})\b'),
    ];

    DateTime? timeResult;
    for (var pattern in timePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        timeResult = _parseTimeMatch(match, date!);
        if (timeResult != null) {
          isTimeSpecified = true;
          date = timeResult;
          break;
        }
      }
    }

    // Handle special time cases
    if (text.contains('noon')) {
      date = DateTime(date!.year, date.month, date.day, 12);
      isTimeSpecified = true;
    } else if (text.contains('midnight')) {
      date = DateTime(date!.year, date.month, date.day);
      isTimeSpecified = true;
    }

     if (!isTimeSpecified) {
      date = DateTime(date!.year, date.month, date.day, 23, 59);
    }

    return date;
  }

  static bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  static DateTime _getNextWeekday(int targetDay) {
    final now = DateTime.now();
    int daysUntilTarget = targetDay - now.weekday;
    if (daysUntilTarget <= 0) daysUntilTarget += 7;
    return now.add(Duration(days: daysUntilTarget));
  }

  static DateTime _getClosestWeekday(int targetDay) {
    final now = DateTime.now();
    int daysUntilTarget = targetDay - now.weekday;
    if (daysUntilTarget <= 0) daysUntilTarget += 7;
    // If it's early in the day, consider today's weekday
    if (targetDay == now.weekday && now.hour < 12) {
      return now;
    }
    return now.add(Duration(days: daysUntilTarget));
  }

  static DateTime? _parseTimeMatch(RegExpMatch match, DateTime baseDate) {
    try {
      int hour = int.parse(match.group(1)!);
      int minute = 0;
      
      // Get the pattern as string to check its format
      final patternStr = match.pattern.toString();
      
      if (patternStr.contains(r':(\d{2})') || patternStr.contains(r'\.(\d{2})')) {
        // If the pattern includes minutes (HH:MM or HH.MM format)
        minute = int.parse(match.group(2)!);
        
        // AM/PM will be in group 3 if present
        if (patternStr.contains('am|pm')) {
          final isPM = match.group(3)!.toLowerCase() == 'pm';
          if (isPM && hour != 12) hour += 12;
          if (!isPM && hour == 12) hour = 0;
        }
      } else if (patternStr.contains('am|pm')) {
        // Simple time format (e.g., "3pm", "2pm", "8am")
        // AM/PM will be in group 2
        final isPM = match.group(2)!.toLowerCase() == 'pm';
        if (isPM && hour != 12) hour += 12;
        if (!isPM && hour == 12) hour = 0;
      } else if (hour >= 0 && hour < 24) {
        // Military time or 24-hour format
        // No conversion needed
      } else {
        // Invalid hour
        return null;
      }

      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        hour,
        minute,
      );
    } catch (e) {
      return null;
    }
  }

  static TimeOfDay? extractTimeOnly(String input) {
    final text = input.toLowerCase().trim();
    final now = DateTime.now();

    // Create a base date to work with
    final baseDate = DateTime(now.year, now.month, now.day);

    // Handle different time formats using existing patterns
    final timePatterns = [
      // 10:30am, 10:30 am, 10:30 PM
      RegExp(r'(\d{1,2}):(\d{2})\s*(am|pm)', caseSensitive: false),
      // 10.30am, 10.30 am, 10.30 PM
      RegExp(r'(\d{1,2})\.(\d{2})\s*(am|pm)', caseSensitive: false),
      // 10am, 10 am, 10PM, 3pm, 2pm, 8am
      RegExp(r'(\d{1,2})\s*(am|pm)', caseSensitive: false),
      // 23:30, military time
      RegExp(r'(\d{2}):(\d{2})'),
      // at 3, at 15
      RegExp(r'at\s+(\d{1,2})\b'),
    ];

    // Handle special time cases first
    if (text.contains('noon')) {
      return TimeOfDay(hour: 12, minute: 0);
    } else if (text.contains('midnight')) {
      return TimeOfDay(hour: 0, minute: 0);
    }

    // Try to match time patterns
    for (var pattern in timePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final parsedDateTime = _parseTimeMatch(match, baseDate);
        if (parsedDateTime != null) {
          return TimeOfDay(
              hour: parsedDateTime.hour, minute: parsedDateTime.minute);
        }
      }
    }

    return null;
  }
}
