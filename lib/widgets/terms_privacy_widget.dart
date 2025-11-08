import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // Import for launching URLs

class TermsAndPrivacyWidget extends StatefulWidget {
  final Function(bool) onAgreementChanged;

  const TermsAndPrivacyWidget({Key? key, required this.onAgreementChanged}) : super(key: key);

  @override
  _TermsAndPrivacyWidgetState createState() => _TermsAndPrivacyWidgetState();
}

class _TermsAndPrivacyWidgetState extends State<TermsAndPrivacyWidget> {
  bool _agreedToTerms = false;

  // Helper to launch URLs
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      // Optionally, show a snackbar or alert if the URL can't be launched
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not launch $urlString')),
      );
    }
  }

  // --- START: Helper methods for styling text ---
  TextStyle _contentBaseStyle(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      height: 1.5,
      color: Colors.grey[700],
    );
  }

  TextStyle _sectionTitleStyle(BuildContext context) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
      color: Colors.grey[850],
      height: 2.0,
    );
  }

  TextStyle _listItemStyle(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      height: 1.6,
      color: Colors.grey[700],
    );
  }

  TextStyle _linkStyle(BuildContext context) {
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).primaryColor,
      decoration: TextDecoration.underline,
      height: 1.6,
    );
  }

  TextStyle _emailLinkStyle(BuildContext context) {
    return _linkStyle(context).copyWith(decoration: TextDecoration.none); // Email usually not underlined
  }
  // --- END: Helper methods for styling text ---


  // --- START: Helper methods for building content ---
  List<TextSpan> _buildTermsContent(BuildContext context) {
    final baseStyle = _contentBaseStyle(context);
    final titleStyle = _sectionTitleStyle(context);
    final itemStyle = _listItemStyle(context);
    final emailStyle = _emailLinkStyle(context);
    final linkStyle = _linkStyle(context);

    return [
      TextSpan(text: "Welcome to PlanIT! 📅\n\n", style: baseStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
      TextSpan(text: "Thanks for using our schedule manager app. Here are the basic rules:\n\n", style: baseStyle),

      TextSpan(text: "🎯 What PlanIT Does\n", style: titleStyle),
      TextSpan(text: "• Helps you organize your daily schedule\n", style: itemStyle),
      TextSpan(text: "• Lets you create, edit, and manage your tasks\n", style: itemStyle),
      TextSpan(text: "• Provides a chatbot assistant for help and information\n", style: itemStyle),
      TextSpan(text: "• Offers weather information to help plan your day\n", style: itemStyle),
      TextSpan(text: "• Keeps your schedule data safe and accessible\n\n", style: itemStyle),

      TextSpan(text: "👤 Your Account\n", style: titleStyle),
      TextSpan(text: "• You need to create an account to save your schedules\n", style: itemStyle),
      TextSpan(text: "• Keep your login details safe - that's your responsibility\n", style: itemStyle),
      TextSpan(text: "• Don't share your account with others\n\n", style: itemStyle),

      TextSpan(text: "✅ How to Use PlanIT\n", style: titleStyle),
      TextSpan(text: "• Use the app for managing your personal schedules\n", style: itemStyle),
      TextSpan(text: "• Don't try to break or hack the app\n\n", style: itemStyle),

      TextSpan(text: "🛠️ Third-Party Services\n", style: titleStyle),
      TextSpan(text: "Our app integrates certain third-party services to enhance your experience:\n", style: baseStyle),
      TextSpan(text: "  • ", style: baseStyle),
      TextSpan(text: "Chatbot Assistant: ", style: itemStyle.copyWith(fontWeight: FontWeight.w600)),
      TextSpan(text: "Our chatbot feature is powered by Google's generative AI models. Your interactions are processed by Google. By using the chatbot, you agree to Google's terms, which you can review at their respective policy pages.\n", style: itemStyle),
      TextSpan(text: "  • ", style: baseStyle),
      TextSpan(text: "Weather Information: ", style: itemStyle.copyWith(fontWeight: FontWeight.w600)),
      TextSpan(text: "Weather data is provided by OpenWeather API. Your use of weather features may involve sharing generalized location data with OpenWeather, subject to their terms. You can find more information on the ", style: itemStyle),
      TextSpan(
          text: "OpenWeather website",
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _launchUrl('https://openweathermap.org/terms'), // Example URL
      ),
      TextSpan(text: ".\n\n", style: itemStyle),
      TextSpan(text: "By using these features, you also agree to the respective terms of service of these third-party providers. We encourage you to review their terms and privacy policies.\n\n", style: itemStyle),


      TextSpan(text: "📱 About the App\n", style: titleStyle),
      TextSpan(text: "• This is a student project for Computer Science degree\n", style: itemStyle),
      TextSpan(text: "• We own the app design and code (excluding third-party services)\n", style: itemStyle),
      TextSpan(text: "• We might add new features or fix bugs anytime\n\n", style: itemStyle),

      TextSpan(text: "⚠️ Important Notes\n", style: titleStyle),
      TextSpan(text: "• We're not responsible if something goes wrong with your device or due to third-party services\n", style: itemStyle),
      TextSpan(text: "• We can't guarantee the app will work 100% perfectly all the time\n", style: itemStyle),
      TextSpan(text: "• We might need to update or change the app sometimes\n\n", style: itemStyle),

      TextSpan(text: "📧 Questions?\n", style: titleStyle),
      TextSpan(text: "If you have any questions about these terms or bugs, just email us at ", style: baseStyle),
      TextSpan(
        text: "himouse21@gmail.com",
        style: emailStyle,
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl('mailto:himouse21@gmail.com'),
      ),
      TextSpan(text: ".\n\n", style: baseStyle),

      TextSpan(text: "Thanks for understanding! 😊", style: baseStyle.copyWith(fontStyle: FontStyle.italic)),
    ];
  }

  List<TextSpan> _buildPrivacyPolicyContent(BuildContext context) {
    final baseStyle = _contentBaseStyle(context);
    final titleStyle = _sectionTitleStyle(context);
    final itemStyle = _listItemStyle(context);
    final emailStyle = _emailLinkStyle(context);
    final linkStyle = _linkStyle(context);
    final boldItemStyle = itemStyle.copyWith(fontWeight: FontWeight.w600);

    return [
      TextSpan(text: "Your Privacy Matters! 🔒\n\n", style: baseStyle.copyWith(fontSize: 15, fontWeight: FontWeight.w500)),
      TextSpan(text: "We want to be clear about how we handle your information:\n\n", style: baseStyle),

      TextSpan(text: "📝 What We Collect\n", style: titleStyle),
      TextSpan(text: "• Your basic account info (like email and name)\n", style: itemStyle),
      TextSpan(text: "• Your schedule data (tasks, events, reminders)\n", style: itemStyle),
      TextSpan(text: "• How you use the app (to make it better)\n", style: itemStyle),
      TextSpan(text: "• Anonymized interaction data with third-party services like our Chatbot and Weather API for service improvement and functionality.\n\n", style: itemStyle),


      TextSpan(text: "🛡️ How We Use Your Info\n", style: titleStyle),
      TextSpan(text: "• To save and sync your schedules\n", style: itemStyle),
      TextSpan(text: "• To provide personalized features like chatbot assistance and weather updates\n", style: itemStyle),
      TextSpan(text: "• To help you when you need support\n", style: itemStyle),
      TextSpan(text: "• To improve the app based on how people use it\n\n", style: itemStyle),

      TextSpan(text: "🤝 Sharing Your Data\n", style: titleStyle),
      TextSpan(text: "We DON'T sell your personal information to anyone. However, to provide certain features, we work with third-party services:\n\n", style: baseStyle.copyWith(height: 1.6)),

      TextSpan(text: "  🤖 Chatbot Assistant (Powered by Google):\n", style: boldItemStyle),
      TextSpan(text: "  • When you use our chatbot (powered by Google's generative AI, e.g., Gemini), your queries and conversation context are sent to Google to generate responses.\n", style: itemStyle),
      TextSpan(text: "  • Google processes this data according to its ", style: itemStyle),
      TextSpan(
        text: "Privacy Policy",
        style: linkStyle,
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl('https://support.google.com/gemini/answer/13594961?hl=en'), 
      ),
      TextSpan(text: ". We recommend reviewing it.\n", style: itemStyle),
      TextSpan(text: "  • We aim to minimize the personal data sent and do not store your full chat conversations on our servers beyond what's necessary for the ongoing interaction and improvement of our service integration.\n\n", style: itemStyle),

      TextSpan(text: "  🌦️ Weather Information (OpenWeather API):\n", style: boldItemStyle),
      TextSpan(text: "  • To provide weather forecasts, we may send your general location (e.g., city, or more specific coordinates if you grant location permission) to OpenWeather API.\n", style: itemStyle),
      TextSpan(text: "  • OpenWeather uses this data according to its ", style: itemStyle),
      TextSpan(
        text: "Privacy Policy",
        style: linkStyle,
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl('https://openweather.co.uk/privacy-policy'),
      ),
      TextSpan(text: ". We encourage you to review their policy.\n\n", style: itemStyle),
      TextSpan(text: "Please note: We are not responsible for the data practices of these third-party services. Their use of your information is governed by their own privacy policies.\n\n", style: itemStyle.copyWith(fontStyle: FontStyle.italic)),


      TextSpan(text: "🔐 Keeping Your Data Safe\n", style: titleStyle),
      TextSpan(text: "• We use secure methods to protect your information stored on our systems\n", style: itemStyle),
      TextSpan(text: "• Your schedule data is stored safely in our database\n", style: itemStyle),
      TextSpan(text: "• We regularly review our security measures\n\n", style: itemStyle),

      TextSpan(text: "⏰ How Long We Keep Your Data\n", style: titleStyle),
      TextSpan(text: "• As long as you have an account with us\n", style: itemStyle),
      TextSpan(text: "• If you delete your account, we'll delete your directly stored personal data too\n", style: itemStyle),

      TextSpan(text: "📱 This is a Student Project\n", style: titleStyle),
      TextSpan(text: "Remember, this is a final year project for a Computer Science degree. We're learning and doing our best to protect your privacy and be transparent about our use of services like Google's AI and OpenWeather API!\n\n", style: itemStyle),

      TextSpan(text: "📧 Questions About Privacy?\n", style: titleStyle),
      TextSpan(text: "Email us anytime at ", style: baseStyle),
      TextSpan(
        text: "himouse21@gmail.com",
        style: emailStyle,
        recognizer: TapGestureRecognizer()..onTap = () => _launchUrl('mailto:himouse21@gmail.com'),
      ),
      TextSpan(text: ".\n\n", style: baseStyle),

      TextSpan(text: "Thanks for trusting us with your schedule! 😊", style: baseStyle.copyWith(fontStyle: FontStyle.italic)),
    ];
  }
  // --- END: Helper methods for building content ---


  Widget _buildTermsAgreement() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: (value) {
                setState(() {
                  _agreedToTerms = value!;
                  widget.onAgreementChanged(_agreedToTerms);
                });
              },
              activeColor: Theme.of(context).primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4), // Adjust this for vertical alignment with checkbox
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.4,
                  ),
                  children: [
                    TextSpan(text: 'I agree to the '),
                    TextSpan(
                      text: 'Terms of Use',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = () {
                        _showTermsOfService();
                      },
                    ),
                    TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = () {
                        _showPrivacyPolicy();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), // Slightly increased height
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description, color: Theme.of(context).primaryColor),
                      SizedBox(width: 12),
                      Text(
                        'Terms of Use',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: RichText(
                      text: TextSpan(
                        style: _contentBaseStyle(context),
                        children: _buildTermsContent(context),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20,10,20,20), // Adjusted padding
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Got it!', style: TextStyle(fontSize: 16)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
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

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85), // Slightly increased height
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.privacy_tip, color: Theme.of(context).primaryColor),
                      SizedBox(width: 12),
                      Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: RichText(
                      text: TextSpan(
                        style: _contentBaseStyle(context),
                        children: _buildPrivacyPolicyContent(context),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20,10,20,20), // Adjusted padding
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Understood!', style: TextStyle(fontSize: 16)),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
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

  @override
  Widget build(BuildContext context) {
    return _buildTermsAgreement();
  }
}