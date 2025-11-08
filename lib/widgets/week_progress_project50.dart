import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'dart:math' as math;

class WeeklyProgressCard extends StatefulWidget {
  final int currentDay;

  const WeeklyProgressCard({
    Key? key,
    required this.currentDay,
  }) : super(key: key);

  @override
  State<WeeklyProgressCard> createState() => _WeeklyProgressCardState();
}

class _WeeklyProgressCardState extends State<WeeklyProgressCard>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _plantGrowthController;
  late AnimationController _plantSwayController;
  late Animation<double> _plantSizeAnimation;
  late Animation<double> _plantSwayAnimation;

  @override
  void initState() {
    super.initState();

    // Controller for week progress bars
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Controller for plant growth and movement
    _plantGrowthController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // Controller for plant sway
    _plantSwayController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _plantSizeAnimation = CurvedAnimation(
      parent: _plantGrowthController,
      curve: Curves.easeOutBack,
    );

    _plantSwayAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.05, end: 0.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.05, end: -0.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 1,
      ),
    ]).animate(_plantSwayController);

    // Start animations after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _progressController.forward();
      _plantGrowthController.forward();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _plantGrowthController.dispose();
    // Get the controller from the _plantSwayAnimation
    _plantSwayController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.7),
      shadowColor: Theme.of(context).primaryColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.25),
              Colors.white.withOpacity(0.05),
              Colors.white.withOpacity(0.15),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.eco_rounded,
                    color: Theme.of(context).primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'WEEKLY PROGRESS',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Motivational Text Container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.park_rounded,
                      color: Theme.of(context).primaryColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your plant is growing with your progress! 🌱 Complete your Project50 tasks to help it bloom into the next phase. Keep going and watch it thrive! 🌿✨',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.color
                              ?.withOpacity(0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              PlantGrowthTracker(
                currentDay: widget.currentDay,
                sizeAnimation: _plantSizeAnimation,
                swayAnimation: _plantSwayAnimation,
              ),
              const SizedBox(height: 24),
              ...List.generate(8, (index) {
                final week = index + 1;
                return _buildWeekProgressBar(context, week);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekProgressBar(BuildContext context, int week) {
    // Calculate progress for each week (each week is approximately 7 days)
    final int daysInWeek = 7;
    final int weekStartDay = (week - 1) * daysInWeek + 2;
    final int weekEndDay = week * daysInWeek;

    // Calculate progress percentage for this week
    double progress = 0.0;
    if (widget.currentDay >= weekEndDay) {
      progress = 1.0; // Week completed
    } else if (widget.currentDay >= weekStartDay) {
      progress = (widget.currentDay - weekStartDay + 1) / daysInWeek;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedBuilder(
        animation: _progressController,
        builder: (context, child) {
          // Stagger the animation of each progress bar
          final delay = (week - 1) * 0.1;
          final animationValue = _progressController.value > delay
              ? (((_progressController.value - delay) / (1 - delay))
                  .clamp(0.0, 1.0))
              : 0.0;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: progress > 0
                              ? _getProgressColor(context, progress)
                              : Colors.grey[300],
                        ),
                        child: progress >= 1.0
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Week $week',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color:
                              progress > 0 ? Colors.black87 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  AnimatedOpacity(
                    opacity: progress > 0 ? 1.0 : 0.6,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      '${(progress * 100).toInt()}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: progress > 0
                            ? _getProgressColor(context, progress)
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Background track
                      Container(
                        height: 10,
                        width: constraints.maxWidth,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      // Animated progress
                      Container(
                        height: 10,
                        width: constraints.maxWidth * progress * animationValue,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: LinearGradient(
                            colors: [
                              _getProgressColor(context, progress)
                                  .withOpacity(0.7),
                              _getProgressColor(context, progress),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getProgressColor(context, progress)
                                  .withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Color _getProgressColor(BuildContext context, double progress) {
    if (progress >= 0.8) return Colors.green[600]!;
    if (progress >= 0.5) return Colors.amber[600]!;
    return Theme.of(context).primaryColor;
  }
}

class PlantGrowthTracker extends StatefulWidget {
  final int currentDay;
  final Animation<double> sizeAnimation;
  final Animation<double> swayAnimation;

  const PlantGrowthTracker({
    Key? key,
    required this.currentDay,
    required this.sizeAnimation,
    required this.swayAnimation,
  }) : super(key: key);

  @override
  State<PlantGrowthTracker> createState() => _PlantGrowthTrackerState();
}

class _PlantGrowthTrackerState extends State<PlantGrowthTracker>
    with SingleTickerProviderStateMixin {
  // Controller for additional interactive animations
  late AnimationController _interactionController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _rotateAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _hitOpacityAnimation;
  late Animation<double> _hitShakeAnimation;

  // Track the current interaction state
  String _currentInteraction = "none";

  @override
  void initState() {
    super.initState();

    // Initialize the interaction animation controller
    _interactionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Bounce animation that goes up and comes back down
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -20.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -20.0, end: 0.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 60,
      ),
    ]).animate(_interactionController);

    // Rotation animation for spinning
    _rotateAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.2),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: -0.2),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.2, end: 0.0),
        weight: 25,
      ),
    ]).animate(_interactionController);

    // Scale animation for grow/shrink effect
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.2),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.9),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0),
        weight: 30,
      ),
    ]).animate(_interactionController);

    // Glow animation for visual feedback
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
    ]).animate(_interactionController);

    // Hit opacity animation for double tap (transparency effect)
    _hitOpacityAnimation = TweenSequence<double>([
      // Quick fade to very transparent
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.2)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      // Hold transparency for a moment
      TweenSequenceItem(
        tween: ConstantTween<double>(0.2),
        weight: 25,
      ),
      // Fade back to visible
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
    ]).animate(_interactionController);

    // Shake animation for hit effect
    _hitShakeAnimation = TweenSequence<double>([
      // Quick jerks left and right in a decreasing pattern
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 0.2),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.2, end: -0.15),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.15, end: 0.1),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.1, end: -0.05),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -0.05, end: 0.0),
        weight: 45,
      ),
    ]).animate(_interactionController);
  }

  @override
  void dispose() {
    _interactionController.dispose();
    super.dispose();
  }

  // Trigger different animations based on the interaction type
  void _handleInteraction(String interactionType) {
    // Reset the controller to prepare for a new animation
    _interactionController.reset();

    setState(() {
      _currentInteraction = interactionType;
    });

    // Play the animation
    _interactionController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Sky background with gradient
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.lightBlue[50]!,
                  Colors.lightBlue[100]!,
                  Colors.lightBlue[50]!,
                ],
              ),
            ),
          ),

          // Soil with texture
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 60,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.brown[400]!,
                    Colors.brown[600]!,
                  ],
                ),
              ),
              child: CustomPaint(
                painter: SoilTexturePainter(),
              ),
            ),
          ),

          // Sun in the corner
          Positioned(
            top: 15,
            right: 15,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.amber[400],
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber[300]!.withOpacity(0.8),
                    blurRadius: 15,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),

          // Current plant phase with animations
          Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([
                widget.sizeAnimation,
                widget.swayAnimation,
                _interactionController
              ]),
              builder: (context, child) {
                // Apply different transformations based on interaction type
                double verticalOffset =
                    _currentInteraction == "tap" ? _bounceAnimation.value : 0.0;

                double rotation = widget.swayAnimation.value +
                    (_currentInteraction == "longPress"
                        ? _rotateAnimation.value
                        : 0.0) +
                    (_currentInteraction == "doubleTap"
                        ? _hitShakeAnimation.value
                        : 0.0);

                double scale = widget.sizeAnimation.value *
                    (_currentInteraction == "tap" ||
                            _currentInteraction == "longPress"
                        ? _scaleAnimation.value
                        : 1.0);

                return Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.identity()
                    ..translate(0.0, verticalOffset, 0.0)
                    ..scale(scale)
                    ..rotateZ(rotation),
                  child: GestureDetector(
                    onTap: () => _handleInteraction("tap"),
                    onDoubleTap: () => _handleInteraction("doubleTap"),
                    onLongPress: () => _handleInteraction("longPress"),
                    child: _buildPlantImage(),
                  ),
                );
              },
            ),
          ),

          RainAnimation(currentDay: widget.currentDay),

          // Growth timeline
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: _buildGrowthTimeline(context),
          ),

          // Add hit effect overlay when double-tapped
          if (_currentInteraction == "doubleTap")
            AnimatedBuilder(
              animation: _interactionController,
              builder: (context, child) {
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(
                                  0.1 * (1.0 - _hitOpacityAnimation.value)),
                              Colors.transparent,
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPlantImage() {
    // Determine which phase to display based on currentDay
    int phase = 1;
    if (widget.currentDay >= 40) {
      phase = 5;
    } else if (widget.currentDay >= 30) {
      phase = 4;
    } else if (widget.currentDay >= 20) {
      phase = 3;
    } else if (widget.currentDay >= 10) {
      phase = 2;
    }

    return AnimatedBuilder(
      animation: _interactionController,
      builder: (context, child) {
        // Apply opacity based on interaction
        double opacity = _currentInteraction == "doubleTap"
            ? _hitOpacityAnimation.value
            : 1.0;

        // Additional glow effect when interacting
        double glowIntensity =
            (_currentInteraction == "tap" || _currentInteraction == "longPress")
                ? _glowAnimation.value
                : 0.0;

        // The hit effect adds a flash of white
        double whiteOverlay = _currentInteraction == "doubleTap"
            ? (1.0 - _hitOpacityAnimation.value) * 0.5
            : 0.0;

        return Opacity(
          opacity: opacity,
          child: SizedBox(
            height: 120,
            width: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow effect that responds to interactions
                if (glowIntensity > 0 || phase >= 4)
                  Container(
                    height: 120,
                    width: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green[300]!
                              .withOpacity(0.3 + (glowIntensity * 0.5)),
                          blurRadius: 20 + (glowIntensity * 10),
                          spreadRadius: 2 + (glowIntensity * 8),
                        ),
                      ],
                    ),
                  ),
                // Plant image with color/transparency adjustments
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.white.withOpacity(whiteOverlay),
                    BlendMode.srcATop,
                  ),
                  child: Image.asset(
                    'assets/images/plant_phase_$phase.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGrowthTimeline(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildTimelineMarker(1, "Seed", 0),
            _buildTimelineMarker(2, "Seedling", 10),
            _buildTimelineMarker(3, "Growing", 20),
            _buildTimelineMarker(4, "Flowering", 30),
            _buildTimelineMarker(5, "Mature", 40),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            // Background track
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Progress indicator with gradient
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              height: 8,
              width: MediaQuery.of(context).size.width *
                  0.8 *
                  (widget.currentDay / 50),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [
                    Colors.green[300]!,
                    Colors.green[700]!,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green[500]!.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            'Day ${widget.currentDay} of 50',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineMarker(int phase, String label, int dayThreshold) {
    bool isActive = widget.currentDay >= dayThreshold;
    bool isCurrent = widget.currentDay >= dayThreshold &&
        (phase == 5 || widget.currentDay < (phase < 5 ? (phase * 10) : 50));

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isCurrent ? 16 : 12,
          height: isCurrent ? 16 : 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCurrent
                ? Colors.green[700]
                : (isActive ? Colors.green[400] : Colors.grey[400]),
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: Colors.green[300]!.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 2,
                    )
                  ]
                : null,
          ),
          child: isCurrent || (isActive && phase == 5)
              ? const Icon(Icons.check, size: 8, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontSize: isCurrent ? 10 : 9,
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            color: isCurrent
                ? Colors.green[700]
                : (isActive ? Colors.green[900] : Colors.grey[600]),
          ),
          child: Text(label),
        ),
      ],
    );
  }
}

// Custom painter for soil texture
class SoilTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown[700]!.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    final random = math.Random(42); // Fixed seed for consistent pattern

    // Draw random soil texture dots and lines
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 3 + 1;

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Occasionally draw small lines for texture
      if (i % 5 == 0) {
        final endX = x + random.nextDouble() * 8 - 4;
        final endY = y + random.nextDouble() * 4 - 2;
        canvas.drawLine(Offset(x, y), Offset(endX, endY),
            paint..strokeWidth = random.nextDouble() * 2 + 0.5);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Add this animation for raindrops if desired
class RainAnimation extends StatefulWidget {
  final int currentDay;

  const RainAnimation({
    Key? key,
    required this.currentDay,
  }) : super(key: key);

  @override
  State<RainAnimation> createState() => _RainAnimationState();
}

class _RainAnimationState extends State<RainAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;
  late List<Offset> _positions;

  @override
  void initState() {
    super.initState();

    // Create 10 raindrops with different animation timings
    final random = math.Random();
    _controllers = List.generate(
        10,
        (_) => AnimationController(
              duration: Duration(milliseconds: random.nextInt(500) + 1000),
              vsync: this,
            )..repeat());

    _animations = _controllers
        .map((controller) =>
            CurvedAnimation(parent: controller, curve: Curves.easeInQuad))
        .toList();

    _positions = List.generate(10, (_) => Offset(random.nextDouble(), 0));
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show rain in early growth stages (first 20 days)
    if (widget.currentDay > 20) return const SizedBox.shrink();

    return SizedBox.expand(
      child: Stack(
        children: List.generate(
            10,
            (i) => AnimatedBuilder(
                  animation: _animations[i],
                  builder: (context, child) {
                    return Positioned(
                      left:
                          _positions[i].dx * MediaQuery.of(context).size.width,
                      top: _animations[i].value * 240,
                      child: Opacity(
                        opacity: 1.0 - _animations[i].value,
                        child: Container(
                          width: 2,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  },
                )),
      ),
    );
  }
}
