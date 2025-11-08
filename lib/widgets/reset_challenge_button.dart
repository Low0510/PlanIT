import 'package:flutter/material.dart';

class ChallengeResetButton extends StatefulWidget {
  final VoidCallback onReset;
  
  const ChallengeResetButton({
    Key? key,
    required this.onReset,
  }) : super(key: key);

  @override
  _ChallengeResetButtonState createState() => _ChallengeResetButtonState();
}

class _ChallengeResetButtonState extends State<ChallengeResetButton> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;
  bool _isHolding = false;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _rotateAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    
    _controller.addListener(() {
      setState(() {
        _progress = _controller.value;
      });
      
      if (_controller.value == 1.0) {
        widget.onReset();
        _resetButton();
      }
    });
  }

  void _resetButton() {
    _controller.reset();
    setState(() {
      _isHolding = false;
      _progress = 0.0;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: GestureDetector(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Long press to reset the challenge'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating,),
            
          );
        },
        onLongPressStart: (_) {
          setState(() {
            _isHolding = true;
          });
          _controller.forward();
        },
        onLongPressEnd: (_) {
          setState(() {
            _isHolding = false;
          });
          _controller.reverse();
        },
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotateAnimation.value * _progress * 3.14,
                child: Container(
                  width: 180,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Progress indicator
                      ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.3),
                          ),
                          minHeight: 60,
                        ),
                      ),
                      // Button content
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            SizedBox(width: 8),
                            Text(
                              _isHolding ? "Hold to Reset..." : "Reset Challenge",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
