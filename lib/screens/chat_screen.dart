import "dart:async";
import "dart:math";
import "dart:ui";

import "package:animations/animations.dart";
import "package:connectivity_plus/connectivity_plus.dart";
import "package:dash_chat_2/dash_chat_2.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_tts/flutter_tts.dart";
import 'package:google_generative_ai/google_generative_ai.dart';
import "package:lottie/lottie.dart";
import "package:planit_schedule_manager/const.dart";
import 'package:cloud_firestore/cloud_firestore.dart';
import "package:planit_schedule_manager/models/task.dart";
import "package:planit_schedule_manager/models/weather_data.dart";
import "package:planit_schedule_manager/screens/task_details_screen.dart";
import "package:planit_schedule_manager/screens/timetable_screen.dart";
import "package:planit_schedule_manager/services/ai_analyzer.dart";
import "package:planit_schedule_manager/services/chat_service.dart";
import "package:planit_schedule_manager/services/location_service.dart";
import "package:planit_schedule_manager/services/network_service.dart";
import "package:planit_schedule_manager/services/schedule_service.dart";
import "package:planit_schedule_manager/services/weather_service.dart";
import "package:planit_schedule_manager/utils/task_delete_dialog.dart";
import "package:planit_schedule_manager/utils/weather_util.dart";
import "package:planit_schedule_manager/widgets/time_conflict_manager.dart";
import "package:planit_schedule_manager/widgets/toast.dart";
import "package:planit_schedule_manager/widgets/url_button.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:speech_to_text/speech_recognition_result.dart";
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final ChatMemoryService _chatMemoryService = ChatMemoryService();
  final ScheduleService _scheduleService = ScheduleService();

  User user = FirebaseAuth.instance.currentUser!;
  List<ChatMessage> messages = [];
  ChatUser currentUser = ChatUser(id: "0", firstName: "User");
  ChatUser scheduleBot = ChatUser(id: "1", firstName: "scheduleBot");
  late GenerativeModel _model;
  bool _isTyping = false;
  ChatSession? _chat;
  bool _isChatInitialized = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WeatherService _weatherService = WeatherService.getInstance(
      OPENWEATHER_API_KEY,
      cacheDurationInMinutes: 90);

  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  final TextEditingController _textController = TextEditingController();

  String _apiKey = '';
  final _apiKeyController = TextEditingController();

  FlutterTts _flutterTts = FlutterTts();
  Map? _currentVoice;
  bool _isTtsEnabled = false;
  bool _isSpeaking = false;

  String _currentLocale = 'en_US';

  final String chatCmd = """
From now on, you are PlanIT, a smart and structured scheduling assistant for task management, I will interpret what you say in Chinese or English and respond in the following format for managing tasks:

**Commands:**

*   **Task Management Response Format (MUST FOLLOW WITHOUT SAID UNECESSARY WORDS ESPECIALLY EDIT):**
    *   add <date> <time> <category> <priority> <task description> [<subtask1>, <subtask2>, ...]
    *   delete <date>
    *   delete <date> <time>
    *   delete <date> <important keywords>
    *   get <date>
    *   get <date> <time>
    *   find <date>
    *   search <search query>
    *   **Output for edit:**
            **delete <original_date> <original_time_if_any> <original_keywords_if_any>**
            **add <original_or_new_date> <original_or_new_time> <original_or_new_category> <original_or_new_priority> <original_or_new_description> [<original_or_new_subtasks>]** 
            *(Note: The two commands will be separated by a newline. Only include fields in the 'add' part that were present or modified. Preserve original details if not explicitly changed.)*

**Rules:**

1. **Date Conversion:**
    *   "today" or "tomorrow" will be converted to the exact date in yyyy-MM-dd format.
    *   Relative dates like "next month on the 5th" will be calculated and converted to yyyy-MM-dd format.

2. **Time Handling:**
    *   For **add** commands:
        *   If no time is mentioned, I will ask you to input the time in 24-hour HH:mm format.  If you unsure, you can also reply with something like “10 minutes later” or “in 2 hours”, I will convert it automatically
    *   For **get** and **delete** commands:
        *   If no time is mentioned, I will **assume you mean the entire day and will not ask for the time**.
    *   For **edit** commands:
        *   The time in the `add` part of the response should be in HH:mm. If the user wants to change the time, the new time should be used. Otherwise, the original time is preserved.

3. **Category Detection:**
    *   I will automatically detect the category of a task based on the description. The available categories are: "Personal," "Health," "Entertainment," "Work."
    *   If I can't recognize the category, I'll assign it to "Other."
    *   For **edit** commands, if the category is not being changed, the original category must be preserved in the `add` part of the response.

4. **Priority Detection:**
    *   I will automatically detect the priority of a task based on the description. The available priorities are: "High," "Medium," "Low", "None"
    *   If I can't recognize the priority, I'll assign it to "Medium."
    *   For **edit** commands, if the priority is not being changed, the original priority must be preserved in the `add` part of the response.

5. **Subtask Handling:**
    *   If a task includes subtasks, I will format them within square brackets and comma-separated after the main task description.
    *   For example: "add 2024-10-09 15:00 Work High Project meeting [Prepare slides, Bring project materials, Review last meeting notes]"
    *   If no subtasks are specified, I will not include any brackets in the output.
    *   For **edit** commands, if subtasks are not being changed, the original subtasks must be preserved. If they are changed (e.g., added, removed, modified), the new list of subtasks should be in the `add` part.

6. **Vague Requests:** 
    *  For vague requests, I will clarify the task and ask for details if something is missing, like the date or time.
    *  If a request includes a phrase like “eat apple 10 minutes later,” it will assume the time as 10 minutes from now.
    *  If the task description is unclear (e.g., *"Add a task on April 4"*), ask the user to specify the details before proceeding.  
    *  If a command is incomplete, prompt the user for missing information naturally without enforcing strict re-entry.  
    *  For **edit** commands, if the task to be edited is ambiguous (e.g., "edit my meeting"), I will ask for clarification (e.g., "Which meeting would you like to edit? Please specify the date and time or some keywords from the description.").

7. **Date and Time Format:**
    *   All dates will be in yyyy-MM-dd format.
    *   All times will be in 24-hour HH:mm format.

8. **Strict Command Handling:**
    *   Commands will strictly follow the formats specified above. I will not ask for unnecessary details unless explicitly required by the rules.

9. **Edit Command Logic:**
    *   When an `edit` command is issued, you must identify the task to be modified using the provided date, time, and/or keywords.
    *   You will then generate a `delete` command to remove the original task. This command should be specific enough to target the correct task.
    *   Subsequently, you will generate an `add` command to create the updated task.
    *   **Crucially, for the `add` command, you MUST carry over all details (date, time, category, priority, description, subtasks) from the original task UNLESS that specific detail is being explicitly changed by the user's edit request.**
    *   If the user says "edit the task I just added" or "edit the last task", you should refer to the most recent task contextually. You need to "remember" or infer the full details of that task to construct the correct `delete` and `add` commands.
    *   I will strictly follow the Date and Time Format

**Responses:**

*   **Greetings:**
    *   If you greet me, I will respond with a warm and friendly greeting, such as:
        *   "Nice to meet you! I'm the PlanIT chatbot assistant. How can I help you manage your schedule today?"
        *   "Hello there! I'm your PlanIT scheduling assistant. What tasks can I help you with?"

*   **Gratitude:**
    *   If you express gratitude, I will respond with a polite acknowledgment, such as: "You're welcome!" or "My pleasure!"

*   **Ending Chat:**
    *   If you say goodbye, I will respond with a closing message like: "Goodbye! Have a productive day!" or "See you later!"

*   **Help:**
    *   If you ask for help, I will respond with: "Here's what I can do for you:  

📅 **Task Management**  
- Add: Add a task to your schedule (you can include subtasks in square brackets)  
- Delete: Remove tasks for a specific date  
- Edit: Modify an existing task. I'll ask for details of the task and what you want to change.
- Get: Check your tasks  
- Find: Check for free time
- Search: Search related task

Need more details about a specific command? Just type the command name!"  

**Examples:**

You: "Hello"
Me: "Nice to meet you! I'm the PlanIT chatbot assistant. How can I help you manage your schedule today?"

You: "Remind me tomorrow to meet my FYP supervisor and prepare my research findings."
Me: "What time should I set this reminder?"
You: "3 PM"
Me: "add 2024-10-09 15:00 Work High meet FYP supervisor [Prepare research findings, Bring progress report, List questions to ask]"

You: "I need to work on my project tomorrow at 5 PM with steps to complete"
Me: "add 2024-10-09 17:00 Work Medium work on project [Create wireframes, Update documentation, Test functionality]"

You: "What tasks do I have today?"
Me: "get 2024-10-08"

You: "What should I do tomorrow 3PM?"
Me: "get 2024-10-08 15:00"

You: "Delete tomorrow's 5pm task"
Me: "delete 2024-10-09 17:00"

You: "Cancel my meeting with Mr Ng tomorrow 3pm"
Me: "delete 2024-10-09 15:00 meeting Mr Ng"

You: "Delete my meeting with Mr Low tomorrow"
Me: "delete 2024-10-09 meeting Mr Low"

You: "What time do I free tomorrow?"
Me: "find 2025-01-01"

You: "When did I need go to school?"
Me: "search go to school"

**--- Edit Examples ---**
You: "The FYP supervisor meeting tomorrow at 3 PM, change its priority to Medium."
Me:
delete 2024-10-09 15:00 meet FYP supervisor
add 2024-10-09 15:00 Work Medium meet FYP supervisor [Prepare research findings, Bring progress report, List questions to ask]

You: "For the project work tomorrow at 5 PM, change the description to 'Finalize project deliverables' and remove subtask 'Create wireframes'."
Me:
delete 2024-10-09 17:00 work on project
add 2024-10-09 17:00 Work Medium Finalize project deliverables [Update documentation, Test functionality]

You: "Actually, the task I just added about project work, move it to 6 PM."
Me: (Assuming the last task was "add 2024-10-09 17:00 Work Medium Finalize project deliverables [Update documentation, Test functionality]")
delete 2024-10-09 17:00 Finalize project deliverables
add 2024-10-09 18:00 Work Medium Finalize project deliverables [Update documentation, Test functionality]

You: "Edit my task 'dentist appointment' on 2024-11-20. Change time from 10:00 to 11:00 and add subtask 'bring insurance card'."
Me: (Assuming original task was "add 2024-11-20 10:00 Personal Medium dentist appointment")
delete 2024-11-20 10:00 dentist appointment
add 2024-11-20 11:00 Personal Medium dentist appointment [bring insurance card]
**--- End Edit Examples ---**

You: "Thank you"
Me: "You're welcome!"

You: "Bye"
Me: "Goodbye! Have a productive day!"

I will strictly follow these rules to response. All the responses I gave only will be plain text without any markdown format.
""";

  late AnimationController _micAnimationController;
  late Animation<double> _micAnimation;
  bool _isAnimationDisposed = false;

  final NetworkService _networkService = NetworkService();
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOnline = true;

  AiAnalyzer _aiAnalyzer = AiAnalyzer();

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _subscribeToConnectivity();

    initAsync();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    if (!_isAnimationDisposed) {
      _micAnimationController.dispose();
      _isAnimationDisposed = true;
    }
    _textController.dispose();

    stopTts();
    _flutterTts.stop();
    super.dispose();
  }

  // ---------------------- Initialization ----------------------------------

  Future<void> initAsync() async {
    await _initializeGeminiModel();
    _initializeAnimationController();
    _initSpeech();
    _initTts();
    _initializeChat();
    _loadMessages();
    _loadLanguagePreference();
    _loadTtsPreference();
  }

  Future<void> _initializeGeminiModel() async {
    try {
      final userData = await _firestore.collection('users').doc(user.uid).get();
      final geminiKey = userData.data()?['geminiApiKey'];

      if (geminiKey != null &&
          geminiKey.toString().isNotEmpty &&
          geminiKey.toString().length > 15) {
        _apiKey = geminiKey.toString();
      } else {
        _apiKey = GEMINI_API_KEY;
      }

      _model = GenerativeModel(
        // model: 'gemini-1.5-flash-8b',
        model: 'gemini-2.0-flash-lite',
        apiKey: _apiKey,
        // apiKey: GEMINI_API_KEY
      );

      print('Gemini KEY: ' + _apiKey);
    } catch (e) {
      print('Error initializing Gemini model: $e');
    }
  }

  // ---------------- Initialize Text To Speech ----------------

  void _initTts() {
    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
        });
      }
    });

    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
      print("TTS Error: $msg");
    });

    _flutterTts.setCancelHandler(() {
      // Important for explicit stops
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    });

    _flutterTts.getVoices.then((data) {
      try {
        List voices = List.from(data);
        String language;
        if (_currentLocale == 'zh_CN') {
          language = 'zh';
        } else if (_currentLocale == 'ms_MY') {
          language = 'ms';
        } else {
          language = 'en';
        }
        voices = voices
            .where((voice) =>
                voice["locale"].toLowerCase().contains(language.toLowerCase()))
            .toList();
        print("Filtered voices for $language: $voices");

        if (voices.isNotEmpty) {
          setState(() {
            // Prefer high-quality voices if available, or just pick the first one
            Map? preferredVoice;
            // Example preference logic (you might need to adjust based on voice names)
            if (language == 'en') {
              preferredVoice = voices.firstWhere(
                  (v) =>
                      v['name'].toLowerCase().contains('male') &&
                      v['name'].toLowerCase().contains('gb'),
                  orElse: () => voices.first);
            } else if (language == 'zh') {
              preferredVoice = voices.firstWhere(
                  (v) =>
                      v['name'].toLowerCase().contains('xiaoxiao') ||
                      v['name'].toLowerCase().contains('female'),
                  orElse: () => voices.first);
            } else {
              preferredVoice = voices.first;
            }
            _currentVoice = preferredVoice;
            setVoice(_currentVoice!);
            print("Selected voice: $_currentVoice");
          });
        } else {
          print(
              "No voices found for locale: $_currentLocale (language: $language)");
        }
      } catch (e) {
        print("Error getting/setting voices: $e");
      }
    });
  }

  void setVoice(Map voice) {
    _flutterTts.setSpeechRate(0.5); // Adjusted for clarity
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
    _flutterTts.setVoice({"name": voice["name"], "locale": voice["locale"]});
  }

  void speakMessage(String message) {
    if (_isTtsEnabled) {
      // Sanitize message for TTS, removing Markdown for smoother speech
      String plainMessage = message
          .replaceAll(
              RegExp(r'[*_#`~]'), '') // Remove common markdown characters
          .replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '') // Remove image tags
          .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // Remove link text
          .replaceAll(RegExp(r'\s+'), ' '); // Normalize whitespace
      _flutterTts.speak(plainMessage.trim());
    }
  }

  Future<void> stopTts() async {
    if (_flutterTts != null) {
      await _flutterTts.stop();
    }
  }

  // Add this method to save TTS preference
  Future<void> _saveTtsPreference(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tts_enabled', isEnabled);
  }

  // Add this method to load TTS preference when app starts
  Future<void> _loadTtsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isTtsEnabled =
          prefs.getBool('tts_enabled') ?? false; // Default to true if not set
    });
  }

  // ---------------------- Speech to Text ----------------------------------

  void _initSpeech() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) {
      _speechEnabled = await _speechToText.initialize();
    } else {
      _speechEnabled = false;
    }
    setState(() {});
  }

  void _initializeAnimationController() {
    _micAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _micAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _micAnimationController, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _micAnimationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          _micAnimationController.forward();
        }
      });
  }

  Future<void> _requestMicrophonePermission() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      _speechEnabled = await _speechToText.initialize();
      setState(() {});
    } else {
      // Show dialog explaining why we need microphone access
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Microphone Permission Required'),
            content: const Text(
                'This app needs microphone access to convert speech to text. '
                'Please enable microphone access in your device settings.'),
            actions: [
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
              ),
            ],
          ),
        );
      }
    }
  }

  void _toggleListening() async {
    if (!_speechEnabled) {
      await _requestMicrophonePermission();
      return;
    }

    if (!_isListening) {
      _startListening();
    } else {
      _stopListening();
    }
  }

  void _startListening() {
    if (_isAnimationDisposed) {
      _initializeAnimationController();
      _isAnimationDisposed = false;
    }
    _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: const Duration(seconds: 30),
      localeId: _currentLocale,
    );
    setState(() {
      _isListening = true;
    });
    _micAnimationController.forward();
  }

  void _stopListening() {
    _speechToText.stop();
    setState(() {
      _isListening = false;
    });

    if (!_isAnimationDisposed) {
      _micAnimationController.dispose();
      _isAnimationDisposed = true;
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (mounted) {
      setState(() {
        _textController.text = result.recognizedWords;

        if (result.finalResult) {
          _isListening = false;

          String text = _textController.text.trim();
          List<String> words = text.split(' ');

          bool isEnglishSend = words.isNotEmpty &&
              (words.last.toLowerCase() == "send" ||
                  words.last.toLowerCase() == "sent");
          bool isChineseSend = text.endsWith("发送");
          bool isMalaySend = text.endsWith("hantar");

          if (isEnglishSend || isChineseSend || isMalaySend) {
            if (isEnglishSend) {
              words.removeLast();
            } else if (isChineseSend) {
              text = text.substring(0, text.length - 2); // Remove "发送"
            }

            String message = words.join(' ').trim();
            sendMessages(ChatMessage(
                user: currentUser,
                createdAt: DateTime.now(),
                text: isChineseSend ? text : message));
            _textController.clear();
            _dismissKeyboard(context);
          }
        }
      });
    }
  }

  // ---------------------- Connectivity ----------------------------------

  Future<void> _initConnectivity() async {
    try {
      bool isOnline = await _networkService.isOnline();
      setState(() {
        _isOnline = isOnline;
      });
    } catch (e) {
      print('Error checking initial connectivity: $e');
    }
  }

  void _subscribeToConnectivity() {
    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      bool isOnline =
          results.any((result) => result != ConnectivityResult.none);
      if (isOnline) {
        // Double-check with our network service
        isOnline = await _networkService.isOnline();
      }
      setState(() {
        _isOnline = isOnline;
      });
    });
  }

  Future<void> _checkInternetConnection() async {
    bool isOnline = await _networkService.isOnline();
    setState(() {
      _isOnline = isOnline;
    });
  }

  // ---------------------- Chat Functions ----------------------------------

  void _initializeChat() async {
    try {
      _chat = await _model.startChat();
      await _chat!.sendMessage(Content.text(chatCmd));

      setState(() {
        _isChatInitialized = true;
      });
    } catch (e) {
      print('Error initializing chat: $e');
    }
  }

  void _loadMessages() async {
    try {
      messages = _chatMemoryService.getMessages();

      if (messages.isEmpty) {
        final initMessage = ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text: """## 👋 Welcome to PlanIT!

**Hi there! I'm your PlanIT Assistant.** I'm here to help you manage your schedule and get things done.


### 🤖 What Can I Do for You?
-	**📅 Add New Tasks** - Just tell me what you need to schedule, and I will handle it.
-	**🗑️ Delete Tasks** - Need to remove something? Just say the word!
-	**🔍 Search Tasks** - Quickly find any task or event in your schedule.
-	**📖 Get Your Tasks** - I will list out all your upcoming plans for easy tracking.
-	**⏳ Find Free Time** - Ask me when you are available, and I will help you plan efficiently.
- **🔄 Refresh** - Use this if you experience any issues or glitches.

### 💬 How to talk to me:
- "Create a meeting with John tomorrow at 3 PM"
- "What's on my schedule this week?"
- "When am I free on Friday?"
- "Remind me to call mom on Sunday 3 PM"  

If you're using voice commands, simply say your request and end with **"send"** (English) or **"发送"** (Chinese) or **"hantar**" (Malay), and I'll process it automatically. 🚀  
""",
          isMarkdown: true,
        );

        _chatMemoryService.addMessage(initMessage);
      }

      for (var message in messages) {
        message.isMarkdown = true;
      }

      // Update the UI
      setState(() {});
    } catch (e) {
      print(e);
    }
  }

  void _addMessage(ChatMessage message) {
    setState(() {
      messages.insert(0, message);
    });
    // _chatMemoryService.addMessage(message);
  }

  // void _addMessage(ChatMessage message) {
  //   setState(() {
  //     messages.insert(0, message);
  //   });
  // }

  void _clearWholeChat() async {
    // Pop a window asking for confirmation
    try {
      setState(() {
        // messages = [];
        _chatMemoryService.clearChat();
      });
    } catch (e) {
      print('Error deleting chat: $e');
    }
  }

  void _dismissKeyboard(BuildContext context) {
    FocusScope.of(context).unfocus();
  }

  // ------------ Load / Save Language Prefrence -----------

  // Save language preference
  Future<void> _saveLanguagePreference(String locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_locale', locale);
  }

  // Load language preference
  Future<void> _loadLanguagePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentLocale =
          prefs.getString('app_locale') ?? 'en_US'; // Default to English
    });
  }

  // ---------------------- Widget ----------------------------------

  Widget _connectionUnavailableUI() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 100,
            color: Colors.grey,
          ),
          SizedBox(height: 20),
          Text(
            'No Internet Connection',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text(
            'Please check your connection and try again',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 30),
          ElevatedButton(
            onPressed: _checkInternetConnection,
            child: Text('Retry'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget deleteConfirmationWindow() {
    return AlertDialog(
      title: const Text("Delete Chat"),
      content: const Text("Are you sure you want to delete the entire chat?"),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            _clearWholeChat();
            Navigator.of(context).pop();
          },
          child: const Text("Delete"),
        ),
      ],
    );
  }

  void _showApiKeyDialog() {
    if (_apiKey != GEMINI_API_KEY) {
      _apiKeyController.text = _apiKey;
    } else {
      _apiKeyController.text = '';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.key, color: Theme.of(context).primaryColor),
            SizedBox(width: 8),
            Text('Get Your API Key')
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Get your free Gemini API key:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final url = Uri.parse('https://aistudio.google.com/apikey');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.link, color: Theme.of(context).primaryColor),
                  SizedBox(width: 4),
                  Text(
                    'AI Studio',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              '1. Visit AI Studio\n2. Sign in with Google account\n3. Click "Get API key"\n4. Copy and paste below',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.vpn_key),
                border: OutlineInputBorder(),
                labelText: 'API Key',
                hintText: 'Paste your Gemini API key',
                filled: true,
              ),
              //  obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close),
            label: Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final newKey = _apiKeyController.text;
              await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .update({'geminiApiKey': newKey});

              setState(() {
                _apiKey = newKey;
                _model = GenerativeModel(
                  model: 'gemini-2.0-flash-lite',
                  apiKey: newKey,
                );
                _chat = null;
                _isChatInitialized = false;
                messages.clear();
              });

              _initializeChat();
              _loadMessages();
              Navigator.pop(context);
            },
            icon: Icon(Icons.save),
            label: Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _dismissKeyboard(context),
      child: Scaffold(
        // Remove the default AppBar background and make it blend with the page background
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent, // Make AppBar transparent
          elevation: 0, // Remove shadow
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 10, sigmaY: 10), // Frosted glass effect
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2), // Subtle white overlay
                  border: Border(
                    bottom: BorderSide(
                        color: Colors.white.withOpacity(0.3), width: 1.0),
                  ),
                ),
              ),
            ),
          ),
          title: Row(
            children: [
              Image.asset(
                'assets/images/tree.png', // Adding tree icon to title
                height: 24,
                width: 24,
              ),
              SizedBox(width: 8),
              Text(
                "PlanIT BOT",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade800, // Nature-themed text color
                  shadows: [
                    Shadow(
                      offset: Offset(1, 1),
                      blurRadius: 3.0,
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          iconTheme: IconThemeData(
            color:
                Colors.green.shade700, // Match icon color to the nature theme
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh_rounded),
              onPressed: () {
                initAsync();
                setState(() {});
              },
            ),
            IconButton(
              onPressed: () {
                if (_apiKey.isEmpty || _apiKey == GEMINI_API_KEY) {
                  _showApiKeyDialog();
                  return;
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TimetableAnalyzerScreen()),
                  );
                }
              },
              icon: Icon(Icons.camera_alt_rounded),
            ),
            PopupMenuButton(
              icon: Icon(Icons.settings),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'tts_toggle',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isTtsEnabled ? Icons.volume_up : Icons.volume_off,
                            size: 20,
                            color: Colors.green.shade600, // Match theme
                          ),
                          SizedBox(width: 8),
                          Text('Text-to-Speech (TESTING)'),
                        ],
                      ),
                      Transform.scale(
                        scale: 0.7,
                        child: Switch(
                          value: _isTtsEnabled,
                          activeColor: Colors.green.shade600, // Match theme
                          onChanged: (newValue) {
                            setState(() {
                              if (_isTtsEnabled == true) {
                                stopTts();
                              }
                              _isTtsEnabled = !_isTtsEnabled;
                              _saveTtsPreference(_isTtsEnabled);
                            });
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'edit_key',
                  child: Row(
                    children: [
                      Icon(
                        Icons.key,
                        size: 20,
                        color: Colors.green.shade600, // Match theme
                      ),
                      SizedBox(width: 8),
                      Text('Edit API Key'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'language',
                  child: Row(
                    children: [
                      Icon(
                        Icons.language,
                        size: 20,
                        color: Colors.green.shade600, // Match theme
                      ),
                      SizedBox(width: 8),
                      Text('Change Language'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever_rounded,
                        size: 20,
                        color: Colors.green.shade600, // Match theme
                      ),
                      SizedBox(width: 8),
                      Text('Delete Chat History'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  showDialog(
                    context: context,
                    builder: (context) => deleteConfirmationWindow(),
                  );
                } else if (value == 'edit_key') {
                  _showApiKeyDialog();
                } else if (value == 'language') {
                  _showLanguageSelectionDialog();
                }
              },
            ),
            Container(
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _currentLocale == 'en_US'
                    ? '🇺🇸'
                    : _currentLocale == 'zh_CN'
                        ? '🇨🇳'
                        : '🇲🇾',
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.png'),
              fit: BoxFit.cover,
            ),
          ),
          child: Stack(
            children: [
              // Semi-transparent overlay
              Container(
                color: Colors.white.withOpacity(0.4),
              ),

              // Check if online
              _isOnline
                  ? Stack(
                      children: [
                        _chatBotUI(),
                        if (_isListening) _buildListeningOverlay(),
                        if (_isTtsEnabled && _isSpeaking)
                          _buildTtsSpeakingOverlay(),
                      ],
                    )
                  : _connectionUnavailableUI(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTtsSpeakingOverlay() {
    return GestureDetector(
      onTap: () {
        stopTts(); // Stop TTS on tap anywhere on this overlay
      },
      child: Container(
        // Full screen semi-transparent background to dim the chat
        color: Colors.black.withOpacity(0.5), // Adjust opacity as needed
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min, // Center the content vertically
            children: [
              Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: Colors.white
                      .withOpacity(0.5), // Light card background for Lottie
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Lottie.asset(
                  'assets/lotties/timetable_robot.json',
                  width: 130, // Adjust size as needed
                  height: 130,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  "Speaking... Tap anywhere to stop.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      // Text shadow for better readability
                      Shadow(
                        offset: Offset(1.0, 1.0),
                        blurRadius: 3.0,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Language'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Text('🇺🇸'),
              title: Text('English'),
              onTap: () {
                setState(() {
                  _currentLocale = 'en_US';
                  _saveLanguagePreference(_currentLocale);
                  _initTts();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Text('🇨🇳'),
              title: Text('Chinese'),
              onTap: () {
                setState(() {
                  _currentLocale = 'zh_CN';
                  _saveLanguagePreference(_currentLocale);
                  _initTts();
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Text('🇲🇾'),
              title: Text('Malay'),
              onTap: () {
                setState(() {
                  _currentLocale = 'ms_MY';
                  _saveLanguagePreference(_currentLocale);
                  _initTts();
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListeningOverlay() {
    return GestureDetector(
      onTap: _stopListening,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _micAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _micAnimation.value,
                    child: Icon(
                      Icons.mic,
                      size: 100,
                      color: Colors.white,
                    ),
                  );
                },
              ),
              SizedBox(height: 20),
              Text(
                "Listening...",
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
              SizedBox(height: 20),
              Text(
                "Tap to stop listening",
                style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatBotUI() {
    return SafeArea(
      child: Column(
        children: [
          // Add the quick replies above the chat
          _buildQuickReplies(),

          // Expand the DashChat to fill remaining space
          Expanded(
            child: DashChat(
              currentUser: currentUser,
              onSend: sendMessages,
              messages: messages,
              inputOptions: InputOptions(
                  textController: _textController,
                  sendButtonBuilder: (onSend) {
                    return IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _isChatInitialized
                          ? () {
                              if (_textController.text.isNotEmpty) {
                                FocusScope.of(context).unfocus();
                                onSend();
                              }
                            }
                          : null,
                    );
                  },
                  leading: [
                    // Bold mic button with solid background and elevation
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _isListening ? Colors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.grey.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.white : Colors.blue,
                          size: 22,
                        ),
                        onPressed: _toggleListening,
                        tooltip:
                            _isListening ? 'Stop listening' : 'Start listening',
                      ),
                    ),
                  ]),
              messageOptions: const MessageOptions(
                showTime: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    // Define your quick reply options with icons
    final List<Map<String, dynamic>> quickReplies = [
      {"text": "Add Task", "icon": Icons.add_task, "suffix": ": "},
      {
        "text": "Get Tomorrow's Schedule",
        "icon": Icons.calendar_today,
        "suffix": ""
      },
      {"text": "Delete Task", "icon": Icons.delete_outline, "suffix": ": "},
      {"text": "Find Free Time", "icon": Icons.access_time, "suffix": ": "},
      {"text": "Search Task", "icon": Icons.search, "suffix": ": "},
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      decoration: BoxDecoration(
        // color: Colors.grey.shade50,
        color: Colors.white.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Padding(
          //   padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
          //   child: Text(
          //     "Quick Actions",
          //     style: TextStyle(
          //       fontSize: 14,
          //       fontWeight: FontWeight.w500,
          //       color: Colors.grey.shade700,
          //     ),
          //   ),
          // ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: quickReplies.map((reply) {
                return Padding(
                  padding: const EdgeInsets.only(right: 10.0),
                  child: Material(
                    elevation: 1,
                    shadowColor: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        // Autofill the text controller with the reply text + suffix
                        _textController.text = reply["text"] + reply["suffix"];

                        // Position cursor at the end of the text
                        _textController.selection = TextSelection.fromPosition(
                          TextPosition(offset: _textController.text.length),
                        );

                        // Optional: Focus on the text field
                        FocusScope.of(context).requestFocus(FocusNode());

                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: Colors.blue.shade200, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              reply["icon"],
                              size: 18,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              reply["text"],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  void sendMessages(ChatMessage message) async {
    if (!_isChatInitialized || _chat == null) {
      print('Chat not initialized yet');
      _addMessage(ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text:
              "Sorry, the chat is not ready. Please try again in a moment. Try to tap the reload icon.",
          isMarkdown: true));
      return;
    }

    if (_apiKey.isEmpty || _apiKey == GEMINI_API_KEY) {
      // Assuming GEMINI_API_KEY is a placeholder
      _showApiKeyDialog(); // Ensure this method exists
      return;
    }

    DateTime now = DateTime.now();
    String timeNow = 'Current Time For Reference: ' +
        DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    _addMessage(message); // Add user's message

    final processingMessages = [
      "🤔 Let me think for a sec...",
      "🔍 Looking into this...",
      "🧠 Figuring it out...",
      "✨ Making something cool...",
      "📘 Reading what you said...",
      "⚙️ Working on it...",
      "💬 Getting the right words...",
      "⏳ Almost there...",
      "🚀 Preparing a reply...",
      "🎯 Finding the best answer..."
    ];

    final thinkingMessageText =
        processingMessages[Random().nextInt(processingMessages.length)];
    final thinkingMessage = ChatMessage(
      user: scheduleBot,
      createdAt: DateTime.now(),
      text: thinkingMessageText,
      isMarkdown: true,
    );

    _addMessage(thinkingMessage);

    setState(() {
      _isTyping = true;
    });

    final prompt = (timeNow +
        "\nUser: " +
        message.text +
        "\nPlanIT:"); // Structure prompt clearly

    try {
      final response = await _chat!.sendMessage(Content.text(prompt));

      // Remove the thinking message
      // Find by its unique text content if possible, or by being the last bot message that's a "thinking" one
      int thinkingMessageIndex = messages.indexWhere(
          (m) => m.user == scheduleBot && m.text == thinkingMessageText);
      if (thinkingMessageIndex != -1) {
        setState(() {
          messages.removeAt(thinkingMessageIndex);
        });
      } else if (messages.isNotEmpty &&
          messages.first.user == scheduleBot &&
          processingMessages.contains(messages.first.text)) {
        setState(() {
          messages.removeAt(0);
        });
      }

      if (response.text != null) {
        String fullLLMResponseText = response.text!;

        // --- Streaming display logic for LLM's raw command output ---
        String currentDisplayResponse = '';
        final responseMessagePlaceholder = ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(), // Timestamp for the bot's response
          text: "", // Start empty, will be filled by stream
          isMarkdown: true,
        );

        // Add the placeholder to the messages list to be updated
        setState(() {
          messages.insert(0, responseMessagePlaceholder);
        });

        final trimmedLLMResponse = fullLLMResponseText.trim();

        bool isCommandType = false;
        String detectedCommandWord = "";
        final linesForCmdCheck = trimmedLLMResponse.split('\n');

        if (linesForCmdCheck.isNotEmpty) {
          String firstPotentialWord =
              linesForCmdCheck[0].trim().split(' ')[0].toLowerCase();
          if (firstPotentialWord == 'add' ||
              firstPotentialWord == 'get' ||
              firstPotentialWord == 'delete' ||
              firstPotentialWord == 'search' ||
              firstPotentialWord == 'find') {
            isCommandType = true;
            detectedCommandWord = firstPotentialWord;
          }
          // Specifically check for edit command (delete \n add)
          if (linesForCmdCheck.length == 2 &&
              linesForCmdCheck[0].trim().startsWith("delete ") &&
              linesForCmdCheck[1].trim().startsWith("add ")) {
            isCommandType = true;
            detectedCommandWord = "edit";
          }
        }

        print("LLM response: $trimmedLLMResponse");

        if (isCommandType) {
          final commandConfirmationMessages = [
            "Alright, on it! Working on your $detectedCommandWord request.",
            "Gotcha! Let's $detectedCommandWord that for you.",
            "Woohoo! A $detectedCommandWord command! Let me work my magic ✨.",
            "Ooh, a $detectedCommandWord task! My favorite! Processing...",
            "PlanIT at your service! Firing up the $detectedCommandWord-inators! 🚀",
          ];
          String confirmationText = commandConfirmationMessages[
              Random().nextInt(commandConfirmationMessages.length)];

          final commandProcessingMsg = ChatMessage(
            user: scheduleBot,
            createdAt: DateTime.now(), // New message for this specific feedback
            text: confirmationText,
            isMarkdown: true,
          );
          _addMessage(commandProcessingMsg); // Add this single message
        } else {
          String currentDisplayResponse = '';
          final generalTextPlaceholder = ChatMessage(
            user: scheduleBot,
            createdAt: DateTime.now(), // Timestamp for this bot response
            text: "", // Start empty
            isMarkdown: true,
          );

          // Add the placeholder to the messages list to be updated
          setState(() {
            messages.insert(0, generalTextPlaceholder);
          });

          for (var chunk in fullLLMResponseText.split(' ')) {
            // Stream the original full text
            if (chunk.isEmpty && currentDisplayResponse.endsWith(' ')) continue;
            currentDisplayResponse += '$chunk ';

            final partialMessage = ChatMessage(
              user: scheduleBot,
              createdAt: generalTextPlaceholder
                  .createdAt, // Keep original timestamp of this message slot
              text: currentDisplayResponse.trim(),
              isMarkdown: true,
            );
            setState(() {
              // Always update messages[0] if it's the bot's current response slot
              if (messages.isNotEmpty &&
                  messages.first.user == scheduleBot &&
                  messages.first.createdAt ==
                      generalTextPlaceholder.createdAt) {
                messages[0] = partialMessage;
              } else {
                // This case should be rare if logic is correct, indicates placeholder was lost
                print(
                    "Streaming fallback: inserting new message as placeholder was lost.");
                messages.insert(
                    0, partialMessage); // Less ideal, might create new bubble
              }
            });
            await Future.delayed(const Duration(milliseconds: 40));
          }
        }
        // At this point, messages[0] contains the fullLLMResponseText

        // --- Process the fully received fullLLMResponseText for commands ---
        final trimmedResponse = fullLLMResponseText.trim();
        final lines = trimmedResponse.split('\n');

        bool isEditCommand = lines.length == 2 &&
            lines[0].trim().startsWith("delete ") &&
            lines[1].trim().startsWith("add ");

        if (isEditCommand) {
          final deleteCommand = lines[0].trim();
          final addCommand = lines[1].trim();

          bool deleteSuccess = await _handleDeleteTaskForEdit(deleteCommand);

          if (deleteSuccess) {
            _handleAddCommand(addCommand, true);
          } else {
            _addMessage(ChatMessage(
              user: scheduleBot,
              createdAt: DateTime.now(),
              text:
                  "⚠️ Couldn't modify the task. The original task might not have been found or an error occurred during deletion.",
              isMarkdown: true,
            ));
          }
        } else if (trimmedResponse.startsWith("add ")) {
          _handleAddCommand(trimmedResponse, false);
        } else if (trimmedResponse.startsWith("get ")) {
          await _handleGetCommand(trimmedResponse);
        } else if (trimmedResponse.startsWith("delete ")) {
          await _handleDeleteTask(
              trimmedResponse); // For standard, non-edit deletes
        } else if (trimmedResponse.startsWith('find ')) {
          await _handleFindCommand(trimmedResponse);
        } else if (trimmedResponse.startsWith('search ')) {
          await _handleSearchCommand(trimmedResponse);
        } else {}
      } else {
        _addMessage(ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text: "Sorry, I received an empty response. Please try again.",
          isMarkdown: true,
        ));
      }
    } catch (e) {
      print('Error in sendMessages or generating AI response: $e');
      // Remove thinking message on error too
      int thinkingMessageIndex = messages.indexWhere(
          (m) => m.user == scheduleBot && m.text == thinkingMessageText);
      if (thinkingMessageIndex != -1) {
        setState(() {
          messages.removeAt(thinkingMessageIndex);
        });
      }

      _addMessage(ChatMessage(
        user: scheduleBot,
        createdAt: DateTime.now(),
        text:
            "😥 Oops! Something went wrong while processing your request. Please try again. Error: $e",
        isMarkdown: true,
      ));
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  void _handleAddCommand(String response, bool isEdit) async {
    // Example response format: "add 2024-10-09 15:00 meet FYP supervisor [subtask1, subtask2]"
    // Split by bracket first to separate main task and subtasks
    final mainAndSubtasks = response.split('[');
    final mainPart = mainAndSubtasks[0].trim();
    final parts = mainPart.split(' ');

    // Extract subtasks if they exist
    List<String> subtasks = [];
    if (mainAndSubtasks.length > 1) {
      // Remove the closing bracket and split by comma
      final subtasksString = mainAndSubtasks[1].replaceAll(']', '').trim();
      subtasks = subtasksString.split(',').map((s) => s.trim()).toList();
    }

    if (parts.length >= 4) {
      try {
        final String dateStr = parts[1]; // Extract date in yyyy-MM-dd format
        final String timeStr =
            parts[2]; // Extract time in HH:mm format (no seconds)
        final String category = parts[3];
        final String priority = parts[4];
        final String taskDescription = parts
            .sublist(5)
            .join(' ')
            .trim(); // Task description from remaining parts

        // Combine date and time, ensuring it follows yyyy-MM-ddTHH:mm format for DateTime parsing
        final DateTime taskDateTime = DateTime.parse("$dateStr $timeStr:00");

        // Initialize with the original time - this will be used if there are no conflicts
        // or if the user selects "Use anyway"
        DateTime selectedTime = taskDateTime;

        final conflicts =
            await _scheduleService.getConflictTasks(newTaskTime: taskDateTime);

        // Check if there are conflicts
        if (conflicts.isNotEmpty) {
          // Define a completer to get both the decision and the selected time
          final completer = Completer<Map<String, dynamic>>();

          // Show conflict dialog
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return StatefulBuilder(
                  builder: (BuildContext context, StateSetter dialogSetState) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange[700], size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'Time Conflict Detected',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'You already have a task scheduled at ${DateFormat('MMM dd, yyyy - HH:mm').format(taskDateTime)}:',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[100]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: conflicts
                                .map((task) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.event,
                                              color: Colors.blue[400],
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Suggested alternatives:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: TimeConflictManager(ScheduleService())
                                .getAlternativeTimes(taskDateTime)
                                .length,
                            itemBuilder: (context, index) {
                              final alternatives =
                                  TimeConflictManager(ScheduleService())
                                      .getAlternativeTimes(taskDateTime);
                              return InkWell(
                                onTap: () {
                                  // Complete the future with both the decision and the selected time
                                  completer.complete({
                                    'proceed': true,
                                    'time': alternatives[index]
                                  });
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.schedule,
                                              color: Colors.green[400]),
                                          const SizedBox(width: 12),
                                          Text(
                                            DateFormat('HH:mm')
                                                .format(alternatives[index]),
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        index < 2 ? 'Earlier' : 'Later',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        FutureBuilder<DateTime?>(
                          future: TimeConflictManager(ScheduleService())
                              .findNextAvailableSlot(taskDateTime),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }

                            if (snapshot.hasData && snapshot.data != null) {
                              return InkWell(
                                onTap: () {
                                  // Complete the future with both the decision and the selected time
                                  completer.complete({
                                    'proceed': true,
                                    'time': snapshot.data!
                                  });
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.blue[200]!),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.auto_awesome,
                                          color: Colors.blue[400]),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Next available: ${DateFormat('HH:mm').format(snapshot.data!)}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return const SizedBox.shrink();
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () {
                                completer
                                    .complete({'proceed': false, 'time': null});
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                completer.complete(
                                    {'proceed': true, 'time': taskDateTime});
                                Navigator.pop(context);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Use anyway',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              });
            },
          );

          // Wait for the dialog result
          final result = await completer.future;

          // Check if the user wants to proceed
          if (!result['proceed']) {
            _addMessage(ChatMessage(
                user: scheduleBot,
                createdAt: DateTime.now(),
                text: "Task addition cancelled due to time conflict.",
                isMarkdown: true));
            return;
          }

          // Update the selected time if one was chosen
          if (result['time'] != null) {
            selectedTime = result['time'];
          }
        }

        // Save the task to Firebase using the selected time
        _scheduleService.addSchedule(
          title: taskDescription,
          category: category,
          url: "",
          placeURL: "",
          time: selectedTime,
          subtasks: subtasks,
          priority: priority,
          isRepeated: false,
          repeatInterval: 'Daily',
          repeatedIntervalTime: 0,
        );

        // Format subtasks section for display if any exist
        String subtasksDisplay = "";
        if (subtasks.isNotEmpty) {
          subtasksDisplay = "\n\n**Subtasks:**\n" +
              subtasks.map((task) => "- $task").join("\n");
        }

        String action;

        if (isEdit) {
          action = "edited";
        } else {
          action = "added";
        }

        String addDetails = """
✅ Task $action successfully!

📝 **Task Details:**
- 📌 Title: **$taskDescription**
- 🏷️ Category: **$category**
- 📅 Date: **${DateFormat('EEEE, MMM d, y').format(selectedTime)}**
- ⏰ Time: **${DateFormat('h:mm a').format(selectedTime)}**
- 🎯 Priority: **$priority**$subtasksDisplay

✨ ${selectedTime != taskDateTime ? 'Task rescheduled to avoid conflicts!' : conflicts.isEmpty ? 'No scheduling conflicts detected!' : 'Task scheduled despite conflicts.'}

Your task has been added to the schedule. Any other tasks you'd like to add?🤝
""";

        _addMessage(ChatMessage(
            user: scheduleBot,
            createdAt: DateTime.now(),
            text: addDetails.trim(),
            isMarkdown: true));

        if (_isTtsEnabled) {
          if (_currentLocale == "en_US") {
            String ttsMessage =
                "Task '$taskDescription' $action for ${DateFormat('d MMM y, h:mm a').format(selectedTime)}. "
                "It's a $priority priority in '$category'. You got this!";
            speakMessage(ttsMessage);
            print('Response: ${response}');
          }
        }
      } catch (e) {
        print("Error parsing add command: $e");
        _addMessage(ChatMessage(
            user: scheduleBot,
            createdAt: DateTime.now(),
            text:
                "Sorry, I couldn't process your request. Please try again. Try to tap the reload icon.",
            isMarkdown: true));
      }
    }
  }

  Future<void> _handleFindCommand(String response) async {
    final trimmedResponse = response.trim();
    final parts = trimmedResponse.split(' ');

    if (parts.length != 2) {
      _addMessage(ChatMessage(
        user: scheduleBot,
        createdAt: DateTime.now(),
        text: "Invalid find command. Please use the format: `find YYYY-MM-DD`",
        isMarkdown: true,
      ));
      return;
    }

    try {
      final String dateStr = parts[1];
      final DateTime targetDate = DateTime.parse(dateStr);
      final DateTime startOfDay =
          DateTime(targetDate.year, targetDate.month, targetDate.day);
      final DateTime endOfDay =
          startOfDay.add(const Duration(hours: 23, minutes: 59));

      // Fetch tasks for the specified day
      final tasks = await _scheduleService.getSchedulesForDate(startOfDay);

      if (tasks.isEmpty) {
        _addMessage(ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text: """# 🌞 Free Day Alert for $dateStr!

🎉 **Good news!** You have no tasks scheduled on ${DateFormat('EEEE, MMM d, y').format(targetDate)}.  
The entire day is yours—time to relax, plan something fun, or tackle that side project!  

**Idea of the Day:** ${getRandomFreeTimeIdea()}
""",
          isMarkdown: true,
        ));
        return;
      }

      // Sort tasks by time to analyze gaps
      tasks.sort((a, b) => a.time.compareTo(b.time));

      // Define working hours (e.g., 8 AM to 10 PM) for free time calculation
      final DateTime workDayStart = startOfDay.add(const Duration(hours: 6));
      final DateTime workDayEnd = startOfDay.add(const Duration(hours: 23));
      List<Map<String, DateTime>> freeSlots = [];

      DateTime lastEndTime = workDayStart;

      // Find gaps between tasks
      for (var task in tasks) {
        final taskStart =
            task.time.isBefore(workDayStart) ? workDayStart : task.time;
        final taskEnd = task.time
            .add(const Duration(hours: 1)); // Assume 1-hour default duration

        if (taskStart.isAfter(lastEndTime)) {
          freeSlots.add({
            'start': lastEndTime,
            'end': taskStart,
          });
        }
        lastEndTime = taskEnd.isAfter(workDayEnd) ? workDayEnd : taskEnd;
      }

      // Check for free time after the last task
      if (lastEndTime.isBefore(workDayEnd)) {
        freeSlots.add({
          'start': lastEndTime,
          'end': workDayEnd,
        });
      }

      // Build the response
      String freeTimeMessage = """### ⏰ Free Time Finder for $dateStr

🌟 **Here’s your free time on ${DateFormat('EEEE, MMM d, y').format(targetDate)}!**  
I’ve scanned your schedule between 6 AM and 11 PM. Here’s what I found:

""";

      if (freeSlots.isEmpty) {
        freeTimeMessage += """
> 😅 **Whoa, busy day!** No free slots found between 8 AM and 10 PM.  
> Maybe sneak in a quick break or reschedule something?  
""";
      } else {
        freeTimeMessage += "### 🕒 Your Free Slots\n\n";
        for (var slot in freeSlots) {
          final startTime = DateFormat('h:mm a').format(slot['start']!);
          final endTime = DateFormat('h:mm a').format(slot['end']!);
          final duration = slot['end']!.difference(slot['start']!).inMinutes;
          final durationStr = duration >= 60
              ? '${duration ~/ 60}h ${duration % 60}m'
              : '${duration}m';

          freeTimeMessage += """
- **$startTime - $endTime**  
  *Duration*: $durationStr  
""";
        }
      }

      freeTimeMessage += """
---

**✨ Pro Tip:** ${getRandomProductivityTip()}  
Need help filling a slot? Just say `add` with a time and task!
""";

      if (_isTtsEnabled) {
        final response = await _aiAnalyzer.generateFreeTimeResponse(
            freeSlots, targetDate, tasks, messages[1].text, _currentLocale);
        speakMessage(response);
        print('Response: ${response}');
      }

      print("Message: ${messages[1].text}");

      _addMessage(ChatMessage(
        user: scheduleBot,
        createdAt: DateTime.now(),
        text: freeTimeMessage.trim(),
        isMarkdown: true,
      ));

      // Optional: Show a dialog with a visual timeline
      if (context.mounted && freeSlots.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => FreeTimeDialog(
            date: dateStr,
            freeSlots: freeSlots,
            tasks: tasks,
          ),
        );
      }
    } catch (e) {
      print("Error parsing find command: $e");
      _addMessage(ChatMessage(
        user: scheduleBot,
        createdAt: DateTime.now(),
        text:
            "Oops! Couldn’t find free time. Please use the format: `find YYYY-MM-DD`",
        isMarkdown: true,
      ));
    }
  }

// Helper method for random free-time ideas
  String getRandomFreeTimeIdea() {
    const ideas = [
      "Catch up on your favorite book 📖",
      "Try a new recipe in the kitchen 👩‍🍳",
      "Go for a relaxing walk in nature 🌳",
      "Binge-watch that series you’ve been eyeing 📺",
      "Plan your next adventure ✈️",
    ];
    return ideas[Random().nextInt(ideas.length)];
  }

  Future<void> _handleSearchCommand(String response) async {
    final trimmedResponse = response.trim();
    final parts = trimmedResponse.split(' ');

    if (parts.length >= 2) {
      try {
        // Extract the search query (everything after "search")
        final searchQuery = parts.sublist(1).join(' ');
        print("Search Query: $searchQuery");

        _addMessage(ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text: "Searching for tasks matching: \"$searchQuery\"...",
          isMarkdown: true,
        ));

        final Stream<List<Task>> incompleteTasksStream =
            _scheduleService.getSchedulesByCompletionStatusAndQuery(
                isCompleted: false, searchQuery: searchQuery);

        // Await both streams to get the results
        final incompleteTasks = await incompleteTasksStream.first;

        if (incompleteTasks.isEmpty) {
          _addMessage(ChatMessage(
            user: scheduleBot,
            createdAt: DateTime.now(),
            text: "No tasks found matching \"$searchQuery\".",
            isMarkdown: true,
          ));
          return;
        }

        // Process tasks by category, similar to the get command
        Map<String, List<Map<String, String>>> tasksByCategory = {};

        for (var task in incompleteTasks) {
          final DateTime time = task.time;
          final bool done = task.done as bool? ?? false;
          final String taskID = task.id;
          final String status = done ? "✅" : "⏳";
          final String category = task.category as String? ?? 'Uncategorized';
          final String title = task.title as String? ?? '';
          final String formattedTime = _formatTime(time);
          final String url = task.url as String? ?? '';
          final String placeURL = task.placeURL as String? ?? '';
          final String priority = task.priority;
          final String date = DateFormat('yyyy-MM-dd').format(time);

          if (!tasksByCategory.containsKey(category)) {
            tasksByCategory[category] = [];
          }
          tasksByCategory[category]!.add({
            'taskID': taskID,
            'time': formattedTime,
            'date': date,
            'title': title,
            'status': status,
            'url': url,
            'placeURL': placeURL,
            'priority': priority,
          });
        }

        // Generate enhanced search results with markdown formatting
        String resultsList = """### 🔍 Search Results for \"$searchQuery\"

Found ${incompleteTasks.length} matching tasks

---
""";

        tasksByCategory.forEach((category, tasks) {
          // Add category with appropriate icon
          final categoryIcon = _getCategoryIcon(category);
          resultsList += "\n### $categoryIcon $category\n\n";

          for (var task in tasks) {
            resultsList += """### ${task['title']} ${task['status']}

* 📅 **Date**: ${task['date']}
* ⏰ **Time**: ${task['time']}${task['url']?.isNotEmpty == true ? "\n* 🔗 [Open Link](${task['url']})" : ""}${task['placeURL']?.isNotEmpty == true ? "\n* 📍 [View Location](${task['placeURL']})" : ""}

---
""";
          }
        });
        resultsList += "**✨ Bonus Tip:** \n\n${getRandomProductivityTip()}\n";

        if (_isTtsEnabled) {
          String ttsContent = await _aiAnalyzer.generateInteractiveTTSForGet(
              tasksByCategory, resultsList, _currentLocale, 'search');
          speakMessage(ttsContent);
          print(ttsContent);
        }

        _addMessage(ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text: resultsList.trim(),
          isMarkdown: true,
        ));

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => TaskViewDialog(
              date: "Search: $searchQuery",
              tasksByCategory: tasksByCategory,
            ),
          );
        }
      } catch (e) {
        print("Error executing search command: $e");
        _addMessage(ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text:
              "Error searching for tasks. Please try again with a different query.",
          isMarkdown: true,
        ));
      }
    } else {
      _addMessage(ChatMessage(
        user: scheduleBot,
        createdAt: DateTime.now(),
        text:
            "Invalid search command. Please use the format: search [your search terms]",
        isMarkdown: true,
      ));
    }
  }

  Future<void> _handleGetCommand(String response) async {
    final trimmedResponse = response.trim();
    final parts = trimmedResponse.split(' ');

    if (parts.length == 2 || parts.length == 3) {
      try {
        final String dateStr = parts[1];
        String shownTime = '';
        DateTime dateTime;
        List<Task> tasks;

        if (parts.length == 3) {
          final String timeStr = parts[2];
          shownTime = timeStr;
          dateTime = DateTime.parse('$dateStr $timeStr');
          tasks = await _scheduleService.getSchedulesForDateTime(dateTime);
        } else {
          dateTime = DateTime.parse(dateStr);
          tasks = await _scheduleService.getSchedulesForDate(dateTime);
        }

        // Weather forecast check only when parts.length > 2
        WeatherData? weatherData;
        if (parts.length > 2 && !dateTime.isBefore(DateTime.now())) {
          try {
            _addMessage(ChatMessage(
              user: scheduleBot,
              createdAt: DateTime.now(),
              text: "Fetching weather data...",
              isMarkdown: true,
            ));
            final LocationService _locationService = LocationService();
            final position = await _locationService.determinePosition();
            weatherData = await _weatherService.getWeather(
                position.latitude, position.longitude);
          } catch (e) {
            print('Weather fetch error: $e');
          }
        }

        if (tasks.isEmpty) {
          _addMessage(ChatMessage(
            user: scheduleBot,
            createdAt: DateTime.now(),
            text: "No tasks found for $dateStr $shownTime",
            isMarkdown: true,
          ));
          if (_isTtsEnabled) {
            if (_currentLocale == "en_US") {
              String ttsMessage =
                  "Looks like you are all clear for $dateStr $shownTime. No tasks found — enjoy your free time!";
              speakMessage(ttsMessage);
            }
          }
          return;
        }

        Map<String, List<Map<String, String>>> tasksByCategory = {};

        for (var task in tasks) {
          final DateTime time = task.time;
          String? weatherForecast;

          if (parts.length > 2 && weatherData != null) {
            final hourlyForecasts = weatherData.hourlyForecast;
            final matchingForecasts = hourlyForecasts.where(
              (forecast) =>
                  forecast.time.isAtSameMomentAs(time) ||
                  (forecast.time.isAfter(time) &&
                      forecast.time.difference(time).inHours <= 12),
            );

            final matchingForecast =
                matchingForecasts.isNotEmpty ? matchingForecasts.first : null;

            if (matchingForecast != null) {
              weatherForecast =
                  WeatherUtils.getWeatherAdvice(task, weatherData);
            }
          }

          bool done = task.done as bool? ?? false;
          final taskID = task.id;
          final String status = done ? "✅" : "⏳";
          final String category = task.category as String? ?? 'Uncategorized';
          final String title = task.title as String? ?? '';
          final String formattedTime = _formatTime(time);
          final String date = DateFormat('yyyy-MM-dd').format(time);
          final String url = task.url as String? ?? '';
          final String placeURL = task.placeURL as String? ?? '';
          final String priority = task.priority;

          if (!tasksByCategory.containsKey(category)) {
            tasksByCategory[category] = [];
          }
          tasksByCategory[category]!.add({
            'taskID': taskID,
            'time': formattedTime,
            'date': date,
            'title': title,
            'status': status,
            'url': url,
            'placeURL': placeURL,
            'weather': weatherForecast ?? '',
            'priority': priority,
          });
        }

        // Generate enhanced task list with better markdown formatting
        String ttsGetCommand = '';
        String taskList = """### 📋 Tasks for $dateStr

---
""";

        tasksByCategory.forEach((category, tasks) {
          // Add category with appropriate icon
          final categoryIcon = _getCategoryIcon(category);
          taskList += "\n### $categoryIcon $category\n\n";

          String categoryTasks = "";

          for (var task in tasks) {
            String taskContent = """### ${task['title']} ${task['status']}

* ⏰ **Time**: ${task['time']}${task['url']?.isNotEmpty == true ? "\n* 🔗 [Open Link](${task['url']})" : ""}${task['placeURL']?.isNotEmpty == true ? "\n* 📍 [View Location](${task['placeURL']})" : ""}${task['weather']?.isNotEmpty == true ? "\n* 🌤️ **Weather Advisory**:\n  > ${task['weather']?.replaceAll('\n', '\n  > ')}" : ""}

---
""";

            categoryTasks += taskContent;

            ttsGetCommand += taskContent;
          }

          taskList += categoryTasks;
        });

// Add bonus tip at the end
        taskList += "**✨ Bonus Tip:** \n\n${getRandomProductivityTip()}\n";

        if (taskList.trim().isEmpty) {
          taskList = """# 📋 Tasks for $dateStr

> ℹ️ No tasks scheduled for today.
""";
        }

        if (_isTtsEnabled) {
          String ttsContent = await _aiAnalyzer.generateInteractiveTTSForGet(
              tasksByCategory, ttsGetCommand, _currentLocale, 'schedule');
          speakMessage(ttsContent);
          print(ttsContent);
        }

        print(ttsGetCommand);

        _addMessage(ChatMessage(
            user: scheduleBot,
            createdAt: DateTime.now(),
            text: taskList.trim(),
            isMarkdown: true));

        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) => TaskViewDialog(
              date: dateStr,
              tasksByCategory: tasksByCategory,
            ),
          );
        }
      } catch (e) {
        print("Error parsing get command: $e");
        _addMessage(ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text:
              "Error retrieving tasks. Please ensure the date is in the correct format (YYYY-MM-DD).",
          isMarkdown: true,
        ));
      }
    } else {
      _addMessage(ChatMessage(
        user: scheduleBot,
        createdAt: DateTime.now(),
        text: "Invalid get command. Please use the format: get YYYY-MM-DD",
        isMarkdown: true,
      ));
    }
  }

  // Function to get a random productivity tip
  String getRandomProductivityTip() {
    final tips = [
      "🍅 Try the Pomodoro Technique: 25 minutes of focused work followed by a 5-minute break. (Helps you stay fresh!)",
      "🗂️ Break down large tasks into smaller, manageable steps. (Baby steps still get you there!)",
      "🎯 Prioritize your tasks based on importance and urgency. (What really needs to be done now?)",
      "🗓️ Set realistic goals and celebrate your achievements. (You deserve a pat on the back!)",
      "🧘 Take breaks to refresh your mind and boost creativity. (A relaxed mind is a productive mind!)",
      "🚫 Eliminate distractions to stay focused on the task at hand. (Turn off those notifications!)",
      "⏱️ Use a timer to track your time and identify areas for improvement. (Where is your time going?)",
      "📝 Review your progress at the end of each day and plan for tomorrow. (Reflect and get ready!)",
      "💧 Stay hydrated and get enough sleep for optimal productivity. (Your body is your engine!)",
      "🤝 Don't be afraid to ask for help when you need it. (Teamwork makes the dream work!)",
      "✅ Create a to-do list and check off tasks as you complete them. (So satisfying!)",
      "⏰ Work during your most productive hours. (Are you a morning person or a night owl?)",
      "🎵 Listen to calming music or nature sounds to help you focus. (Find your flow state!)",
      "🧹 Keep your workspace clean and organized. (A tidy space equals a tidy mind!)",
      "🥇 Focus on one task at a time. (Multitasking is a myth!)",
      "🎉 Reward yourself after completing a challenging task. (You earned it!)",
      "🙅 Learn to say no to tasks that don't align with your priorities. (Protect your time!)",
      "🤔 Reflect on your work habits and identify areas for improvement. (Always be learning!)",
      "🚶 Take a walk or do some light exercise to boost your energy. (Move your body, boost your mind!)",
      "💡 Keep a notebook handy to jot down ideas as they come to you. (Inspiration can strike anywhere!)",
      "🤸 Incorporate short stretch breaks into your day. (Keeps the body and mind limber!)",
      "🪟 Open a window for some fresh air to improve focus and reduce fatigue. (A breath of fresh air works wonders!)",
    ];
    final randomIndex = Random().nextInt(tips.length);
    return tips[randomIndex];
  }

  // Helper function to get category-specific icons
  String _getCategoryIcon(String category) {
    return switch (category.toLowerCase()) {
      'outdoor' => '🏞️',
      'sports' => '🏃',
      'travel' => '✈️',
      'work' => '💼',
      'meeting' => '👥',
      'personal' => '🏠',
      _ => '📝'
    };
  }

  Future<bool> _handleDeleteTaskForEdit(String deleteCommandResponse) async {
    // Simplified version for the 'delete' part of an 'edit'
    // It might not need to show a dialog, or it might need to find a *single* specific task
    // based on the LLM's more precise 'delete' command.
    final parts = deleteCommandResponse.trim().split(' ');

    if (parts.length < 2) return false; // Invalid delete command structure

    try {
      final dateStr = parts[1];
      final hasTime =
          parts.length >= 3 && RegExp(r'^\d{2}:\d{2}$').hasMatch(parts[2]);
      final hasSearchQuery = parts.length > (hasTime ? 3 : 2);
      final timeStr = hasTime ? parts[2] : null;
      final searchQuery = hasSearchQuery
          ? parts.sublist(hasTime ? 3 : 2).join(' ').toLowerCase()
          : null;

      final dateTime = hasTime
          ? DateTime.parse('$dateStr $timeStr')
          : DateTime.parse(dateStr);

      List<Task> tasks = hasTime
          ? await _scheduleService.getSchedulesForDateTime(dateTime)
          : await _scheduleService.getSchedulesForDate(dateTime);

      tasks = tasks.where((task) => !task.done).toList();

      if (searchQuery != null && tasks.isNotEmpty) {
        // For an edit, the LLM should ideally provide enough keywords
        // to narrow it down to one task.
        // We might want a more precise search or assume the first match is correct here.
        tasks = await _scheduleService
            .searchTasksWithRelevance(searchQuery, tasks, limitOne: true);
      } else if (tasks.length > 1 && hasTime) {
        // If multiple tasks at exact time, and no keywords, it's ambiguous
        // But for an edit, the LLM should have been specific.
        // We might default to the first one, or if LLM provided specific original details,
        // we should try to match those.
        // For simplicity now, if multiple matches, and LLM didn't provide enough keywords for search,
        // it might fail or delete the first one. This needs careful thought for robustness.
      }

      if (tasks.isEmpty) {
        print("Edit: Original task for deletion not found precisely.");
        return false;
      }

      // For an automated edit, we usually want to delete just one task.
      // If the LLM correctly identified the task, 'tasks' should contain one item.
      if (tasks.length == 1) {
        await _scheduleService.deleteSchedule(tasks.first.id);
        print("Edit: Original task ${tasks.first.title} deleted.");
        return true;
      } else {
        // If LLM's delete command still results in multiple tasks, it's an issue.
        // The LLM should be specific enough.
        print(
            "Edit: Ambiguous original task for deletion. Found ${tasks.length} tasks.");
        // Optionally, delete the first match if you want to be more lenient.
        // await _scheduleService.deleteSchedule(tasks.first.id);
        // return true;
        return false;
      }
    } catch (e) {
      print("Error processing delete part of edit command: $e");
      return false;
    }
  }

  Future<void> _handleDeleteTask(String response) async {
    final trimmedResponse = response.trim();
    final parts = trimmedResponse.split(' ');

    if (parts.length < 2) {
      _addMessage(ChatMessage(
        user: scheduleBot,
        createdAt: DateTime.now(),
        text:
            "Invalid delete command. Please use: delete YYYY-MM-DD [HH:mm] [searchQuery]",
        isMarkdown: true,
      ));
      return;
    }

    try {
      final dateStr = parts[1];
      final hasTime =
          parts.length >= 3 && RegExp(r'^\d{2}:\d{2}$').hasMatch(parts[2]);
      final hasSearchQuery = parts.length > (hasTime ? 3 : 2);
      final timeStr = hasTime ? parts[2] : null;
      final searchQuery = hasSearchQuery
          ? parts.sublist(hasTime ? 3 : 2).join(' ').toLowerCase()
          : null;

      // Always filter by date first
      final dateTime = hasTime
          ? DateTime.parse('$dateStr $timeStr')
          : DateTime.parse(dateStr);

      List<Task> tasks = hasTime
          ? await _scheduleService.getSchedulesForDateTime(dateTime)
          : await _scheduleService.getSchedulesForDate(dateTime);

      // Filter incomplete tasks
      tasks = tasks.where((task) => !task.done).toList();

      // Apply search query if provided
      if (searchQuery != null && tasks.isNotEmpty) {
        tasks =
            await _scheduleService.searchTasksWithRelevance(searchQuery, tasks);
      }

      if (tasks.isEmpty) {
        _addMessage(ChatMessage(
          user: scheduleBot,
          createdAt: DateTime.now(),
          text: "No tasks found for the given query.",
          isMarkdown: true,
        ));
        return;
      }

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => TaskDeleteDialog(
            tasks: tasks,
            onDelete: _deleteSelectedTask,
          ),
        );
      }
    } catch (e) {
      print("Error parsing delete command: $e");
      _addMessage(ChatMessage(
        user: scheduleBot,
        createdAt: DateTime.now(),
        text:
            "Error retrieving tasks. Please ensure the date format is YYYY-MM-DD.",
        isMarkdown: true,
      ));
    }
  }

  void _deleteSelectedTask(List<Task> selectedTasks) async {
    final taskCount = selectedTasks.length;
    final taskWord = taskCount == 1 ? 'task' : 'tasks';

    final tasksDetail = selectedTasks.map((task) {
      final dateStr = DateFormat('EEEE, MMM d, y').format(task.time);
      final timeStr = DateFormat('h:mm a').format(task.time);
      return """
📌 **${task.title}**\n\n
   • 📅 Date: **$dateStr**\n\n
   • ⏰ Time: **$timeStr**\n\n
   • 🏷️ Category: **${task.category}**""";
    }).join('\n\n\n\n');

    String deleteDetails = """
🗑️ **Task Deletion Confirmation**

Successfully deleted $taskCount $taskWord:

$tasksDetail

✨ Your schedule has been updated successfully! Need anything else? I'm here to help! 🤝
""";

    for (var task in selectedTasks) {
      await _scheduleService.deleteSchedule(task.id);
    }

    _addMessage(ChatMessage(
      user: scheduleBot,
      createdAt: DateTime.now(),
      text: deleteDetails.trim(),
      isMarkdown: true,
    ));
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

class TaskViewDialog extends StatelessWidget {
  final String date;
  final Map<String, List<Map<String, String>>> tasksByCategory;

  TaskViewDialog({
    super.key,
    required this.date,
    required this.tasksByCategory,
  });

  @override
  Widget build(BuildContext context) {
    final totalTasks = tasksByCategory.values.expand((tasks) => tasks).length;
    final completedTasks = tasksByCategory.values
        .expand((tasks) => tasks)
        .where((task) => task['status'] == '✅')
        .length;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior:
            Clip.antiAlias, // Ensures content doesn't overflow rounded corners
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(context),
            if (!date.startsWith('Search'))
              _buildProgressIndicator(context, completedTasks, totalTasks),
            Flexible(
              child: _buildTaskList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color headerColor =
        isDark ? const Color(0xFF1E1E2C) : theme.primaryColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            headerColor,
            Color.lerp(headerColor, Colors.black, 0.2) ?? headerColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          // Date display with icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 16),

          // Title and date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks Overview',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Close button
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(50),
            child: InkWell(
              borderRadius: BorderRadius.circular(50),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(
      BuildContext context, int completed, int total) {
    final progress = total > 0 ? completed / total : 0.0;
    final ThemeData theme = Theme.of(context);
    final Color progressColor = theme.primaryColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: progressColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.check_circle_outline_rounded,
                      color: progressColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Today\'s Progress',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: progressColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completed/$total',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: progressColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom progress bar
          Stack(
            children: [
              // Background
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),

              // Progress fill
              LayoutBuilder(
                builder: (context, constraints) {
                  return Container(
                    height: 12,
                    width: constraints.maxWidth * progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          progressColor,
                          Color.lerp(progressColor, Colors.white, 0.3) ??
                              progressColor,
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: progressColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),

          // Progress percentage
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${(progress * 100).toStringAsFixed(1)}% completed',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Modified to pass context to CategorySection
  Widget _buildTaskList(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ...tasksByCategory.entries.map((entry) {
            return SliverToBoxAdapter(
              child: CategorySection(
                category: entry.key,
                tasks: entry.value,
                onTaskTap: (taskData) =>
                    _navigateToTaskDetails(context, taskData),
              ),
            );
          }).toList(),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  // Add the navigate to task details function
  void _navigateToTaskDetails(
      BuildContext context, Map<String, String> taskData) async {
    ScheduleService _scheduleService = ScheduleService();
    try {
      // Assuming taskData contains a taskId
      final taskId = taskData['taskID'];
      if (taskId == null) {
        throw Exception('Task ID is missing');
      }

      final task = await _scheduleService.getScheduleById(taskId);

      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              TaskDetailsScreen(task: task),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SharedAxisTransition(
              animation: animation,
              secondaryAnimation: secondaryAnimation,
              transitionType: SharedAxisTransitionType.scaled,
              child: child,
            );
          },
        ),
      );
    } catch (e) {
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading task details: ${e.toString()}')),
      );
    }
  }
}

class CategorySection extends StatefulWidget {
  final String category;
  final List<Map<String, String>> tasks;
  final Function(Map<String, String>) onTaskTap;

  const CategorySection({
    super.key,
    required this.category,
    required this.tasks,
    required this.onTaskTap,
  });

  @override
  State<CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<CategorySection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.easeInOut));

    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final completedTasks =
        widget.tasks.where((task) => task['status'] == '✅').length;

    return Column(
      children: [
        InkWell(
          onTap: _toggleExpanded,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                // Category icon (can be customized based on category name)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(widget.category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(widget.category),
                    color: _getCategoryColor(widget.category),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),

                // Category name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.category,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '$completedTasks/${widget.tasks.length} tasks',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // Expand/collapse icon
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Animated tasks list
        AnimatedBuilder(
          animation: _controller.view,
          builder: (context, child) {
            return ClipRect(
              child: Align(
                heightFactor: _heightFactor.value,
                child: child,
              ),
            );
          },
          child: Column(
            children: [
              const SizedBox(height: 8),
              ...widget.tasks
                  .map((task) => _buildTaskItem(context, task))
                  .toList(),
              const SizedBox(height: 8),
            ],
          ),
        ),

        const Divider(),
      ],
    );
  }

  Widget _buildTaskItem(BuildContext context, Map<String, String> task) {
    final ThemeData theme = Theme.of(context);
    final bool isCompleted = task['status'] == '✅';
    final hasLink = task['url'] != null && task['url']!.isNotEmpty;
    final placeURL = task['placeURL']?.toString().trim();
    final hasPlaceLink = placeURL != null && placeURL.isNotEmpty;
    final hasTime = task['time'] != null && task['time']!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => widget.onTaskTap(task),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isCompleted
                ? Colors.green.withOpacity(0.05)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isCompleted
                  ? Colors.green.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Task status indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        isCompleted
                            ? Icons.check_rounded
                            : Icons.circle_outlined,
                        color: isCompleted ? Colors.green : Colors.grey,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Task title
                  Expanded(
                    child: Text(
                      task['title'] ?? 'Untitled Task',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isCompleted
                            ? theme.colorScheme.onSurface.withOpacity(0.6)
                            : theme.colorScheme.onSurface,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),

                  // Priority indicator
                  if (task['priority'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task['priority'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task['priority'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getPriorityColor(task['priority']),
                        ),
                      ),
                    ),
                ],
              ),

              // Time indicator - New addition
              if (hasTime)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 36),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: theme.colorScheme.primary.withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${task['date']} | ${task['time']}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.primary.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),

              // URL and Location links
              if (hasLink || hasPlaceLink)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 36),
                  child: Row(
                    children: [
                      if (hasLink) UrlLinkButton(url: task['url']!),
                      if (hasLink && hasPlaceLink) const SizedBox(width: 12),
                      if (hasPlaceLink) UrlLinkButton(url: placeURL)
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Colors.blue;
      case 'personal':
        return Colors.purple;
      case 'shopping':
        return Colors.orange;
      case 'health':
        return Colors.green;
      case 'finance':
        return Colors.indigo;
      default:
        return Colors.teal;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return Icons.work_outline;
      case 'personal':
        return Icons.person_outline;
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'health':
        return Icons.favorite_border;
      case 'finance':
        return Icons.account_balance_outlined;
      default:
        return Icons.list_alt_outlined;
    }
  }

  Color _getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

// Placeholder dialog widget (customize as needed)
class FreeTimeDialog extends StatelessWidget {
  final String date;
  final List<Map<String, DateTime>> freeSlots;
  final List<Task> tasks;

  const FreeTimeDialog({
    super.key,
    required this.date,
    required this.freeSlots,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime parsedDate = DateTime.parse(date);
    final String formattedDate =
        DateFormat('EEEE, MMM d, y').format(parsedDate);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Free Time Explorer',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          formattedDate,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Timeline content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: TimelineView(
                  freeSlots: freeSlots,
                  tasks: tasks,
                  date: parsedDate,
                ),
              ),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // TextButton.icon(
                  //   onPressed: () {
                  //     // Logic to add a new task would go here
                  //     Navigator.pop(context, 'add');
                  //   },
                  //   icon: Icon(Icons.add),
                  //   label: Text('Add Task'),
                  // ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TimelineView extends StatelessWidget {
  final List<Map<String, DateTime>> freeSlots;
  final List<Task> tasks;
  final DateTime date;

  const TimelineView({
    super.key,
    required this.freeSlots,
    required this.tasks,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    // Combine tasks and free slots to create a complete timeline
    final List<TimelineItem> timelineItems = [];

    // Create timeline items for tasks
    for (var task in tasks) {
      final taskEnd =
          task.time.add(const Duration(hours: 1)); // Assuming 1-hour duration
      timelineItems.add(
        TimelineItem(
          startTime: task.time,
          endTime: taskEnd,
          isTask: true,
          title: task.title,
          color: _getTaskColor(task),
        ),
      );
    }

    // Create timeline items for free slots
    for (var slot in freeSlots) {
      timelineItems.add(
        TimelineItem(
          startTime: slot['start']!,
          endTime: slot['end']!,
          isTask: false,
          title: 'Free Time',
          color: Colors.green.shade100,
        ),
      );
    }

    // Sort all items by start time
    timelineItems.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Extract free time blocks for summary section
    final List<TimelineItem> freeTimeBlocks =
        timelineItems.where((item) => !item.isTask).toList();

    // Build the timeline
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Day at a Glance',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // New Free Time Summary Section
          if (freeTimeBlocks.isNotEmpty)
            _buildFreeTimeSummary(context, freeTimeBlocks),

          const SizedBox(height: 24),
          Text(
            'Detailed Schedule',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...timelineItems.map((item) => _buildTimelineItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildFreeTimeSummary(
      BuildContext context, List<TimelineItem> freeTimeBlocks) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                'Free Time Blocks',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: freeTimeBlocks.map((block) {
              // Format time range in a readable way
              final startFormat = DateFormat('h:mm a').format(block.startTime);
              final endFormat = DateFormat('h:mm a').format(block.endTime);
              final duration = block.endTime.difference(block.startTime);

              // Create a nice summary chip for each free time block
              return InkWell(
                onTap: () {
                  // Navigate to schedule creation with this time slot
                  Navigator.pop(context, {
                    'action': 'schedule',
                    'startTime': block.startTime,
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$startFormat - $endFormat',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          duration.inMinutes >= 60
                              ? '${duration.inHours}h ${duration.inMinutes % 60}m'
                              : '${duration.inMinutes}m',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, TimelineItem item) {
    final duration = item.endTime.difference(item.startTime);
    final durationText = duration.inMinutes >= 60
        ? '${duration.inHours}h ${duration.inMinutes % 60}m'
        : '${duration.inMinutes}m';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time column
            SizedBox(
              width: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('h:mm a').format(item.startTime),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    DateFormat('h:mm a').format(item.endTime),
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Timeline connector
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: item.isTask
                          ? Theme.of(context).primaryColor
                          : Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Icon(
                      item.isTask ? Icons.event : Icons.free_cancellation,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
            ),

            // Content card
            Expanded(
              child: Card(
                elevation: 2,
                color: item.color,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            item.isTask ? Icons.work : Icons.free_breakfast,
                            size: 16,
                            color: item.isTask
                                ? Colors.black87
                                : Colors.green.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: item.isTask
                                    ? Colors.black87
                                    : Colors.green.shade800,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              durationText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // if (!item.isTask)
                      //   Align(
                      //     alignment: Alignment.centerRight,
                      //     child: TextButton.icon(
                      //       onPressed: () {
                      //         // Function to schedule a task in this free slot
                      //         Navigator.pop(context, {
                      //           'action': 'schedule',
                      //           'startTime': item.startTime,
                      //         });
                      //       },
                      //       icon: Icon(Icons.add_task, size: 16),
                      //       label: Text('Schedule Here'),
                      //       style: TextButton.styleFrom(
                      //         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      //         minimumSize: Size.zero,
                      //         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      //         textStyle: TextStyle(fontSize: 12),
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTaskColor(Task task) {
    // Assign colors based on task properties, priority, or category
    // This is just a placeholder - you can customize logic based on your Task model
    switch (task.priority.toLowerCase()) {
      case 'high':
        return Colors.red.shade200;
      case 'medium':
        return Colors.orange.shade200;
      case 'low':
        return Colors.green.shade200;
      default:
        return Colors.blue.shade200;
    }
  }
}

class TimelineItem {
  final DateTime startTime;
  final DateTime endTime;
  final bool isTask;
  final String title;
  final Color color;

  TimelineItem({
    required this.startTime,
    required this.endTime,
    required this.isTask,
    required this.title,
    required this.color,
  });
}
