class RepeatTaskParser {
  static String parseRepeatInterval(String input, int repeatedIntervalTime) {
    // Days of the week mapping
    const daysOfWeek = {
      '1': 'Monday',
      '2': 'Tuesday',
      '3': 'Wednesday',
      '4': 'Thursday',
      '5': 'Friday',
      '6': 'Saturday',
      '7': 'Sunday',
    };

    // Split the input string
    List<String> parts = input.split(',');

    // Extract repeat type (e.g., "weekly") and days (e.g., ["1", "2"])
    String repeatType = parts[0].trim();
    List<String> days =
        parts.sublist(1).map((day) => daysOfWeek[day.trim()] ?? '').toList();

    // Format the days into a readable string
    String daysString = days.isNotEmpty && days.any((day) => day.isNotEmpty)
        ? "every ${days.join(' and ')}"
        : "";

    // Add the repeated interval time with correct pluralization
    String intervalString = repeatedIntervalTime > 1
        ? "for $repeatedIntervalTime ${_getPluralForm(repeatType)}"
        : "";

    // Combine all parts into the final description
    return ["Repeat $repeatType", daysString, intervalString]
        .where((part) => part.isNotEmpty)
        .join(' ');
  }

  // Helper method to get the correct plural form
  static String _getPluralForm(String repeatType) {
    return switch (repeatType.toLowerCase()) {
      'daily' => 'days',
      'weekly' => 'weeks',
      'monthly' => 'months',
      'yearly' => 'years',
      _ => repeatType.replaceFirst('ly', 's'), // fallback for other cases
    };
  }
}