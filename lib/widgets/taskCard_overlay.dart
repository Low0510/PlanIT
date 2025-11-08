import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:planit_schedule_manager/const.dart';
import 'package:planit_schedule_manager/models/task.dart'; // Assuming your Task model is here
import 'package:planit_schedule_manager/models/weather_data.dart';
import 'package:planit_schedule_manager/screens/task_details_screen.dart';
import 'package:planit_schedule_manager/services/location_service.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/services/weather_service.dart';
import 'package:shake/shake.dart';
import 'package:url_launcher/url_launcher.dart';

// --- (DopamineColors and TaskShakeDetector remain the same) ---
class DopamineColors {
  static final List<List<Color>> colorPalettes = [
    [Color(0xFFFF6B6B), Color(0xFFFFE66D)], // Red to Yellow
    [Color(0xFF42E695), Color(0xFF3BB2B8)], // Green to Teal
    [Color(0xFFFF61D2), Color(0xFFFE9090)], // Pink to Light Pink
    [Color(0xFF4E65FF), Color(0xFF92EFFD)], // Blue to Light Blue
    [Color(0xFFA651EF), Color(0xFF6BCBEF)], // Purple to Light Blue
    [Color(0xFFFF9966), Color(0xFFFF5E62)], // Orange to Red
    [Color(0xFF6B4DFF), Color(0xFFBDB2FF)], // Deep Purple to Light Purple
    [Color(0xFF00DBDE), Color(0xFFFC00FF)], // Teal to Magenta
    [Color(0xFF0BA360), Color(0xFF3CBA92)], // Deep Green to Light Green
    [Color(0xFFFFE259), Color(0xFFFFB800)], // Yellow to Orange
  ];

  static List<Color> getRandomGradient() {
    final random = Random();
    return colorPalettes[random.nextInt(colorPalettes.length)];
  }
}

class TaskShakeDetector {
  ShakeDetector? _detector;
  final Function onShake;

  TaskShakeDetector({required this.onShake});

  void startListening() {
    _detector = ShakeDetector.autoStart(
      onPhoneShake: (dynamic event) {
        // ShakeEvent might be specific, use dynamic or Object
        onShake();
      },
      minimumShakeCount: 1,
      shakeSlopTimeMS: 800,
      shakeCountResetTime: 3000,
    );
  }

  void stopListening() {
    _detector?.stopListening();
  }
}

// Task Overlay Manager
class TaskOverlayManager {
  static OverlayEntry? _overlayEntry;
  static bool _isOverlayVisible =
      false; // Tracks if an overlay is currently supposed to be visible or animating
  static final TaskOverlayManager _instance = TaskOverlayManager._internal();

  static AnimationController? _slideController;
  static Animation<Offset>? _slideAnimation;

  factory TaskOverlayManager() => _instance;

  TaskOverlayManager._internal();

  static void _initAnimation(TickerProvider vsync) {
    _slideController?.dispose(); // Dispose previous controller if any
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800), // Animation duration
      vsync: vsync,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(
          0.0, 1.0), // Start from bottom (1.0 = 100% of its height below)
      end: Offset.zero, // End at its natural centered position
    ).animate(CurvedAnimation(
      parent: _slideController!,
      curve: Curves.easeOutCubic, // A smooth curve
    ));
  }

  // Task can be nullable
  // Requires a TickerProvider, typically 'this' from a StatefulWidget with TickerProviderStateMixin
  static void showTaskOverlay(
      BuildContext context, Task? task, TickerProvider vsync) {
    // If an overlay is already fully visible, hide it first, then show the new one.
    if (_overlayEntry != null &&
        _slideController != null &&
        _slideController!.isCompleted) {
      hideTaskOverlay().then((_) {
        // Short delay can sometimes help with visual flow if needed, but often not required
        // Future.delayed(const Duration(milliseconds: 10), () {
        _performShowNewOverlay(context, task, vsync);
        // });
      });
      return;
    }

    // If an animation is in progress (e.g., hiding), stop it and proceed to show new.
    if (_slideController != null && _slideController!.isAnimating) {
      if (_slideController!.status == AnimationStatus.reverse) {
        // If currently hiding
        _slideController!.stop();
      }
      // If it was showing, _performShowNewOverlay will re-initialize, effectively replacing it.
    }

    _performShowNewOverlay(context, task, vsync);
  }

  static void _performShowNewOverlay(
      BuildContext context, Task? task, TickerProvider vsync) {
    _initAnimation(vsync); // Initialize or re-initialize animation controller

    // Clean up any existing overlay entry immediately, in case hide didn't fully complete
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardWidth = screenWidth * TaskOverlayCard.cardWidthFraction;
    final cardHeight = screenHeight * TaskOverlayCard.cardHeightFraction;

    // Calculate the target (final) position for the card
    final targetTop = (screenHeight - cardHeight) / 2;
    final targetLeft = (screenWidth - cardWidth) / 2;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return AnimatedBuilder(
            animation: _slideAnimation!,
            builder: (context, child) {
              // Calculate opacity for the background scrim based on animation progress
              double scrimOpacity =
                  0.4 * (1.0 - _slideAnimation!.value.dy.abs());
              scrimOpacity = scrimOpacity.clamp(0.0, 0.4);

              return Stack(
                children: [
                  // Layer 1: Full-screen GestureDetector for dismissal with animated scrim
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {
                        // Only allow dismiss if card is fully shown or close to it
                        if (_slideController?.status ==
                            AnimationStatus.completed) {
                          TaskOverlayManager.hideTaskOverlay();
                        }
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: Colors.black.withOpacity(scrimOpacity),
                      ),
                    ),
                  ),
                  // Layer 2: The actual card, positioned and animated
                  Positioned(
                    top: targetTop, // Final resting Y position
                    left: targetLeft, // Final resting X position
                    width: cardWidth,
                    height: cardHeight,
                    child: SlideTransition(
                      position: _slideAnimation!, // Applies the animated offset
                      child: GestureDetector(
                        onTap: () {
                          // Absorb taps on the card itself to prevent background tap
                        },
                        child: TaskOverlayCard(
                            task: task,
                            onDismiss: () {
                              // For the 'X' button on the card
                              TaskOverlayManager.hideTaskOverlay();
                            }),
                      ),
                    ),
                  ),
                ],
              );
            });
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    _isOverlayVisible = true; // Mark as intending to be visible
    _slideController!.forward(); // Start the slide-in animation

    HapticFeedback.mediumImpact();
  }

  static Future<void> hideTaskOverlay() async {
    if (_overlayEntry == null ||
        _slideController == null ||
        (!_isOverlayVisible && !_slideController!.isAnimating)) {
      // Not visible or no entry/controller to hide, or already in process of hiding without intent.
      return;
    }

    // If already hiding or dismissed, just ensure cleanup if needed.
    if (_slideController!.status == AnimationStatus.reverse ||
        _slideController!.status == AnimationStatus.dismissed) {
      if (_slideController!.status == AnimationStatus.dismissed &&
          _overlayEntry != null) {
        // Stale entry, remove it.
        _overlayEntry?.remove();
        _overlayEntry = null;
        _isOverlayVisible = false;
      }
      return; // Already hiding or hidden.
    }

    _isOverlayVisible = false; // Mark as intending to be hidden

    final completer = Completer<void>();

    // Add a status listener to remove the overlay entry once the animation completes.
    void statusListener(AnimationStatus status) {
      if (status == AnimationStatus.dismissed) {
        _overlayEntry?.remove();
        _overlayEntry = null;
        // _slideController?.removeStatusListener(statusListener); // Clean up listener
        // The controller will be disposed on next _initAnimation or if we add explicit dispose here
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    }

    _slideController!.addStatusListener(statusListener);

    await _slideController!.reverse(); // Start slide-out animation (to bottom)

    // Defensive removal and listener cleanup
    if (_overlayEntry != null &&
        (_slideController == null ||
            _slideController!.status == AnimationStatus.dismissed)) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _slideController?.removeStatusListener(statusListener);

    // Controller is disposed in _initAnimation upon next show.
    // Or, you could dispose it here if no immediate re-show is expected:
    // _slideController?.dispose();
    // _slideController = null;
    // _slideAnimation = null;

    return completer.future;
  }

  static Future<void> hideTaskOverlayImmediately() async {
    // Renamed for clarity
    print("TaskOverlayManager: hideTaskOverlayImmediately called.");
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      print("TaskOverlayManager: OverlayEntry removed immediately.");
    } else {
      print("TaskOverlayManager: No OverlayEntry to remove immediately.");
    }

    // If the controller is still active or animating, stop and dispose it.
    if (_slideController != null) {
      if (_slideController!.isAnimating) {
        _slideController!.stop();
        print("TaskOverlayManager: SlideController stopped.");
      }
      // You might want to dispose it here if it's not going to be reused soon,
      // or let _initAnimation handle disposal on the next show.
      // For immediate hide, disposing it makes sense to clean up resources.
      _slideController!.dispose();
      _slideController = null;
      _slideAnimation = null; // Clear the animation object too
      print("TaskOverlayManager: SlideController disposed immediately.");
    } else {
      print("TaskOverlayManager: No SlideController to dispose immediately.");
    }

    _isOverlayVisible = false;
    // No animation, so we can complete a future immediately if the caller expects one.
    return Future.value();
  }
}

// Task Overlay Card Widget
class TaskOverlayCard extends StatefulWidget {
  final Task? task; // Task can be null for the empty/motivational card
  final VoidCallback onDismiss;

  static const double cardWidthFraction = 0.85;
  static const double cardHeightFraction = 0.55;

  const TaskOverlayCard({
    Key? key,
    this.task, // Updated to be nullable
    required this.onDismiss,
  }) : super(key: key);

  @override
  _TaskOverlayCardState createState() => _TaskOverlayCardState();
}

class _TaskOverlayCardState extends State<TaskOverlayCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late List<Color> _gradientColors;
  bool _showFront = true; // Only relevant if task is not null

  ScheduleService _scheduleService = ScheduleService();

  // Motivational content
  static const List<String> _motivationalQuotes = [
    "The journey of a thousand miles begins with a single step.",
    "What you do today can improve all your tomorrows.",
    "Believe you can and you're halfway there.",
    "The secret of getting ahead is getting started.",
    "Don't watch the clock; do what it does. Keep going.",
    "Your potential is endless. Go do what you were created to do.",
    "The future depends on what you do today.",
    "Dream big. Start small. Act now.",
    "Every accomplishment starts with the decision to try.",
    "Ready to make some magic happen?",
    "Create a plan. Conquer your day!",
    "A blank slate for your brilliance.",
    "What masterpiece will you create today?",
  ];

  static const List<IconData> _motivationalIcons = [
    Icons.lightbulb_outline_rounded,
    Icons.rocket_launch_outlined,
    Icons.star_outline_rounded,
    Icons.explore_outlined,
    Icons.auto_awesome_outlined, // Sparkles
    Icons.filter_vintage_outlined, // Flower-like
    Icons.emoji_events_outlined, // Trophy
    Icons.trending_up_rounded,
    Icons.wb_sunny_outlined,
    Icons.palette_outlined,
  ];

  late String _currentQuote;
  late IconData _currentIcon;

  late WeatherService _weatherService;
  late LocationService _locationService;

  // Weather State
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;
  String? _weatherError;

  @override
  void initState() {
    super.initState();
    _gradientColors = DopamineColors.getRandomGradient();

    // Initialize motivational content randomly
    final random = Random();
    _currentQuote =
        _motivationalQuotes[random.nextInt(_motivationalQuotes.length)];
    _currentIcon =
        _motivationalIcons[random.nextInt(_motivationalIcons.length)];

    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutBack,
      ),
    );

    if (widget.task != null) {
      _controller.forward(); // For the flip animation
      _weatherService = WeatherService.getInstance(OPENWEATHER_API_KEY,
          cacheDurationInMinutes: 90);
      _locationService = LocationService();
      _fetchWeatherDataForTask();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static String getWeatherIcon(
    String weatherType, {
    required DateTime? sunrise,
    required DateTime? sunset,
  }) {
    final now = DateTime.now();
    bool isDay = sunrise != null && sunset != null
        ? now.isAfter(sunrise) && now.isBefore(sunset)
        : now.hour >= 6 && now.hour < 18;

    switch (weatherType.toLowerCase()) {
      case 'clear':
        return isDay
            ? 'assets/weather_icons/day.svg'
            : 'assets/weather_icons/night.svg';
      case 'clouds':
        return isDay
            ? 'assets/weather_icons/cloud_day.svg'
            : 'assets/weather_icons/cloud_night.svg';
      case 'rain':
        return 'assets/weather_icons/rain.svg';
      case 'thunderstorm':
        return 'assets/weather_icons/thunderstorm.svg';
      case 'snow':
        return 'assets/weather_icons/snow.svg';
      default:
        return 'assets/weather_icons/cloud.svg';
    }
  }

  Future<void> _fetchWeatherDataForTask() async {
    if (!mounted) return;
    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    try {
      final position = await _locationService.determinePosition();
      final weather = await _weatherService.getWeather(
          position.latitude, position.longitude);
      _weatherService.printStats();
      if (mounted) {
        setState(() {
          _weatherData = weather;
          _isLoadingWeather = false;
        });
      }
    } catch (e) {
      print("Error fetching weather: $e");
      if (mounted) {
        setState(() {
          _weatherError = "Weather unavailable";
          _isLoadingWeather = false;
        });
      }
    }
  }

  void _flipCard() {
    if (widget.task == null || _controller.isAnimating) return;

    if (_controller.status == AnimationStatus.dismissed ||
        _controller.status == AnimationStatus.reverse) {
      _controller.forward();
    } else if (_controller.status == AnimationStatus.completed ||
        _controller.status == AnimationStatus.forward) {
      _controller.reverse();
    }
    setState(() {
      _showFront = !_showFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.task == null) {
      return _buildEmptyInspirationCard();
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _flipCard,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final isFrontAnimating = _animation.value < 0.5;
            final angle = _animation.value * pi;
            var currentRotationValue = _animation.value;
            var tilt = (currentRotationValue - 0.5).abs() * -0.002;

            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle)
                ..rotateX(tilt),
              alignment: Alignment.center,
              child: isFrontAnimating
                  ? _buildBackCard()
                  : Transform(
                      transform: Matrix4.identity()..rotateY(pi),
                      alignment: Alignment.center,
                      child: _buildFrontCard(),
                    ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnimatedShakeHint() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(
          milliseconds: 1800), // Slightly longer for a nice effect
      curve: Curves
          .elasticOut, // This curve provides a natural "spring" or "bounce"
      builder: (context, value, child) {
        return Opacity(
          opacity:
              value.clamp(0.0, 1.0), // Ensure opacity stays within valid range
          child: Transform.scale(
            scale:
                value, // The elasticOut curve makes the scale animation bouncy
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vibration,
                    color: Colors.white.withOpacity(0.85),
                    size: 20), // Slightly larger icon
                SizedBox(width: 10),
                Text(
                  "Shake for view task",
                  style: TextStyle(
                    fontSize: 15, // Slightly larger text
                    color: Colors.white.withOpacity(0.85),
                    fontWeight: FontWeight.w600, // Bolder
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCardBase(
      {required Widget child, required bool isFront, bool isEmtyCard = false}) {
    return Container(
      width:
          MediaQuery.of(context).size.width * TaskOverlayCard.cardWidthFraction,
      height: MediaQuery.of(context).size.height *
          TaskOverlayCard.cardHeightFraction,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: isEmtyCard
                ? Alignment.topCenter
                : (isFront ? Alignment.topLeft : Alignment.bottomRight),
            end: isEmtyCard
                ? Alignment.bottomCenter
                : (isFront ? Alignment.bottomRight : Alignment.topLeft),
            colors: isEmtyCard
                ? _gradientColors
                : (isFront
                    ? _gradientColors
                    : _gradientColors.reversed.toList()),
          ),
          boxShadow: [
            BoxShadow(
              color: _gradientColors[0].withOpacity(0.35),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: _gradientColors[1].withOpacity(0.25),
              blurRadius: 15,
              offset: Offset(0, 5),
            ),
          ],
          border:
              Border.all(color: Colors.white.withOpacity(0.15), width: 1.0)),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CardPatternPainter(
                  reverse: isEmtyCard ? false : !isFront,
                  seed: _gradientColors.hashCode),
            ),
          ),
          child, // Content
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.close, color: Colors.white, size: 22),
              ),
              onPressed: widget.onDismiss,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInspirationCard() {
    return _buildCardBase(
      isFront: true,
      isEmtyCard: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildAnimatedParticles(), // Keep the dynamic background
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.spaceAround, // Distribute space more evenly
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // --- Icon and Title (More integrated) ---
                Column(
                  children: [
                    SizedBox(height: 10),
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.6, end: 1.0),
                      duration: Duration(milliseconds: 1000),
                      curve: Curves.elasticOut,
                      builder: (context, double value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding:
                                EdgeInsets.all(22), // Slightly larger padding
                            decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.20),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _gradientColors[0].withOpacity(0.45),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.15),
                                    blurRadius: 10,
                                    spreadRadius: -5,
                                  ),
                                ],
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 1.2)),
                            child: Icon(
                              _currentIcon,
                              size: 64, // Larger icon
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Your Canvas is Clear!", // Shorter, more active title
                      textAlign: TextAlign.center,

                      style: TextStyle(
                        fontSize: 24, // Adjusted for impact
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.4,
                        decoration: TextDecoration.none,
                        shadows: [
                          Shadow(
                              blurRadius: 10,
                              color: Colors.black.withOpacity(0.3),
                              offset: Offset(0, 2))
                        ],
                      ),
                    ),
                  ],
                ),

                // --- Motivational Quote (Concise and centered) ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0), // Less horizontal padding for quote
                  child: Text(
                    _currentQuote, // The main piece of text
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18, // Slightly smaller to not dominate
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.95),
                      height: 1.4,
                      decoration: TextDecoration.none,
                      fontStyle: FontStyle.italic,
                      shadows: [
                        Shadow(
                            blurRadius: 6,
                            color: Colors.black.withOpacity(0.25),
                            offset: Offset(0, 1))
                      ],
                    ),
                    maxLines: 3, // Limit lines to keep it concise
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // --- Bottom Section: CTA and Hint ---
                Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact(); // Lighter haptic
                        widget.onDismiss();
                      },
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                        decoration: BoxDecoration(
                          // Solid color button can sometimes feel cleaner than gradient
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                                color: _gradientColors.last.withOpacity(
                                    0.3), // Use a consistent shadow color
                                blurRadius: 10,
                                offset: Offset(0, 3)),
                          ],
                        ),
                        child: Text(
                          "Got It!", // Shorter CTA
                          style: TextStyle(
                            decoration: TextDecoration.none,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 25), // More space before hint
                    _buildAnimatedShakeHint(), // Keep this, it's a core functionality hint
                    SizedBox(height: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedParticles() {
    return CustomPaint(
      painter: ParticlesPainter(
        particleColor: Colors.white.withOpacity(0.4),
        numParticles: 20,
        seed: _gradientColors.hashCode,
      ),
      size: Size.infinite,
    );
  }

  Widget _buildWeatherSection() {
    if (_isLoadingWeather) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white))),
            SizedBox(width: 10),
            Text("Checking weather...",
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (_weatherError != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: Colors.yellowAccent.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.yellowAccent, size: 18),
            SizedBox(width: 10),
            Text(_weatherError!,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 14)),
          ],
        ),
      );
    }

    if (_weatherData == null) {
      return SizedBox.shrink();
    }

    final weatherIcon = getWeatherIcon(
      _weatherData!.weather ?? 'clear',
      sunrise: _weatherData!.sunrise,
      sunset: _weatherData!.sunset,
    );

    final weatherReminder = _weatherService.getWeatherReminder(_weatherData!);
    Color weatherBgColor = _getWeatherBackgroundColor(_weatherData!.weather);

    return Container(
      margin: EdgeInsets.symmetric(vertical: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            weatherBgColor.withOpacity(0.7),
            weatherBgColor.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: weatherBgColor.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    _buildAnimatedWeatherIcon(weatherIcon),
                    SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${_weatherData!.temperature.toStringAsFixed(1)}°C",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          // Text(
                          //   "${_weatherData.}"
                          // ),
                          Text(
                            _weatherData!.locationName,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _weatherData!.description.isNotEmpty
                      ? "${_weatherData!.description[0].toUpperCase()}${_weatherData!.description.substring(1)}"
                      : "",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          // if (weatherReminder.isNotEmpty) ...[
          //   SizedBox(height: 8),
          //   Container(
          //     padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          //     decoration: BoxDecoration(
          //       color: Colors.white.withOpacity(0.2),
          //       borderRadius: BorderRadius.circular(10),
          //     ),
          //     child: Row(
          //       children: [
          //         _buildPulsingIcon(Icons.tips_and_updates_outlined),
          //         SizedBox(width: 8),
          //         Flexible(
          //           child: Text(
          //             weatherReminder,
          //             style: TextStyle(
          //               fontSize: 12,
          //               color: Colors.white.withOpacity(0.9),
          //               fontStyle: FontStyle.italic,
          //             ),
          //             maxLines: 2,
          //             overflow: TextOverflow.ellipsis,
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _buildAnimatedWeatherIcon(String svgPath) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.9, end: 1.1),
      duration: Duration(seconds: 2),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.15),
                  blurRadius: 5,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: SvgPicture.asset(
              svgPath,
              width: 30,
              height: 30,
              colorFilter: ColorFilter.mode(
                  Colors.white, BlendMode.srcIn), // Ensure color is applied
            ),
          ),
        );
      },
    );
  }

  Widget _buildPulsingIcon(IconData icon) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.8, end: 1.0),
      duration: Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Transform.scale(
          scale: value,
          child: Icon(
            icon,
            color: Colors.white.withOpacity(0.9),
            size: 16,
          ),
        );
      },
    );
  }

  Color _getWeatherBackgroundColor(String? weatherCondition) {
    if (weatherCondition == null)
      return DopamineColors.colorPalettes[7][0]; // Default teal color

    final condition = weatherCondition.toLowerCase();

    if (condition.contains('clear') || condition.contains('sun')) {
      return DopamineColors.colorPalettes[9][0]; // Yellow
    } else if (condition.contains('cloud')) {
      return DopamineColors.colorPalettes[3][0].withOpacity(0.8); // Blue
    } else if (condition.contains('rain') || condition.contains('drizzle')) {
      return DopamineColors.colorPalettes[4][0].withOpacity(0.9); // Purple
    } else if (condition.contains('snow')) {
      return DopamineColors.colorPalettes[7][0]; // Teal
    } else if (condition.contains('thunder') || condition.contains('storm')) {
      return DopamineColors.colorPalettes[6][0]; // Deep Purple
    } else if (condition.contains('mist') ||
        condition.contains('fog') ||
        condition.contains('haze') ||
        condition.contains('smoke')) {
      return DopamineColors.colorPalettes[2][1].withOpacity(0.7); // Light Pink
    }
    return DopamineColors.colorPalettes[1][0]; // Green-Teal as a fallback
  }

  Widget _buildFrontCard() {
    final task = widget.task!;
    final formattedTime =
        "${task.time.hour.toString().padLeft(2, '0')}:${task.time.minute.toString().padLeft(2, '0')}";
    final timeDifference = task.time.difference(DateTime.now());
    final bool isOverdue = timeDifference.isNegative;
    final String timeUntil = isOverdue
        ? "Overdue by ${_formatDuration(timeDifference.abs())}"
        : "In ${_formatDuration(timeDifference)}";

    return _buildCardBase(
      isFront: true,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(child: _buildCategoryChip(task.category)),
                SizedBox(width: 8),
                _buildPriorityTag(task.priority),
              ],
            ),
            SizedBox(height: 16),
            Text(
              task.title,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                      blurRadius: 3,
                      color: Colors.black38,
                      offset: Offset(0, 1))
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10),
            _buildWeatherSection(),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.alarm_rounded,
                    color: Colors.white.withOpacity(0.9), size: 26),
                SizedBox(width: 10),
                Text(
                  formattedTime,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.95),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isOverdue
                    ? Colors.red.withOpacity(0.5)
                    : Colors.white.withOpacity(0.25),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                timeUntil,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white),
              ),
            ),
            Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (task.emotion != null && task.emotion!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      task.emotion!,
                      style: TextStyle(fontSize: 26),
                    ),
                  )
                else
                  SizedBox(height: (26 * 1.5) + (8 * 2)),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.flip_camera_android_outlined,
                        color: Colors.white.withOpacity(0.7), size: 20),
                    SizedBox(height: 4),
                    Text(
                      "Tap to flip",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                          fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackCard() {
    final task = widget.task!;
    return _buildCardBase(
      isFront: false,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Details & Actions",
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            SizedBox(height: 15),
            Expanded(
              child: task.subtasks.isEmpty
                  ? Center(
                      child: Text(
                        "No subtasks",
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                            fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: min(
                          5,
                          task.subtasks
                              .length), // Limit to 5 subtasks for display
                      padding: EdgeInsets.zero,
                      itemBuilder: (context, index) {
                        final subtask = task.subtasks[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6.0), // Reduced vertical padding
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    subtask.isDone = !subtask.isDone;
                                  });
                                  HapticFeedback.mediumImpact();
                                  _scheduleService.updateSubtaskStatus(
                                      task.id, subtask.id, subtask.isDone);
                                },
                                child: Container(
                                  width: 20, // Slightly smaller
                                  height: 20, // Slightly smaller
                                  decoration: BoxDecoration(
                                      color: subtask.isDone
                                          ? Colors.white.withOpacity(0.9)
                                          : Colors.white.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(
                                          5), // Slightly smaller radius
                                      border: subtask.isDone
                                          ? null
                                          : Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.5),
                                              width: 1.5)),
                                  child: subtask.isDone
                                      ? Icon(Icons.check,
                                          size: 16, // Slightly smaller
                                          color: _gradientColors.first)
                                      : null,
                                ),
                              ),
                              SizedBox(width: 12), // Slightly reduced width
                              Expanded(
                                child: Text(
                                  subtask.title,
                                  style: TextStyle(
                                    fontSize: 15, // Slightly smaller
                                    color: Colors.white,
                                    decoration: subtask.isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: Colors.white70,
                                    decorationThickness: 1.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: 15),
            if (task.url.isNotEmpty || task.placeURL.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Links",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      if (task.url
                          .isNotEmpty) // Check for null or empty before accessing
                        Expanded(
                          child: _buildLinkButton(
                            Icons.link_rounded,
                            "Web Link",
                            () async {
                              if (task.url.isNotEmpty &&
                                  await canLaunchUrl(Uri.parse(task.url))) {
                                launchUrl(Uri.parse(task.url));
                                HapticFeedback.mediumImpact();
                              }
                            },
                          ),
                        ),
                      if (task.url.isNotEmpty && task.placeURL.isNotEmpty)
                        SizedBox(width: 10),
                      if (task.placeURL.isNotEmpty) // Check for null or empty
                        Expanded(
                          child: _buildLinkButton(
                            Icons.location_on_outlined,
                            "Location",
                            () async {
                              if (task.placeURL.isNotEmpty &&
                                  await canLaunchUrl(
                                      Uri.parse(task.placeURL))) {
                                launchUrl(Uri.parse(task.placeURL));
                                HapticFeedback.mediumImpact();
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 15),
                ],
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildActionButton(
                    Icons.check_circle_outline_rounded, "Complete", () {
                  _scheduleService.updateTaskCompletion(task.id, true);
                  HapticFeedback.mediumImpact();
                  widget
                      .onDismiss(); // Triggers manager's hide, which animates out
                }),
                _buildActionButton(Icons.edit_note_rounded, "Edit Task", () {
                  TaskOverlayManager.hideTaskOverlayImmediately();
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TaskDetailsScreen(task: task),
                      ),
                    );
                  }
                  HapticFeedback.mediumImpact();
                }),
              ],
            ),
            SizedBox(height: 20),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flip_camera_android_outlined,
                      color: Colors.white.withOpacity(0.7), size: 20),
                  SizedBox(height: 4),
                  Text(
                    "Tap to flip back",
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkButton(IconData icon, String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        category,
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _buildPriorityTag(String priority) {
    IconData icon;
    Color color = _getPriorityColor(priority);
    switch (priority.toLowerCase()) {
      case 'high':
        icon = Icons.priority_high_rounded;
        break;
      case 'medium':
        icon = Icons.swap_vert_circle_outlined;
        break;
      case 'low':
        icon = Icons.low_priority_rounded;
        break;
      default:
        icon = Icons.bookmark_border_rounded;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.85),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          )),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          SizedBox(width: 6),
          Text(
            priority.toUpperCase(),
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent.withOpacity(0.7);
      case 'medium':
        return Colors.orangeAccent.withOpacity(0.7);
      case 'low':
        return Colors.green.withOpacity(0.7);
      default:
        return Colors.blueGrey.withOpacity(0.7);
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0)
      return "${duration.inDays}d ${(duration.inHours % 24)}h";
    if (duration.inHours > 0)
      return "${duration.inHours}h ${(duration.inMinutes % 60)}m";
    if (duration.inMinutes > 0)
      return "${duration.inMinutes}m ${(duration.inSeconds % 60)}s";
    return "${duration.inSeconds}s";
  }
}

class CardPatternPainter extends CustomPainter {
  final bool reverse;
  final int seed;

  CardPatternPainter({this.reverse = false, this.seed = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    final random = Random(seed);

    if (!reverse) {
      Path path1 = Path();
      path1.moveTo(0, size.height * 0.1);
      path1.quadraticBezierTo(size.width * 0.3, size.height * 0.3,
          size.width * 0.6, size.height * 0.05);
      path1.quadraticBezierTo(
          size.width * 0.7, -size.height * 0.1, size.width * 0.3, 0);
      path1.lineTo(0, 0);
      path1.close();
      canvas.drawPath(path1, paint..color = Colors.white.withOpacity(0.06));

      Path path2 = Path();
      path2.moveTo(size.width, size.height * 0.8);
      path2.quadraticBezierTo(size.width * 0.7, size.height * 0.6,
          size.width * 0.4, size.height * 0.95);
      path2.quadraticBezierTo(
          size.width * 0.3, size.height * 1.1, size.width * 0.7, size.height);
      path2.lineTo(size.width, size.height);
      path2.close();
      canvas.drawPath(path2, paint..color = Colors.white.withOpacity(0.05));

      for (int i = 0; i < 8; i++) {
        canvas.drawCircle(
          Offset(random.nextDouble() * size.width,
              random.nextDouble() * size.height),
          random.nextDouble() * 3 + 2,
          paint..color = Colors.white.withOpacity(0.1),
        );
      }
    } else {
      Path path1 = Path();
      path1.moveTo(size.width * 0.9, 0);
      path1.quadraticBezierTo(
          size.width * 0.6, size.height * 0.2, size.width, size.height * 0.5);
      path1.quadraticBezierTo(size.width * 1.1, size.height * 0.6,
          size.width * 0.5, size.height * 0.3);
      path1.lineTo(size.width * 0.7, 0);
      path1.close();
      canvas.drawPath(path1, paint..color = Colors.white.withOpacity(0.07));

      Path path2 = Path();
      path2.moveTo(0, size.height * 0.7);
      path2.quadraticBezierTo(
          size.width * 0.3, size.height * 0.9, size.width * 0.1, size.height);
      path2.lineTo(0, size.height);
      path2.close();
      canvas.drawPath(path2, paint..color = Colors.white.withOpacity(0.06));

      for (int i = 0; i < 6; i++) {
        canvas.drawCircle(
          Offset(random.nextDouble() * size.width,
              random.nextDouble() * size.height),
          random.nextDouble() * 4 + 1.5,
          paint..color = Colors.white.withOpacity(0.09),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CardPatternPainter oldDelegate) =>
      oldDelegate.reverse != reverse || oldDelegate.seed != seed;
}

class ParticlesPainter extends CustomPainter {
  final Color particleColor;
  final int numParticles;
  final int seed;

  ParticlesPainter({
    required this.particleColor,
    this.numParticles = 15,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(seed);
    final paint = Paint()
      ..color = particleColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < numParticles; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 3 + 1;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    for (int i = 0; i < 3; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final shapeType = random.nextInt(3);

      if (shapeType == 0) {
        canvas.drawCircle(Offset(x, y), random.nextDouble() * 15 + 5,
            paint..color = particleColor.withOpacity(0.1));
      } else if (shapeType == 1) {
        final width = random.nextDouble() * 30 + 10;
        final height = random.nextDouble() * 30 + 10;
        canvas.drawRect(Rect.fromLTWH(x, y, width, height),
            paint..color = particleColor.withOpacity(0.08));
      } else {
        final path = Path();
        final radius = random.nextDouble() * 20 + 10;
        for (int j = 0; j < 5; j++) {
          final angle = j * 2 * pi / 5;
          final point =
              Offset(x + radius * cos(angle), y + radius * sin(angle));
          j == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        path.close();
        canvas.drawPath(path, paint..color = particleColor.withOpacity(0.06));
      }
    }
  }

  @override
  bool shouldRepaint(ParticlesPainter oldDelegate) =>
      oldDelegate.particleColor != particleColor ||
      oldDelegate.numParticles != numParticles ||
      oldDelegate.seed != seed;
}
