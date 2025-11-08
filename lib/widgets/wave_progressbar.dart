import 'dart:math' as math;
import 'package:flutter/material.dart';

class WaveProgressBar extends StatefulWidget {
  final int completed;
  final int total;
  final bool showPercentage;

  const WaveProgressBar({
    Key? key,
    required this.completed,
    required this.total,
    this.showPercentage = true,
  }) : super(key: key);

  @override
  State<WaveProgressBar> createState() => _WaveProgressBarState();
}

class _WaveProgressBarState extends State<WaveProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Color _getProgressColor(double percentage) {
    if (percentage >= 100) return Colors.green;
    if (percentage >= 70) return Colors.blue;
    if (percentage >= 40) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = widget.total > 0 
        ? (widget.completed / widget.total * 100).round() 
        : 0;
    
    final progressColor = _getProgressColor(percentage.toDouble());

    return Container(
      height: 32,
      width: 100, // Increased width to accommodate percentage
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: progressColor.withOpacity(0.1),
        border: Border.all(
          color: progressColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          // Primary wave
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: CompactWavePainter(
                    waveAnimation: _waveController,
                    percentage: percentage,
                    progressColor: progressColor.withOpacity(0.3),
                    waveCount: 3,
                    phase: 0,
                  ),
                );
              },
            ),
          ),
          
          // Secondary wave (offset for more realistic effect)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  size: Size.infinite,
                  painter: CompactWavePainter(
                    waveAnimation: _waveController,
                    percentage: percentage,
                    progressColor: progressColor.withOpacity(0.2),
                    waveCount: 2,
                    phase: math.pi / 2, // Offset phase for second wave
                  ),
                );
              },
            ),
          ),
          
          // Text overlay
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!widget.showPercentage) ...[
                  Text(
                    '${widget.completed}/${widget.total}',
                    style: TextStyle(
                      color: progressColor.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else ...[
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: progressColor.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CompactWavePainter extends CustomPainter {
  final Animation<double> waveAnimation;
  final int percentage;
  final Color progressColor;
  final int waveCount;
  final double phase;

  CompactWavePainter({
    required this.waveAnimation,
    required this.percentage,
    required this.progressColor,
    this.waveCount = 3,
    this.phase = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = size.height * 0.25;
    final progress = size.width * (percentage / 100);
    
    path.moveTo(0, size.height);
    
    // Create more realistic wave effect with multiple waves
    for (var i = 0.0; i <= size.width; i++) {
      final x = i;
      final normalizedX = x / size.width;
      final wavePhase = (waveAnimation.value * 2 * math.pi) + phase;
      
      double y = size.height / 2;
      // Composite wave function
      y += math.sin((normalizedX * waveCount * 2 * math.pi) + wavePhase) * 
           waveHeight * (1 - math.pow(normalizedX - 0.5, 2));
      
      if (x <= progress) {
        path.lineTo(x, y);
      }
    }
    
    if (progress > 0) {
      path.lineTo(progress, size.height);
    }
    path.close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CompactWavePainter oldDelegate) => true;
}