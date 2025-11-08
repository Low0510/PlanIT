import 'dart:math';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';

class MotivationWidget extends StatefulWidget {
  final String selectedEmotion;

  const MotivationWidget({Key? key, required this.selectedEmotion}) : super(key: key);

  @override
  _MotivationWidgetState createState() => _MotivationWidgetState();
}

class _MotivationWidgetState extends State<MotivationWidget> {
  // Emotion-specific motivational messages
  final Map<String, List<String>> emotionMotivations = {
  '😆': [
    "You're loving this! Keep it up! 😄",
    "Great energy! Keep that positive vibe! ✨",
    "Your enjoyment is contagious! Spread the joy! 😊",
    "So happy to see you thriving! 🎉",
    "Keep on shining, you're doing amazing! 🌟"
  ],
  '😍': [
    "This task is made for you! You're a natural! 👌",
    "You're in your element! Keep crushing it! 💪",
    "Perfect fit! You're doing an amazing job! 🎯",
    "You make this look easy! Keep it up! 😎",
    "This task is yours to conquer! You've got this! 🏆"
  ],
  '🥳': [
    "You did it! Congrats on the milestone! 🎉",
    "Time to celebrate! You earned it! 🥂",
    "Huge win! All your hard work paid off! 👏",
    "Another goal achieved! You're on fire! 🔥",
    "You're making great progress! Celebrate the win! 🎊"
  ],
  '🥴': [
    "Take a breather, you've got a lot on your plate. 😮‍💨",
    "It's okay to feel overwhelmed. Take it one step at a time. 🚶‍♀️",
    "Remember to pace yourself. You can do this! 💪",
    "Don't be afraid to ask for help. We all need it sometimes. 🤝",
    "You're strong and capable, even when it's tough. Hang in there! 🌟"
  ],
  '😡': [
    "Don't let setbacks stop you. You're stronger than this! 💪",
    "Channel that frustration into finding a solution. You've got this! 🧠",
    "It's okay to be angry. Use that energy to push forward. 🔥",
    "Obstacles are temporary. You'll overcome this! 🚧",
    "Keep your eyes on the goal. You'll break through! 🎯"
  ],
  '😢': [
    "It's okay to ask for help. You don't have to go it alone. 🤝",
    "We're here to support you. What do you need? 🤗",
    "Don't be afraid to reach out. We all need a hand sometimes. 🆘",
    "You're not alone in this. Let's tackle it together. 👥",
    "Asking for help is a sign of strength, not weakness. 💪"
  ],
  '😫': [
    "You're in a tough spot, but you can get through this. Hang in there! 💪",
    "Take a deep breath. We'll find a solution together. 🤝",
    "Don't panic. Let's figure this out step by step. 👣",
    "You're not alone. Help is available. Reach out! 🆘",
    "This is urgent, but you're capable of handling it. You've got this! 🔥"
  ],
  '🚀': [
    "You're making great progress! Keep up the momentum!  গতিবেগ",
    "You're on a roll! Nothing can stop you now! 🚀",
    "Full speed ahead! You're crushing your goals! 🎯",
    "You're moving fast and achieving big things! Keep it up! ✨",
    "Your hard work is paying off! Keep going! You're unstoppable! 💪"
  ],
};

  late String _currentMotivation;

  @override
  void initState() {
    super.initState();
    _generateMotivation();
  }

  void _generateMotivation() {
    // Get the list of motivations for the selected emotion
    final motivationList = emotionMotivations[widget.selectedEmotion] ??
        ['You are capable of amazing things!'];

    // Randomly select a motivation
    setState(() {
      _currentMotivation =
          motivationList[Random().nextInt(motivationList.length)];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Emotion icon
          Text(
            widget.selectedEmotion,
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 16),
          // Motivation text
          Expanded(
            child: AnimatedTextKit(
              animatedTexts: [
                TypewriterAnimatedText(
                  _currentMotivation,
                  textStyle: TextStyle(
                    fontFamily: 'Caveat',
                    fontSize: 30,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              isRepeatingAnimation: false,
              repeatForever: false,
              onFinished: () {
                // Optional: Add any action when animation completes
              },
            ),
          ),
          // Refresh button
          // IconButton(
          //   icon: const Icon(Icons.refresh, color: Colors.grey),
          //   onPressed: _generateMotivation,
          // ),
        ],
      ),
    );
  }
}

// Example of how to use the MotivationWidget
void showMotivationDialog(BuildContext context, String emotion) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.white.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: MotivationWidget(selectedEmotion: emotion),
      );
    },
  );
}