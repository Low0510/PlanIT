import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:planit_schedule_manager/screens/login_screen.dart'; // Make sure this path is correct
import 'dart:ui'; // Needed for Color.lerp

// Data structure for onboarding content
class OnboardingFeature {
  final String title;
  final String description;
  final String imagePath;
  final Color startColor; // Start color for gradient/transition
  final Color endColor;   // End color for gradient/transition

  OnboardingFeature({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.startColor,
    required this.endColor,
  });
}

class OnboardingScreen extends StatefulWidget {
  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _pageOffset = 0.0; // To track fractional page position for transitions

  // --- Onboarding Content ---
  final List<OnboardingFeature> _features = [
    OnboardingFeature(
      title: 'Meet Your AI Buddy',
      description:
          'Your intelligent companion that transforms scheduling into a delightful experience.',
      imagePath: 'assets/images/vector_chatbot.png',
      startColor: Color(0xFFE3F2FD), // Light Blue 50
      endColor: Color(0xFFBBDEFB),   // Light Blue 100
    ),
    OnboardingFeature(
      title: 'Smart Calendar Magic',
      description:
          'Seamlessly manage events, sync tasks, and stay ahead of your schedule with intuitive insights.',
      imagePath: 'assets/images/vector_calendar.png',
      startColor: Color(0xFFE0F2F1), // Teal 50
      endColor: Color(0xFFB2DFDB),   // Teal 100
    ),
    OnboardingFeature(
      title: 'Weather-Aware Planning',
      description:
          'Real-time weather updates that help you plan your day with precision and comfort.',
      imagePath: 'assets/images/vector_weather.png',
      startColor: Color(0xFFE3F2FD), // Blue 50 (Using Light Blue again for variety)
      endColor: Color(0xFFB3E5FC),   // Light Blue 100 (Slightly different shade)
    ),
    OnboardingFeature(
      title: 'Project 50 Goals',
      description:
          'Track, visualize, and celebrate your progress as you transform your aspirations into achievements.',
      imagePath: 'assets/images/vector_project50.png',
      startColor: Color(0xFFE8EAF6), // Indigo 50
      endColor: Color(0xFFC5CAE9),   // Indigo 100
    ),
  ];
  // --- End Onboarding Content ---


  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() {
        _pageOffset = _pageController.page ?? 0.0;
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Function to interpolate background color based on page offset
  Color _getBackgroundColor(double pageOffset) {
    int N = _features.length;
    int page = pageOffset.floor();
    double t = pageOffset - page; // Factor for lerp (0.0 to 1.0)

    Color startColor = _features[page % N].startColor;
    Color endColor = _features[(page + 1) % N].endColor;

    // Interpolate between the current page's start color and the next page's end color
    // Adjust logic slightly for better visual transition
    Color color1 = Color.lerp(_features[page % N].startColor, _features[page % N].endColor, t) ?? _features[page % N].startColor;
    Color color2 = Color.lerp(_features[(page + 1) % N].startColor, _features[(page + 1) % N].endColor, t) ?? _features[(page + 1) % N].startColor;

    // Interpolate between the interpolated colors of adjacent pages
    return Color.lerp(color1, color2, t) ?? color1;

  }

   // Function to interpolate accent color (for buttons, indicator)
  Color _getAccentColor(double pageOffset) {
    // Use a slightly darker shade derived from the background for accents
    // Or define specific accent colors per feature
    int page = pageOffset.floor();
    double t = pageOffset - page;
    Color currentAccent = _darken(_features[page % _features.length].endColor, 0.4);
    Color nextAccent = _darken(_features[(page + 1) % _features.length].startColor, 0.4);
    return Color.lerp(currentAccent, nextAccent, t) ?? currentAccent;
  }

  // Helper to darken a color
  Color _darken(Color color, [double amount = .1]) {
    assert(amount >= 0 && amount <= 1);
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final Color currentAccentColor = _getAccentColor(_pageOffset);
    final Color currentBackgroundColor = _getBackgroundColor(_pageOffset);

    return Scaffold(
      // Animated Background Container
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 0), // Background changes instantly via lerp
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getBackgroundColor(_pageOffset), // Use the interpolated color
              _darken(_getBackgroundColor(_pageOffset), 0.05), // Slightly darker shade for gradient
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- Top Row: Skip Button ---
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0, right: 16.0),
                  child: TextButton(
                    onPressed: _navigateToLogin,
                    style: TextButton.styleFrom(
                      foregroundColor: currentAccentColor, // Dynamic accent color
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),

              // --- Main Content: PageView ---
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _features.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      // Note: _pageOffset is updated by the listener
                    });
                  },
                  itemBuilder: (context, index) {
                    // Pass interpolated values for potential parallax or animations later
                    return _buildOnboardingPage(
                      feature: _features[index],
                      pageOffset: _pageOffset,
                      index: index,
                      accentColor: currentAccentColor,
                    );
                  },
                ),
              ),

              // --- Bottom Section: Indicator and Navigation ---
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 25.0),
                child: Column(
                  children: [
                    // Page Indicator
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: _features.length,
                      effect: ExpandingDotsEffect( // Changed effect
                        dotColor: currentAccentColor.withOpacity(0.3),
                        activeDotColor: currentAccentColor,
                        dotHeight: 10,
                        dotWidth: 10,
                        expansionFactor: 3,
                        spacing: 8,
                      ),
                    ),
                    const SizedBox(height: 35), // Increased spacing

                    // Navigation Buttons Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Previous Button (Fades in/out)
                        AnimatedOpacity(
                          opacity: _currentPage > 0 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: TextButton(
                            onPressed: _currentPage > 0
                                ? () {
                                    _pageController.previousPage(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOutCubic,
                                    );
                                  }
                                : null, // Disable onPressed when not visible
                            style: TextButton.styleFrom(
                              foregroundColor: currentAccentColor,
                            ),
                            child: const Text(
                              'Previous',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        // Next / Get Started Button
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentAccentColor, // Dynamic accent color
                            foregroundColor: currentBackgroundColor, // Contrast color
                            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 3,
                            shadowColor: Colors.black.withOpacity(0.2),
                          ),
                          onPressed: () {
                            if (_currentPage < _features.length - 1) {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOutCubic,
                              );
                            } else {
                              _navigateToLogin();
                            }
                          },
                          child: Text(
                            _currentPage < _features.length - 1 ? 'Next' : 'Get Started',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Builds the content for a single page ---
  Widget _buildOnboardingPage({
    required OnboardingFeature feature,
    required double pageOffset,
    required int index,
    required Color accentColor,
  }) {
    // Calculate offset for potential parallax (optional)
    double gauss = Curves.easeOutExpo.transform(
      (1 - (pageOffset.abs() - index)).clamp(0.0, 1.0),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image with potential subtle scale based on gauss
          Transform.scale(
            scale: gauss * 0.3 + 0.9, // Scale between 0.8 and 1.0
            child: Image.asset(
              feature.imagePath,
              height: MediaQuery.of(context).size.height * 0.35, // Relative height
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 40), // More space

          // Title Text
          Text(
            feature.title,
            style: TextStyle(
              fontSize: 26, // Larger font
              fontWeight: FontWeight.bold,
              color: _darken(accentColor, 0.1), // Darker accent
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 15),

          // Description Text
          Text(
            feature.description,
            style: TextStyle(
              fontSize: 16,
              color: _darken(accentColor, 0.05).withOpacity(0.85), // Slightly lighter than title
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30), // Bottom spacing within page content
        ],
      ),
    );
  }

  // --- Navigation Logic ---
  void _navigateToLogin() {
    // Consider adding a fade-out transition if desired
    Navigator.of(context).pushReplacement(
      // Fade Transition Route
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500), // Adjust duration
      ),
      // Or keep the simple MaterialPageRoute:
      // MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }
}