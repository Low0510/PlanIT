import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

class CurvedNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CurvedNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CurvedNavigationBar(
      index: currentIndex,
      height: 60.0,
      items: const [
        Icon(Icons.home, size: 28),
        Icon(Icons.chat_bubble, size: 28),
        Icon(Icons.calendar_month_outlined, size: 28),
        Icon(Icons.wb_cloudy, size: 28),
        Icon(Icons.grid_view_rounded, size: 28),
        // Icon(Icons.rocket_launch_rounded, size: 28,),
        Icon(Icons.person, size: 28),
      ],
      color: Colors.white.withOpacity(0.7),
      buttonBackgroundColor: Colors.blue.shade300,
      backgroundColor: Colors.transparent,
      animationCurve: Curves.easeInOut,
      animationDuration: const Duration(milliseconds: 600),
      onTap: onTap,
    );
  }
}
