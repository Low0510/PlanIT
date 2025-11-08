import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NumberButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Duration holdDelay;
  final Duration repeatDuration;

  const NumberButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.holdDelay = const Duration(milliseconds: 500),
    this.repeatDuration = const Duration(milliseconds: 100),
  });

  @override
  State<NumberButton> createState() => NumberButtonState();
}

class NumberButtonState extends State<NumberButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  Timer? _holdTimer;
  Timer? _repeatTimer;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _holdTimer?.cancel();
    _repeatTimer?.cancel();
    super.dispose();
  }

  void _startHolding() {
    if (widget.onPressed == null) return;
    
    _isHolding = true;
    _controller.forward();
    HapticFeedback.lightImpact();
    
    // Initial hold delay
    _holdTimer = Timer(widget.holdDelay, () {
      if (_isHolding) {
        _repeatTimer = Timer.periodic(widget.repeatDuration, (timer) {
          if (_isHolding && widget.onPressed != null) {
            widget.onPressed!();
            HapticFeedback.selectionClick();
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _stopHolding() {
    _isHolding = false;
    _controller.reverse();
    _holdTimer?.cancel();
    _repeatTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    Widget button = ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: widget.onPressed == null
              ? Colors.grey[200]
              : Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.onPressed == null
                ? Colors.grey[300]!
                : Theme.of(context).primaryColor.withOpacity(0.2),
          ),
          boxShadow: widget.onPressed != null
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Icon(
          widget.icon,
          size: 20,
          color: widget.onPressed == null
              ? Colors.grey[400]
              : Theme.of(context).primaryColor,
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed == null ? null : () {
          widget.onPressed!();
          HapticFeedback.selectionClick();
        },
        onTapDown: widget.onPressed == null ? null : (_) => _startHolding(),
        onTapUp: widget.onPressed == null ? null : (_) => _stopHolding(),
        onTapCancel: widget.onPressed == null ? null : _stopHolding,
        borderRadius: BorderRadius.circular(12),
        splashColor: widget.onPressed != null
            ? Theme.of(context).primaryColor.withOpacity(0.1)
            : Colors.transparent,
        highlightColor: widget.onPressed != null
            ? Theme.of(context).primaryColor.withOpacity(0.05)
            : Colors.transparent,
        child: button,
      ),
    );
  }
}

// Add this new widget for weekday selection
class WeekdayButton extends StatelessWidget {
  final int day;
  final bool isSelected;
  final ValueChanged<bool> onToggle;

  const WeekdayButton({
    required this.day,
    required this.isSelected,
    required this.onToggle,
  });

  String get _dayLabel {
    switch (day) {
      case 0:
        return 'S';
      case 1:
        return 'M';
      case 2:
        return 'T';
      case 3:
        return 'W';
      case 4:
        return 'T';
      case 5:
        return 'F';
      case 6:
        return 'S';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle(!isSelected);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).primaryColor.withOpacity(0.2),
            ),
          ),
          child: Center(
            child: Text(
              _dayLabel,
              style: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
