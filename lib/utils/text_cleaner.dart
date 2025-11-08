class TextCleaner {
  static String removeDateAndTime(String text) {
    // Store original text to preserve case in final result
    final originalText = text;
    // Convert to lowercase only for pattern matching
    final lowercaseText = text.toLowerCase();
    
    // Relative dates and expressions
    final relativeDatePatterns = [
      'today',
      'tonight',
      'tomorrow',
      'day after tomorrow',
      'in 2 days',
      'in 3 days',
      'in 4 days',
      'in 5 days',
      'in a week',
      'in 1 week',
      'next week'
    ];
    
    // Weekdays with "next" prefix
    final weekdays = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    final weekdayPatterns = [
      ...weekdays,
      ...weekdays.map((day) => 'next $day'),
    ];
    
    // Time-related contextual words to remove
    final timeContextWords = [
      'at',
      'around',
      'by',
      'before',
      'after',
      'from',
      'until',
      'till',
      'between'
    ];
    
    // Time patterns with context word patterns
    // These patterns include both the context word and the time
    final timePatternStrings = [
      // Context word followed by time patterns
      ...timeContextWords.map((word) => '$word\\s+\\d{1,2}:\\d{2}\\s*(am|pm)?'),
      ...timeContextWords.map((word) => '$word\\s+\\d{1,2}\\.\\d{2}\\s*(am|pm)?'),
      ...timeContextWords.map((word) => '$word\\s+\\d{1,2}\\s*(am|pm)'),
      ...timeContextWords.map((word) => '$word\\s+\\d{2}:\\d{2}'),
      ...timeContextWords.map((word) => '$word\\s+\\d{1,2}\\b'),
      
      // Regular time patterns without context words
      '\\d{1,2}:\\d{2}\\s*(am|pm)?',
      '\\d{1,2}\\.\\d{2}\\s*(am|pm)?',
      '\\d{1,2}\\s*(am|pm)',
      '\\d{2}:\\d{2}',
      
      // Special cases with context words
      ...timeContextWords.map((word) => '$word\\s+(noon|midnight)'),
      '(noon|midnight)'
    ];
    
    final timePatterns = timePatternStrings.map((pattern) => RegExp(pattern, caseSensitive: false)).toList();
    
    // Track positions of all matches to remove
    final matches = <MapEntry<int, int>>[];
    
    // Find all matches for relative date patterns
    for (final pattern in relativeDatePatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final matchItems = regex.allMatches(lowercaseText);
      for (final match in matchItems) {
        matches.add(MapEntry(match.start, match.end));
      }
    }
    
    // Find all matches for weekday patterns
    for (final pattern in weekdayPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final matchItems = regex.allMatches(lowercaseText);
      for (final match in matchItems) {
        matches.add(MapEntry(match.start, match.end));
      }
    }
    
    // Find all matches for time patterns
    for (final pattern in timePatterns) {
      final matchItems = pattern.allMatches(lowercaseText);
      for (final match in matchItems) {
        matches.add(MapEntry(match.start, match.end));
      }
    }
    
    // Create safe version that avoids index errors
    String resultText = originalText;
    
    if (matches.isNotEmpty) {
      // Sort matches by start position to handle overlaps
      matches.sort((a, b) => a.key.compareTo(b.key));
      
      // Filter out overlapping matches
      final filteredMatches = <MapEntry<int, int>>[];
      MapEntry<int, int>? lastMatch;
      
      for (final match in matches) {
        if (lastMatch == null || match.key >= lastMatch.value) {
          filteredMatches.add(match);
          lastMatch = match;
        } else if (match.value > lastMatch.value) {
          // This match extends beyond the last one, so update the last match
          filteredMatches.removeLast();
          filteredMatches.add(MapEntry(lastMatch.key, match.value));
          lastMatch = MapEntry(lastMatch.key, match.value);
        }
      }
      
      // Sort in reverse order to preserve indices while removing
      filteredMatches.sort((a, b) => b.key.compareTo(a.key));
      
      // Remove all matches from the original text
      for (final match in filteredMatches) {
        // Safety check to ensure indices are within bounds
        if (match.key >= 0 && match.value <= resultText.length) {
          resultText = resultText.substring(0, match.key) + resultText.substring(match.value);
        }
      }
    }
    
    // Clean up extra spaces and trim
    resultText = resultText.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return resultText;
  }
}