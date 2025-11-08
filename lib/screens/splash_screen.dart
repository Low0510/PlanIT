import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ensure these paths are correct for your project structure
import 'package:planit_schedule_manager/services/authentication_service.dart';
import 'package:planit_schedule_manager/widgets/onboarding_screen.dart';
import 'package:planit_schedule_manager/widgets/main_layout.dart';
import 'login_screen.dart'; // Assuming this is in the same directory or correct path

// --- Particle Class ---
class Particle {
  Offset position;
  Color color;
  double speed;
  double radius;
  double opacity;
  double direction;

  Particle({
    required this.position,
    required this.color,
    required this.speed,
    required this.radius,
    required this.opacity,
    required this.direction,
  });
}

// --- AnimatedLetter Class (Handles individual letter animations) ---
class AnimatedLetter {
  final String finalChar;
  String displayChar;

  late AnimationController appearanceController;
  late AnimationController transformMoveController;

  late Animation<double> scale;
  late Animation<double> yOffset;
  late Animation<double> appearanceOpacity;

  late Animation<double> tOpacity;
  late Animation<double> TOpacity;
  late Animation<double> xOffset;

  bool isAppearing = false;
  bool hasAppeared = false;
  bool isTransforming = false;
  bool hasTransformed = false;

  AnimatedLetter(this.finalChar, TickerProvider vsync, {
    String? initialDisplayCharOverride,
    Duration appearanceDuration = const Duration(milliseconds: 900), // Slower pop-in
    Duration transformMoveDuration = const Duration(milliseconds: 750), // Slower transform
  }) : displayChar = initialDisplayCharOverride ?? finalChar {
    appearanceController = AnimationController(duration: appearanceDuration, vsync: vsync);
    transformMoveController = AnimationController(duration: transformMoveDuration, vsync: vsync);

    // Appearance animations
    scale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: appearanceController, curve: Curves.elasticOut),
    );
    yOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 35.0, end: -18.0), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: -18.0, end: 0.0), weight: 25),
      TweenSequenceItem(tween: Tween<double>(begin: 0.0, end: -10.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: -10.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: appearanceController, curve: Curves.easeInOut));
    appearanceOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: appearanceController, curve: Curves.easeIn),
    );

    // Transform/Move animations (primarily for 'T' slot)
    tOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: transformMoveController, curve: Interval(0.0, 0.5, curve: Curves.easeOutCubic))
    );
    TOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: transformMoveController, curve: Interval(0.3, 0.8, curve: Curves.easeInCubic))
    );
    // xOffset will be dynamically set when playTransformAndMove is called
    xOffset = ConstantTween<double>(0.0).animate(transformMoveController);
  }

  Future<void> playAppearance({bool hideInitially = false}) async {
    isAppearing = true;
    hasAppeared = false;
    if (hideInitially) {
      appearanceController.value = 0.0;
    }
    // Use try-catch for orCancel if a controller might be disposed mid-animation
    try {
      await appearanceController.forward(from: 0.0).orCancel;
    } on TickerCanceled { /* Handle cancellation if necessary */ }
    isAppearing = false;
    hasAppeared = true;
  }

  Future<void> playTransformAndMove(double targetX) async {
    if (finalChar != 'T') return; // This logic is specific to the 'T' slot

    isTransforming = true;
    hasTransformed = false;
    // Update xOffset animation for the current transformation
    this.xOffset = Tween<double>(begin: 0.0, end: targetX).animate(
        CurvedAnimation(parent: transformMoveController, curve: Curves.easeInOutCubic)
    );
    try {
      await transformMoveController.forward(from: 0.0).orCancel;
    } on TickerCanceled { /* Handle cancellation */ }
    isTransforming = false;
    hasTransformed = true;
    displayChar = 'T'; // Solidify display char after transform
  }

  void reset() {
    appearanceController.reset();
    transformMoveController.reset();
    isAppearing = false;
    hasAppeared = false;
    isTransforming = false;
    hasTransformed = false;
    // Reset displayChar for 'T' slot back to 't'
    displayChar = (finalChar == 'T' && initialDisplayCharOverride == 't') ? 't' : finalChar;
    // Reset xOffset to a non-moving state
    xOffset = ConstantTween<double>(0.0).animate(transformMoveController);
  }

  // Ensure initialDisplayCharOverride is captured for reset logic if needed
  String? get initialDisplayCharOverride => (finalChar == 'T') ? 't' : null;


  void dispose() {
    appearanceController.dispose();
    transformMoveController.dispose();
  }
}

// --- SplashScreen Widget ---
class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  bool _isFirstTime = true;
  bool _isLogin = false;
  User? user;

  late AnimationController _particleController;
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotateAnimation;

  final List<Particle> _particles = [];
  final Random _random = Random();
  
  // For custom "PlanIT" text animation
  List<AnimatedLetter> _planItAnimLetters = [];
  final String _finalText = "PlanIT"; // P l a n I T
  // IMPORTANT: Tune this distance based on your font size and desired gap for 'I'
  final double _tMoveDistance = 0.0; 

  // For tagline animation
  late AnimationController _taglineController;
  late Animation<double> _taglineOpacityAnimation;

  @override
  void initState() {
    super.initState();
    _initializeNavigationLogic(); // Handles navigation logic
    _setupVisualAnimations();   // Sets up all visual animations
    _generateParticles();       // Generates background particles
  }

  void _setupVisualAnimations() {
    // Particle animation controller
    _particleController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    
    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _logoScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );
    _logoRotateAnimation = Tween<double>(begin: -0.2, end: 0.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
    
    // Tagline animation controller
    _taglineController = AnimationController(
      duration: const Duration(milliseconds: 1000), // Slower tagline fade-in
      vsync: this,
    );
    _taglineOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _taglineController, curve: Curves.easeIn),
    );
    
    _preparePlanItLetters(); // Initialize AnimatedLetter objects
    
    // Start animations in sequence
    _logoController.forward().then((_) {
      if (mounted) { // Ensure widget is still in the tree
        _animatePlanItText();
      }
    });
  }

  void _preparePlanItLetters() {
    _planItAnimLetters.clear();
    // Order for _planItAnimLetters: P, l, a, n, I, T
    // This matches _finalText string "PlanIT"
    _planItAnimLetters.add(AnimatedLetter(_finalText[0], this)); // P
    _planItAnimLetters.add(AnimatedLetter(_finalText[1], this)); // l
    _planItAnimLetters.add(AnimatedLetter(_finalText[2], this)); // a
    _planItAnimLetters.add(AnimatedLetter(_finalText[3], this)); // n
    _planItAnimLetters.add(AnimatedLetter(_finalText[4], this)); // I (will appear later)
    _planItAnimLetters.add(AnimatedLetter(_finalText[5], this, initialDisplayCharOverride: 't')); // T (starts as 't')
  }

  Future<void> _animatePlanItText() async {
    if (!mounted) return;

    // Reset all letters before starting sequence
    for (var letter in _planItAnimLetters) {
      letter.reset();
    }
    _taglineController.reset();

    const letterStagger = Duration(milliseconds: 250); // Slower stagger
    const stageDelay = Duration(milliseconds: 700);   // Delay between major stages

    // --- Stage 1: "P", "l", "a", "n", "t" appear ---
    // Animate P, l, a, n (indices 0-3 in _planItAnimLetters)
    for (int i = 0; i < 4; i++) { 
      if (!mounted) return;
      _planItAnimLetters[i].playAppearance(); // Don't await each, let them overlap for smoother entry
      await Future.delayed(letterStagger);
    }
    // Animate 't' (which is _planItAnimLetters[5], representing the 'T' slot)
    if (!mounted) return;
    await _planItAnimLetters[5].playAppearance(); // Await this last letter of "Plant"

    await Future.delayed(stageDelay);

    // --- Stage 2: "t" transforms to "T" and moves right ---
    if (!mounted) return;
    AnimatedLetter tSlotLetter = _planItAnimLetters[5];
    await tSlotLetter.playTransformAndMove(_tMoveDistance);

    await Future.delayed(Duration(milliseconds: (stageDelay.inMilliseconds * 0.5).round())); // Shorter delay before 'I'

    // --- Stage 3: "I" appears ---
    // 'I' is at _planItAnimLetters[4]
    if (!mounted) return;
    AnimatedLetter iLetter = _planItAnimLetters[4];
    await iLetter.playAppearance(hideInitially: true);

    // Wait for 'I' to finish appearing plus a small buffer
    await Future.delayed(iLetter.appearanceController.duration! + Duration(milliseconds: 400));

    // --- Stage 4: Animate tagline ---
    if (mounted) {
      _taglineController.forward();
    }
  }

  void _generateParticles() {
    for (int i = 0; i < 80; i++) {
      _particles.add(Particle(
        position: Offset(_random.nextDouble() * 400, _random.nextDouble() * 800),
        color: Color.fromRGBO(
          _random.nextInt(100) + 155,
          _random.nextInt(100) + 155,
          255,
          1.0,
        ),
        speed: _random.nextDouble() * 1.5 + 0.5,
        radius: _random.nextDouble() * 5 + 1,
        opacity: _random.nextDouble() * 0.6 + 0.2,
        direction: _random.nextDouble() * 2 * pi,
      ));
    }
  }

  Future<void> _initializeNavigationLogic() async {
    final auth = AuthenticationService();
    bool isFirstTime = await auth.checkFirstTime();
    bool isLogin = await auth.checkUserLoginStatus();

    if (mounted) {
      setState(() {
        _isFirstTime = isFirstTime;
        _isLogin = isLogin;
      });
    }

    if (_isLogin) {
      await auth.setFirstTimeFalse();
      user = FirebaseAuth.instance.currentUser; // Can be null if not logged in
    }

    // Increased delay to ensure all animations can play out
    Future.delayed(const Duration(seconds: 9), () { 
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => _isFirstTime
                ? OnboardingScreen()
                : (_isLogin && user != null ? MainLayout(user: user!) : LoginScreen()),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              var fadeAnimation = Tween(begin: 0.0, end: 1.0).animate(animation);
              return FadeTransition(
                opacity: fadeAnimation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 900), // Slower page transition
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _particleController.dispose();
    _logoController.dispose();
    _taglineController.dispose();
    for (var letterInfo in _planItAnimLetters) {
      letterInfo.dispose();
    }
    super.dispose();
  }

  Widget _buildAnimatedPlanItText() {
    const textStyle = TextStyle(
      fontSize: 58,
      fontWeight: FontWeight.bold,
      color: Colors.white,
      shadows: [
        Shadow(
          blurRadius: 15.0,
          color: Colors.lightBlueAccent,
          offset: Offset(0, 0),
        ),
      ],
    );

    // The Row will render P, l, a, n, I, T in this order (matching _finalText and _planItAnimLetters setup)
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_finalText.length, (index) {
        AnimatedLetter letterInfo = _planItAnimLetters[index];
        
        return AnimatedBuilder(
          animation: Listenable.merge([letterInfo.appearanceController, letterInfo.transformMoveController]),
          builder: (context, child) {
            double currentScale = letterInfo.scale.value;
            double currentYOffset = letterInfo.yOffset.value;
            double currentOpacity = letterInfo.appearanceOpacity.value;
            String charToRender = letterInfo.displayChar;
            double xTranslation = 0;

            // Handle 'I' - it should only be visible during/after its appearance and not before.
            if (letterInfo.finalChar == 'I') {
              if (!letterInfo.isAppearing && !letterInfo.hasAppeared) {
                currentOpacity = 0.0; // Start 'I' as invisible
              }
            }
            
            // Handle 't'/'T' slot (which is _planItAnimLetters[5])
            if (letterInfo.finalChar == 'T') {
              xTranslation = letterInfo.xOffset.value; // Apply X movement

              if (letterInfo.isTransforming) {
                // During transformation, use a Stack to cross-fade 't' and 'T'
                // YOffset should be from the settled appearance, X from transform
                return Transform.translate(
                  offset: Offset(xTranslation, letterInfo.hasAppeared ? 0 : currentYOffset),
                  child: Stack(
                    alignment: Alignment.center, // Or Alignment.bottomLeft if preferred
                    children: [
                      // 't' fading out
                      Opacity(
                        opacity: letterInfo.tOpacity.value,
                        child: Transform.scale(
                          scale: letterInfo.hasAppeared ? 1.0 : currentScale, // Use settled scale for 't'
                          child: Text('t', style: textStyle),
                        ),
                      ),
                      // 'T' fading in
                      Opacity(
                        opacity: letterInfo.TOpacity.value,
                        child: Transform.scale(
                          scale: 1.0, // 'T' appears at full scale during fade
                          child: Text('T', style: textStyle),
                        ),
                      ),
                    ],
                  ),
                );
              } else if (letterInfo.hasTransformed) {
                charToRender = 'T';
                currentOpacity = 1.0; // Ensure 'T' is fully opaque
                currentScale = 1.0;   // Ensure 'T' is full scale
              } else if (letterInfo.hasAppeared) { // After 't' has appeared, before transform
                 charToRender = 't';
                 currentOpacity = 1.0;
                 currentScale = 1.0;
              }
              // If !letterInfo.hasAppeared, normal opacity/scale/char from appearanceController apply for 't'
            }

            return Opacity(
              opacity: currentOpacity,
              child: Transform.translate(
                offset: Offset(xTranslation, currentYOffset),
                child: Transform.scale(
                  scale: currentScale,
                  child: Text(charToRender, style: textStyle),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A237E), Color(0xFF0D47A1), Color(0xFF01579B)],
                stops: [0.0, 0.6, 1.0],
              ),
            ),
          ),
          
          // Star field effect (Particle Painter)
          CustomPaint(
            size: size,
            painter: ParticlePainter(
              _particles, 
              _particleController, 
              size,
            ),
          ),
          
          // Logo and text content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo
                AnimatedBuilder(
                  animation: _logoController,
                  builder: (context, child) {
                    return Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001) // Perspective for 3D effect
                        ..rotateX(_logoRotateAnimation.value)
                        ..scale(_logoScaleAnimation.value),
                      child: Lottie.asset(
                        'assets/lotties/1.json', // Make sure this Lottie file exists
                        width: 300,
                        height: 300,
                      ),
                    );
                  }),
                // const SizedBox(height: 5),
    
                // New custom animated "PlanIT" text
                _buildAnimatedPlanItText(),
    
                // Tagline with delayed appearance
                // FadeTransition(
                //   opacity: _taglineOpacityAnimation,
                //   child: Padding(
                //     padding: const EdgeInsets.only(top: 10.0),
                //     child: Text(
                //       "1% Planning, 99% Crushing it",
                //       style: TextStyle(
                //         fontSize: 18,
                //         fontWeight: FontWeight.w400,
                //         color: Colors.white.withOpacity(0.85),
                //         letterSpacing: 1.2,
                //       ),
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- ParticlePainter Class ---
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Animation<double> animation;
  final Size canvasSize;
  final Paint _paint = Paint();
  final Random _random = Random();

  ParticlePainter(this.particles, this.animation, this.canvasSize) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0; // Time in seconds
    
    for (var particle in particles) {
      // Movement logic for continuous, dynamic motion
      double timeFactor = now * 0.05; 
      double noiseX = sin(particle.position.dx * 0.01 + particle.position.dy * 0.005 + timeFactor + particle.direction);
      double noiseY = cos(particle.position.dy * 0.01 + particle.position.dx * 0.005 + timeFactor + particle.direction);
      particle.direction += (noiseX + noiseY) * 0.05 * (_random.nextDouble() - 0.4); 
      
      particle.position = Offset(
        (particle.position.dx + cos(particle.direction) * particle.speed),
        (particle.position.dy + sin(particle.direction) * particle.speed),
      );

      // Wrap particles around the screen
      if (particle.position.dx < -particle.radius) particle.position = Offset(canvasSize.width + particle.radius, particle.position.dy);
      if (particle.position.dx > canvasSize.width + particle.radius) particle.position = Offset(-particle.radius, particle.position.dy);
      if (particle.position.dy < -particle.radius) particle.position = Offset(particle.position.dx, canvasSize.height + particle.radius);
      if (particle.position.dy > canvasSize.height + particle.radius) particle.position = Offset(particle.position.dx, -particle.radius);

      // Pulsing opacity for particles
      double pulsingOpacity = particle.opacity * (0.6 + 0.4 * sin(now * (0.5 + particle.speed * 0.1) + particle.radius));
      pulsingOpacity = pulsingOpacity.clamp(0.0, 1.0); 
      
      _paint.color = particle.color.withOpacity(pulsingOpacity);
      canvas.drawCircle(particle.position, particle.radius, _paint);
      
      // Add subtle glow to some particles
      if (_random.nextDouble() > 0.65) {
        double glowOpacity = (pulsingOpacity * 0.25).clamp(0.0, 1.0);
        _paint.color = particle.color.withOpacity(glowOpacity);
        canvas.drawCircle(particle.position, particle.radius * (_random.nextDouble() * 1.8 + 1.8), _paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}