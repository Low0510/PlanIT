import 'package:flutter/material.dart';
import 'package:animated_background/animated_background.dart';
import 'dart:ui';

class GlassmorphicAnimatedBackground extends StatefulWidget {
  final Widget child;

  GlassmorphicAnimatedBackground({required this.child});

  @override
  _GlassmorphicAnimatedBackgroundState createState() => _GlassmorphicAnimatedBackgroundState();
}

class _GlassmorphicAnimatedBackgroundState extends State<GlassmorphicAnimatedBackground> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedBackground(
          behaviour: RandomParticleBehaviour(
            options: ParticleOptions(
              spawnOpacity: 0.0,
              opacityChangeRate: 0.25,
              minOpacity: 0.1,
              maxOpacity: 0.4,
              particleCount: 70,
              spawnMaxRadius: 45.0,
              spawnMaxSpeed: 100.0,
              spawnMinSpeed: 30,
              spawnMinRadius: 7.0,
              // image: Image(image: AssetImage("images/clock.png"), height: 40,)
            ),
          ),
          vsync: this,
          child: Container(),
        ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}