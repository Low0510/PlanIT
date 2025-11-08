import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/utils/task_analytics.dart';

class AiAnalyzer {
  // Make this a singleton for better resource management
  static final AiAnalyzer _instance = AiAnalyzer._internal();
  factory AiAnalyzer() => _instance;
  AiAnalyzer._internal();

  // Cache the API key to avoid unnecessary Firestore reads
  String? _cachedApiKey;

  // Add configurable timeout
  final Duration timeout = Duration(seconds: 30);

  // Get API key from Firebase or use cached key
  Future<String?> _getApiKey() async {
    if (_cachedApiKey != null) return _cachedApiKey;

    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      User? user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        print('Error: User not authenticated');
        return null;
      }

      final userData = await _firestore.collection('users').doc(user.uid).get();
      final geminiKey = userData.data()?['geminiApiKey'];

      if (geminiKey == null || geminiKey.toString().isEmpty) {
        print('Error: Gemini API key not found in user data');
        return null;
      }

      _cachedApiKey = geminiKey.toString();
      return _cachedApiKey;
    } catch (e) {
      print('Error fetching API key: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> analyzeNutrition(File imageFile) async {
    try {
      // Get API key
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        return {
          'success': false,
          'message': 'Failed to analyze image: API key not available'
        };
      }

      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Gemini API endpoint for the gemini-2.5-flash-lite model
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite-preview-06-17:generateContent?key=$apiKey';

      // Enhanced prompt for better nutrition analysis
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    """Analyze this food image and provide a detailed nutritional breakdown in the following JSON format:
{
  "name": "Food name",
  "ingredients": ["ingredient1", "ingredient2", ...],
  "nutrition": {
    "calories": number,
    "protein": number (g),
    "carbs": number (g),
    "fat": number (g),
    "fiber": number (g),
    "sugar": number (g)
  },
  "nutritionScore": number (1-10),
  "healthBenefits": ["benefit1", "benefit2", ...],
  "cautions": ["caution1", "caution2", ...] // if applicable
}

For the nutritionScore, use this balanced 1-10 scale:

9-10: Exceptional - Superfoods, very nutrient-dense whole foods (quinoa bowls, kale salads, salmon)
7-8: Very Good - Healthy whole foods with good nutritional balance (grilled chicken with vegetables, oatmeal with fruits)
5-6: Good/Moderate - Generally healthy but may have some processed elements or higher calories (homemade pizza with vegetables, pasta with lean protein)
3-4: Fair - Some nutritional value but higher in calories, sodium, or contains processed ingredients (restaurant meals, sandwiches)
1-2: Poor - Highly processed, very high sugar/fat, minimal nutritional value (candy, deep-fried foods, sugary desserts)

Consider these factors for scoring:
- Presence of vegetables, fruits, whole grains, lean proteins (+points)
- Cooking method (grilled, baked, steamed vs. fried)
- Portion size and balance of macronutrients
- Level of processing (homemade vs. packaged vs. fast food)
- Added sugars and sodium content
- Overall nutritional density

Be generous with scores 5-8 for typical home-cooked meals and restaurant dishes that include some healthy components. Reserve very low scores (1-3) only for obviously unhealthy items like candy, deep-fried foods, or extremely processed snacks.

Ensure the response is ONLY in the specified JSON format with no additional text."""
              },
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image}
              }
            ]
          }
        ],
        "generation_config": {
          "temperature": 0.1,
          "top_p": 0.95,
          "top_k": 32,
          "max_output_tokens": 1024
        }
      };

      // Send the request with timeout
      final response = await http
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('The request timed out');
      });

      if (response.statusCode == 200) {
        // Parse the Gemini response
        final responseData = jsonDecode(response.body);

        // Safely access the parts array
        if (responseData.containsKey('candidates') &&
            responseData['candidates'] is List &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0].containsKey('content') &&
            responseData['candidates'][0]['content'].containsKey('parts') &&
            responseData['candidates'][0]['content']['parts'] is List &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty &&
            responseData['candidates'][0]['content']['parts'][0]
                .containsKey('text')) {
          final analysisText =
              responseData['candidates'][0]['content']['parts'][0]['text'];

          // Try to parse the returned JSON
          try {
            // Extract JSON if there's any surrounding text (shouldn't be, but just in case)
            final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(analysisText);
            final jsonStr =
                jsonMatch != null ? jsonMatch.group(0) : analysisText;

            final nutritionData = jsonDecode(jsonStr);
            return {'success': true, 'data': nutritionData};
          } catch (e) {
            print('Error parsing nutrition data: $e');
            return {
              'success': false,
              'message': 'Failed to parse nutrition data',
              'rawResponse': analysisText
            };
          }
        } else {
          print('Unexpected response format: ${response.body}');
          return {
            'success': false,
            'message': 'Failed to analyze image: Unexpected response format'
          };
        }
      } else {
        print(
            'Error from Gemini API: ${response.statusCode} - ${response.body}');

        // More helpful error handling
        String errorMessage =
            'Failed to analyze image. Error: ${response.statusCode}';

        try {
          final errorData = jsonDecode(response.body);
          if (errorData.containsKey('error') &&
              errorData['error'].containsKey('message')) {
            errorMessage = 'API Error: ${errorData['error']['message']}';
          }
        } catch (_) {
          // If we can't parse the error, use the default message
        }

        return {'success': false, 'message': errorMessage};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Analysis timed out. Please try again.'
      };
    } catch (e) {
      print('Exception when analyzing image: $e');
      return {
        'success': false,
        'message': 'Failed to analyze image: ${e.toString()}'
      };
    }
  }

  Future<Map<String, dynamic>> analyzeTimetable(File imageFile) async {
    try {
      // Get API key
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        return {
          'success': false,
          'message': 'Failed to analyze timetable: API key not available'
        };
      }

      // Get today's date in the required format
      final today = DateFormat('yyyy/MM/dd').format(DateTime.now());

      // Convert image to base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Gemini API endpoint for the gemini-2.5-flash-lite model
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite-preview-06-17:generateContent?key=$apiKey';

      // Timetable analysis prompt
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    """You are PlanIT, a highly precise data extraction assistant. Your single goal is to analyze the provided timetable image
                    and convert every event into a JSON array of formatted command strings.

Follow these steps precisely:
1.  **Identify Events:** Locate every colored block in the timetable that represents a scheduled event.
2.  **Extract Details:** For each event, extract its date, start time, and description.
3.  **Construct Command String:** For each event, create a single command string by assembling the extracted details according to the strict format below.
4.  **Format Final Output:** Combine all the generated command strings into a single, valid JSON array.

**Command String Construction Rules (Follow Exactly):**
Each string in the output array MUST follow this rigid structure:
`add <date> <time> <category> <priority> <task_description>`

*   **`add`**: The string must start with the literal word `add` followed by a single space.
*   **`<date>`**: Find the date in the event's row (e.g., `2025-06-23`) and reformat it as `YYYY/MM/DD`. So `2025-06-23` becomes `2025/06/23`.
*   **`<time>`**: Use only the event's **start time**. For a range like "8:00 AM - 10:00 AM", use `08:00`. For "12:30 PM - 2:00 PM", use `12:30`.
*   **`<category>`**: All these are academic classes, so you must use the word `Work`.
*   **`<priority>`**: You must use the word `medium`.
*   **`<task_description>`**: Use the subject code and its type, like `AJEL1713 (T)` or `AMIT1733 (P) E-learning`.

**Crucial Output Constraints:**
*   Accurately count every event. If there are 11 event blocks in the image, your final JSON array must contain exactly 11 command strings.
*   The final output MUST BE ONLY a valid JSON array of strings. Do not include any other text, explanations, or markdown formatting like ```json.

**Example of a correctly formatted string from the image:**
`"add 2025/06/23 08:00 Work medium AJEL1713 (T)"`

**Example of the final JSON array structure:**
[
  "add 2025/06/23 08:00 Work medium AJEL1713 (T)",
  "add 2025/06/23 12:30 Work medium ABFA1153 (T)",
  ...
]
"""
              },
              {
                "inline_data": {"mime_type": "image/jpeg", "data": base64Image}
              }
            ]
          }
        ],
        "generation_config": {
          "temperature": 0.1,
          "top_p": 0.95,
          "top_k": 32,
          "max_output_tokens": 2048
        }
      };

      // Send the request with timeout
      final response = await http
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('The request timed out');
      });

      if (response.statusCode == 200) {
        // Parse the Gemini response
        final responseData = jsonDecode(response.body);

        // Safely access the parts array
        if (responseData.containsKey('candidates') &&
            responseData['candidates'] is List &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0].containsKey('content') &&
            responseData['candidates'][0]['content'].containsKey('parts') &&
            responseData['candidates'][0]['content']['parts'] is List &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty &&
            responseData['candidates'][0]['content']['parts'][0]
                .containsKey('text')) {
          final analysisText =
              responseData['candidates'][0]['content']['parts'][0]['text'];

          // Try to parse the returned array of commands
          try {
            // Extract JSON array if there's any surrounding text
            final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(analysisText);
            final jsonStr =
                jsonMatch != null ? jsonMatch.group(0) : analysisText;

            final taskCommands = jsonDecode(jsonStr);
            if (taskCommands is! List) {
              throw FormatException('Expected array of task commands');
            }

            return {'success': true, 'commands': taskCommands};
          } catch (e) {
            print('Error parsing timetable data: $e');
            return {
              'success': false,
              'message': 'Failed to parse timetable data',
              'rawResponse': analysisText
            };
          }
        } else {
          print('Unexpected response format: ${response.body}');
          return {
            'success': false,
            'message': 'Failed to analyze timetable: Unexpected response format'
          };
        }
      } else {
        print(
            'Error from Gemini API: ${response.statusCode} - ${response.body}');

        // More helpful error handling
        String errorMessage =
            'Failed to analyze timetable. Error: ${response.statusCode}';

        try {
          final errorData = jsonDecode(response.body);
          if (errorData.containsKey('error') &&
              errorData['error'].containsKey('message')) {
            errorMessage = 'API Error: ${errorData['error']['message']}';
          }
        } catch (_) {
          // If we can't parse the error, use the default message
        }

        return {'success': false, 'message': errorMessage};
      }
    } on TimeoutException {
      return {
        'success': false,
        'message': 'Analysis timed out. Please try again.'
      };
    } catch (e) {
      print('Exception when analyzing timetable: $e');
      return {
        'success': false,
        'message': 'Failed to analyze timetable: ${e.toString()}'
      };
    }
  }

  // Helper method to get a human-readable summary from the nutrition data
  String getReadableSummary(Map<String, dynamic> nutritionData) {
    if (!nutritionData.containsKey('data')) {
      return nutritionData['message'] ?? 'Analysis failed';
    }

    final data = nutritionData['data'];
    final name = data['name'] ?? 'Unknown food';
    final score = data['nutritionScore'] ?? 0;
    final calories = data['nutrition']?['calories'] ?? 0;

    String scoreDescription;
    if (score >= 7) {
      scoreDescription = 'healthy';
    } else if (score >= 4) {
      scoreDescription = 'moderately nutritious';
    } else {
      scoreDescription = 'less nutritious';
    }

    final benefits =
        (data['healthBenefits'] as List?)?.take(2).join(', ') ?? '';

    return '📊 $name (${score}/10): $calories calories, $scoreDescription' +
        (benefits.isNotEmpty ? '\n✅ Benefits: $benefits' : '');
  }

  Future<String> generateInteractiveTTSForGet(
      Map<String, List<Map<String, String>>> tasksByCategory,
      String summarizedContent,
      String language,
      String functionType) async { // Added functionType parameter
    try {
      // Get API key
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        return functionType == 'schedule' 
            ? 'I found some tasks in your schedule. Let me read them for you.'
            : 'I found some relevant tasks. Let me tell you about them.';
      }

      // Create a structured task summary to send to the LLM
      final taskSummary = _createTaskSummary(tasksByCategory);

      // Gemini API endpoint for the gemini-2.0-flash-lite model
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$apiKey';

      // Generate contextual prompt based on function type
      String promptText = _generateContextualPrompt(functionType, language, taskSummary, summarizedContent);

      // Prompt to generate interactive TTS response
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text": promptText
              }
            ]
          }
        ],
        "generation_config": {
          "temperature": 0.4,
          "top_p": 0.95,
          "top_k": 32,
          "max_output_tokens": 256
        }
      };

      // Send the request with timeout
      final response = await http
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(timeout, onTimeout: () {
        throw TimeoutException('The request timed out');
      });

      if (response.statusCode == 200) {
        // Parse the Gemini response
        final responseData = jsonDecode(response.body);

        // Safely access the text response
        if (responseData.containsKey('candidates') &&
            responseData['candidates'] is List &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0].containsKey('content') &&
            responseData['candidates'][0]['content'].containsKey('parts') &&
            responseData['candidates'][0]['content']['parts'] is List &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty &&
            responseData['candidates'][0]['content']['parts'][0]
                .containsKey('text')) {
          final speechText =
              responseData['candidates'][0]['content']['parts'][0]['text'];
          return speechText;
        } else {
          print('Unexpected response format: ${response.body}');
          return _createDefaultSpeechResponse(tasksByCategory, functionType);
        }
      } else {
        print(
            'Error from Gemini API: ${response.statusCode} - ${response.body}');
        return _createDefaultSpeechResponse(tasksByCategory, functionType);
      }
    } on TimeoutException {
      return _createDefaultSpeechResponse(tasksByCategory, functionType);
    } catch (e) {
      print('Exception when generating TTS content: $e');
      return _createDefaultSpeechResponse(tasksByCategory, functionType);
    }
  }

  // Generate contextual prompts based on function type
  String _generateContextualPrompt(String functionType, String language, String taskSummary, String summarizedContent) {
    final today = DateFormat('yyyy/MM/dd').format(DateTime.now());
    switch (functionType.toLowerCase()) {
      case 'schedule':
        return """You're a helpful schedule assistant. Create a natural-sounding brief for the user's daily schedule in ${language}.

Today's Schedule:
${taskSummary}

Additional context (if available):
${summarizedContent}

When creating your response:
- Keep it conversational and flowing (around 100 words)
- Present this as their day overview with phrases like "Your day starts with", "You have", "Later today"
- Prioritize time-sensitive and high-priority tasks
- Naturally group related activities and mention timing when relevant
- Adapt your tone to match the day's workload (energetic for busy days, calm for lighter schedules)
- Skip formal greetings and unnecessary explanations
- Use plain conversational text as this will be read aloud
- Include a brief encouraging note at the end about their productive day

Feel free to adjust based on context - be more detailed for busy days and briefer for lighter schedules. If there's weather info, mention it naturally if relevant to the day's activities.
Important: DO NOT include any special formatting like markdown, bullet points, or text styling. The output should be pure conversational text that will be read aloud.""";

      case 'search':
        return """You're a helpful task search assistant. Present the search results in a natural, conversational way in ${language} Today date is $today.

Search Results:
${taskSummary}

Additional context (if available):
${summarizedContent}

When creating your response:
- Keep it conversational and flowing (around 100 words)
- Start with phrases like "I found", "Here are the tasks that match", "Your search returned"
- Focus on the most relevant matches first
- Briefly explain what makes these tasks relevant to their search
- Group similar results naturally (by category, time, or priority)
- Mention the variety of results if they span different categories or time periods
- Skip formal greetings and unnecessary explanations
- Use plain conversational text as this will be read aloud
- End with an offer to help refine their search if needed

Important: DO NOT include any special formatting like markdown, bullet points, or text styling. The output should be pure conversational text that will be read aloud.""";

      default:
        return """You're a helpful assistant. Present these tasks naturally in ${language}.

Tasks:
${taskSummary}

Additional context (if available):
${summarizedContent}

When creating your response:
- Keep it conversational and flowing (around 100 words)
- Prioritize important tasks and naturally group related items
- Adapt your tone to match the nature of the tasks
- Skip formal greetings and unnecessary explanations
- Use plain conversational text as this will be read aloud
- Include a brief encouraging note at the end if appropriate

Feel free to adjust based on context - be more detailed for busy days and briefer for lighter schedules. If there's weather info, mention it naturally if relevant to the day's activities.
Important: DO NOT include any special formatting like markdown, bullet points, or text styling. The output should be pure conversational text that will be read aloud.""";
    }
  }

  // Helper method to create a structured task summary for the prompt
  String _createTaskSummary(
      Map<String, List<Map<String, String>>> tasksByCategory) {
    StringBuffer summary = StringBuffer();

    tasksByCategory.forEach((category, tasks) {
      summary.writeln('Category: $category');

      for (var task in tasks) {
        final time = task['time'] ?? 'Unknown time';
        final title = task['title'] ?? 'Untitled task';
        final priority = task['priority'] ?? 'medium';
        final status = task['status'] ?? '⏳';

        summary.writeln(
            '- $title (Time: $time, Priority: $priority, Status: $status)');
      }

      summary.writeln();
    });

    return summary.toString();
  }

  // Enhanced fallback method with function type support
  String _createDefaultSpeechResponse(
      Map<String, List<Map<String, String>>> tasksByCategory, 
      String functionType) {
    StringBuffer speech = StringBuffer();
    
    // Different openings based on function type
    switch (functionType.toLowerCase()) {
      case 'schedule':
        speech.writeln("Here's your schedule for today. ");
        break;
      case 'search':
        speech.writeln("Here are the tasks I found for you. ");
        break;
      default:
        speech.writeln("Here are your tasks. ");
        break;
    }

    // Count high priority tasks
    int highPriorityCount = 0;
    tasksByCategory.forEach((category, tasks) {
      for (var task in tasks) {
        if (task['priority'] == 'high') {
          highPriorityCount++;
        }
      }
    });

    if (highPriorityCount > 0) {
      speech.writeln(
          "You have $highPriorityCount high priority tasks to focus on. ");
    }

    // Add categories
    tasksByCategory.forEach((category, tasks) {
      if (functionType.toLowerCase() == 'search') {
        speech.writeln("In $category, I found ${tasks.length} matching tasks. ");
      } else {
        speech.writeln("For $category, you have ${tasks.length} tasks. ");
      }
    });

    // Different endings based on function type
    switch (functionType.toLowerCase()) {
      case 'schedule':
        speech.writeln("Good luck with your day!");
        break;
      case 'search':
        speech.writeln("Let me know if you need to search for something more specific!");
        break;
      default:
        speech.writeln("Have a productive day!");
        break;
    }
    
    return speech.toString();
  }

  Future<String> generateFreeTimeResponse(
      List<Map<String, DateTime>> freeSlots,
      DateTime targetDate,
      List<Task> tasks,
      String lastMessage,
      String language) async {
    try {
      // Get API key
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        return _createDefaultFreeTimeResponse(freeSlots, targetDate, tasks);
      }

      // Create structured data about free slots
      final freeSlotsData = _formatFreeSlotsData(freeSlots, targetDate);
      final tasksData = _formatTasksData(tasks);
      final dayName = DateFormat('EEEE, MMM d').format(targetDate);

      // Gemini API endpoint
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$apiKey';

      // Prompt for generating free time response
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    """Help the user plan their free time on ${dayName} in ${language}.

Available free time:
${freeSlotsData}

Current commitments:
${tasksData}

User's recent message:
${lastMessage}

When responding:
- Keep it conversational and under 120 words
- If the user mentioned a specific activity (like badminton, reading, gym):
  * Suggest the best time slot that fits the activity's typical duration and timing needs
  * Offer a backup option if available
- If no specific activity was mentioned:
  * Highlight the most substantial free blocks first
  * Suggest 1-2 fitting activities based on the time available
- "✅" represent the task done, "⏳" represent the task still pending, categorize the done tasks together
- Characterize their day naturally (busy with brief breaks, scattered free moments, or generous free time)
- Reference their message context for personalized suggestions
- Consider morning vs evening appropriateness for activities
- Close with a practical suggestion or planning question
- Use a friendly, helpful tone without excessive enthusiasm

Remember this will be spoken aloud, so keep it flowing naturally without special formatting.
"""
              }
            ]
          }
        ],
        "generation_config": {
          "temperature": 0.4,
          "top_p": 0.95,
          "top_k": 32,
          "max_output_tokens": 300
        }
      };

      // Send the request with timeout
      final response = await http
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('The request timed out');
      });

      if (response.statusCode == 200) {
        // Parse the Gemini response
        final responseData = jsonDecode(response.body);
        // Safely access the text response
        if (responseData.containsKey('candidates') &&
            responseData['candidates'] is List &&
            responseData['candidates'].isNotEmpty &&
            responseData['candidates'][0].containsKey('content') &&
            responseData['candidates'][0]['content'].containsKey('parts') &&
            responseData['candidates'][0]['content']['parts'] is List &&
            responseData['candidates'][0]['content']['parts'].isNotEmpty &&
            responseData['candidates'][0]['content']['parts'][0]
                .containsKey('text')) {
          final responseText =
              responseData['candidates'][0]['content']['parts'][0]['text'];
          return responseText;
        } else {
          print('Unexpected response format: ${response.body}');
          return _createDefaultFreeTimeResponse(freeSlots, targetDate, tasks);
        }
      } else {
        print(
            'Error from Gemini API: ${response.statusCode} - ${response.body}');
        return _createDefaultFreeTimeResponse(freeSlots, targetDate, tasks);
      }
    } on TimeoutException {
      return _createDefaultFreeTimeResponse(freeSlots, targetDate, tasks);
    } catch (e) {
      print('Exception when generating free time content: $e');
      return _createDefaultFreeTimeResponse(freeSlots, targetDate, tasks);
    }
  }

// Helper function to format free slots data for the prompt
  String _formatFreeSlotsData(
      List<Map<String, DateTime>> freeSlots, DateTime date) {
    if (freeSlots.isEmpty) {
      return "No free slots available for the day.";
    }

    final buffer = StringBuffer();
    for (var slot in freeSlots) {
      final startTime = DateFormat('h:mm a').format(slot['start']!);
      final endTime = DateFormat('h:mm a').format(slot['end']!);
      final duration = slot['end']!.difference(slot['start']!).inMinutes;
      final durationStr = duration >= 60
          ? '${duration ~/ 60}h ${duration % 60}m'
          : '${duration}m';

      buffer.writeln("- $startTime to $endTime ($durationStr)");
    }
    return buffer.toString();
  }

// Helper function to format tasks data for the prompt
  String _formatTasksData(List<Task> tasks) {
    if (tasks.isEmpty) {
      return "No tasks scheduled for the day.";
    }

    tasks.sort((a, b) => a.time.compareTo(b.time));
    final buffer = StringBuffer();
    for (var task in tasks) {
      final time = DateFormat('h:mm a').format(task.time);
      buffer.writeln("- $time: ${task.title}");
    }
    return buffer.toString();
  }

// Create a default response if the API call fails
  String _createDefaultFreeTimeResponse(List<Map<String, DateTime>> freeSlots,
      DateTime targetDate, List<Task> tasks) {
    if (freeSlots.isEmpty) {
      return "You don't have any free time slots for ${DateFormat('EEEE, MMM d').format(targetDate)}. Your schedule is fully booked.";
    }

    final largestSlot = freeSlots.reduce((a, b) {
      final aDuration = a['end']!.difference(a['start']!).inMinutes;
      final bDuration = b['end']!.difference(b['start']!).inMinutes;
      return aDuration > bDuration ? a : b;
    });

    final startTime = DateFormat('h:mm a').format(largestSlot['start']!);
    final endTime = DateFormat('h:mm a').format(largestSlot['end']!);
    final duration =
        largestSlot['end']!.difference(largestSlot['start']!).inMinutes;
    final durationStr = duration >= 60
        ? '${duration ~/ 60} hours and ${duration % 60} minutes'
        : '${duration} minutes';

    return "For ${DateFormat('EEEE, MMM d').format(targetDate)}, your largest free time slot is from $startTime to $endTime ($durationStr). You have a total of ${freeSlots.length} free slots throughout the day.";
  }

  Future<String> getEnhancedTaskInsights(
      AnalyticsData analyticsData, List<Task> tasks) async {
    try {
      // Get API key
      final apiKey = await _getApiKey();
      if (apiKey == null) {
        return '{"status":"error","message":"API key not available. Please check your settings."}';
      }

      // Format data for AI analysis
      final analysisData = _formatAnalyticsForAI(analyticsData, tasks);

      // Gemini API endpoint for the gemini-2.0-flash-lite model
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=$apiKey';

      // Create the prompt for task analysis
      final requestBody = {
        "contents": [
          {
            "parts": [
              {
                "text":
                    """Analyze this task productivity data from the past 7 days and provide deep, personalized insights.
TASK DATA:
$analysisData

Consider the following dimensions in your analysis:
- Patterns in task completion rates across different times of day
- Relationship between task complexity and completion time
- Categories of tasks where the user excels vs struggles
- Emotional states correlated with productive vs unproductive periods
- Task switching frequency and its impact on productivity
- Recurring blockers or productivity obstacles

Return a JSON object with the following structure:
{
  "summary": "A concise, personalized summary highlighting the most significant productivity patterns discovered in the data",
  "key_insights": [
    {
      "title": "Short descriptive title for this insight",
      "description": "Detailed explanation of the pattern found, with specific examples from the data",
      "impact": "How this pattern affects overall productivity"
    },
    // 2-3 more insights following same structure
  ],
  "emotional_patterns": {
    "positive_triggers": ["Specific factors that correlate with high productivity"],
    "negative_triggers": ["Specific factors that correlate with low productivity"]
  },
  "optimal_conditions": {
    "time_of_day": "The specific time ranges when the user is most productive",
    "task_types": ["Categories of tasks the user excels at during optimal times"],
    "environmental_factors": ["Any environmental conditions that correlate with peak performance"]
  },
  "actionable_recommendations": [
    {
      "recommendation": "Specific, tailored action based on the data analysis",
      "expected_benefit": "Why this would improve productivity based on observed patterns",
      "implementation": "Simple, concrete first step to implement this change"
    },
    // 2-3 more recommendations following same structure
  ]
}

Important guidelines:
1. Provide specific insights based on patterns in THIS specific dataset, not generic productivity advice
2. Highlight unexpected or non-obvious patterns in the data
3. Connect emotional states to productivity outcomes when possible
4. Make concrete recommendations that directly address the identified patterns
5. Use precise language and refer to specific metrics from the provided data
6. Focus on actionable insights that can lead to behavioral changes"""
              }
            ]
          }
        ],
        "generation_config": {
          "temperature": 0.3,
          "top_p": 0.95,
          "top_k": 40,
          "max_output_tokens": 1000,
          "response_mime_type": "application/json"
        }
      };

      // Send the request with timeout
      final response = await http
          .post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      )
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('The request timed out');
      });

      if (response.statusCode == 200) {
        // Parse the Gemini response
        final responseData = jsonDecode(response.body);

        // Safely access the text content
        if (responseData.containsKey('candidates') &&
            responseData['candidates'] is List &&
            responseData['candidates'].isNotEmpty) {
          final textContent = _extractTextFromResponse(responseData);
          return textContent;
        } else {
          print('Unexpected response format: ${response.body}');
          return '{"status":"error","message":"Unexpected response format from AI service."}';
        }
      } else {
        print(
            'Error from Gemini API: ${response.statusCode} - ${response.body}');
        return '{"status":"error","message":"API Error ${response.statusCode}"}';
      }
    } on TimeoutException {
      return '{"status":"error","message":"Analysis timed out. Please try again later."}';
    } catch (e) {
      print('Exception when generating insights: $e');
      return '{"status":"error","message":"${e.toString()}"}';
    }
  }

  String _extractTextFromResponse(Map<String, dynamic> responseData) {
    try {
      if (responseData['candidates'][0].containsKey('content') &&
          responseData['candidates'][0]['content'].containsKey('parts') &&
          responseData['candidates'][0]['content']['parts'] is List &&
          responseData['candidates'][0]['content']['parts'].isNotEmpty &&
          responseData['candidates'][0]['content']['parts'][0]
              .containsKey('text')) {
        return responseData['candidates'][0]['content']['parts'][0]['text'];
      }

      // Fallback JSON with error details
      return '{"status":"error","message":"Unable to extract content from API response"}';
    } catch (e) {
      return '{"status":"error","message":"Error parsing API response: ${e.toString()}"}';
    }
  }

  String _formatAnalyticsForAI(AnalyticsData analytics, List<Task> tasks) {
    // Create a structured representation of the analytics data for the AI
    final buffer = StringBuffer();

    buffer.writeln('PRODUCTIVITY METRICS:');
    buffer.writeln(
        '- Completion Rate: ${analytics.completionRate.toStringAsFixed(1)}%');
    buffer.writeln(
        '- Average Productivity Score: ${analytics.averageProductivity.toStringAsFixed(1)}/100');
    buffer.writeln(
        '- Average Completion Time: ${analytics.averageCompletionTime.toStringAsFixed(1)} hours');

    buffer.writeln('\nCATEGORY BREAKDOWN:');
    analytics.categoryDistribution.forEach((category, count) {
      buffer.writeln('- $category: $count tasks');
    });

    buffer.writeln('\nPRIORITY DISTRIBUTION:');
    analytics.priorityDistribution.forEach((priority, count) {
      buffer.writeln('- $priority: $count tasks');
    });

    buffer.writeln('\nEMOTIONAL DATA:');
    buffer.writeln('Emotional States During Task Completion:');
    analytics.emotionalTrends.forEach((emotion, percentage) {
      buffer.writeln('- $emotion: ${percentage.toStringAsFixed(1)}%');
    });

    if (analytics.emotionalProductivity.isNotEmpty) {
      buffer.writeln('\nProductivity by Emotional State:');
      analytics.emotionalProductivity.forEach((emotion, avgTime) {
        buffer.writeln(
            '- $emotion: ${avgTime.toStringAsFixed(1)} minutes avg completion time');
      });
    }

    buffer.writeln('\nTIME OF DAY PRODUCTIVITY:');
    analytics.timeOfDayDistribution.forEach((timeSlot, count) {
      buffer.writeln('- $timeSlot: $count tasks completed');
    });

    // Add details about done tasks
    buffer.writeln('\nRECENTLY COMPLETED TASKS (SAMPLE):');
    final allTasks = tasks.toList();
    if (allTasks.isNotEmpty) {
      for (int i = 0; i < math.min(5, allTasks.length); i++) {
        final task = allTasks[i];
        buffer.writeln('- Title: "${task.title}"');
        buffer.writeln('  Category: ${task.category}');
        buffer.writeln('  Priority: ${task.priority}');
        buffer.writeln(
            '  Due: ${task.time != null ? DateFormat('MMM d, yyyy').format(task.time!) : "No due date"}');
      }
    } else {
      buffer.writeln('- No upcoming tasks');
    }

    return buffer.toString();
  }

  Map<String, dynamic> parseInsightData(String jsonString) {
    try {
      // First attempt: try to parse as valid JSON
      return jsonDecode(jsonString);
    } catch (e) {
      // If parsing fails, try to extract JSON from text (in case the AI wrapped it in explanation)
      final regExp =
          RegExp(r'\{(?:[^{}]|(?:\{(?:[^{}]|(?:\{[^{}]*\}))*\}))*\}');
      final match = regExp.firstMatch(jsonString);

      if (match != null) {
        try {
          return jsonDecode(match.group(0)!);
        } catch (_) {
          // If nested JSON extraction fails, return a fallback object
        }
      }

      // Fallback: create a basic structure with the full text as summary
      return {
        'summary': jsonString.length > 300
            ? jsonString.substring(0, 300) + '...'
            : jsonString,
        'recommendations': [
          'Review your productivity patterns to identify optimal work times',
          'Consider balancing your task categories for better overall productivity',
          'Set clear priorities to focus on high-impact tasks'
        ]
      };
    }
  }
}
