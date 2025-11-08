import 'package:flutter/material.dart';
import 'dart:math' as math; // For math.max

class TimelineFilterSlider extends StatefulWidget {
  final Function(String) onFilterChanged;
  final String initialFilter;

  const TimelineFilterSlider({
    Key? key,
    required this.onFilterChanged,
    required this.initialFilter,
  }) : super(key: key);

  @override
  _TimelineFilterSliderState createState() => _TimelineFilterSliderState();
}

class _TimelineFilterSliderState extends State<TimelineFilterSlider>
    with SingleTickerProviderStateMixin {
  final List<String> _filterOptions = ['Overdue', 'Today', 'Coming Soon', 'All'];
  final List<IconData> _filterIcons = [
    Icons.warning_amber_rounded,
    Icons.today,
    Icons.upcoming, // Changed for better visual
    Icons.layers_outlined,
  ];

  late int _selectedIndex;
  late AnimationController _animationController;
  late Animation<double> _pillAnimation;
  late Animation<Color?> _pillColorAnimation;

  // Store previous values for animation
  int _previousIndex = 0;
  Color _previousPillColor = Colors.transparent;


  @override
  void initState() {
    super.initState();
    _selectedIndex = _filterOptions.indexOf(widget.initialFilter);
    if (_selectedIndex == -1) {
      _selectedIndex = 1; // Default to 'Today'
    }
    _previousIndex = _selectedIndex;
    _previousPillColor = _getPillColor(_selectedIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _setupAnimations();
    _animationController.forward(); // Initial animation to selected
  }

  void _setupAnimations() {
    _pillAnimation = Tween<double>(
      begin: _previousIndex.toDouble(),
      end: _selectedIndex.toDouble(),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutCubic, // Smoother curve
    ));

    _pillColorAnimation = ColorTween(
      begin: _previousPillColor,
      end: _getPillColor(_selectedIndex),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(covariant TimelineFilterSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter) {
      _updateSelection(_filterOptions.indexOf(widget.initialFilter));
    }
  }

  Color _getPillColor(int index) {
    switch (index) {
      case 0:
        return Colors.redAccent.withOpacity(0.15);
      case 1:
        return Colors.blueAccent.withOpacity(0.15);
      case 2:
        return Colors.greenAccent.withOpacity(0.20);
      case 3:
      default:
        return Colors.grey.withOpacity(0.15);
    }
  }

  Color _getIconTextColor(int index, bool isSelected) {
    if (!isSelected) return Colors.grey[500]!;
    switch (index) {
      case 0:
        return Colors.redAccent;
      case 1:
        return Colors.blueAccent;
      case 2:
        return Colors.greenAccent.shade700;
      case 3:
      default:
        return Colors.grey[800]!;
    }
  }

  void _updateSelection(int index) {
    if (index == _selectedIndex || index < 0 || index >= _filterOptions.length) return;

    setState(() {
      _previousIndex = _selectedIndex;
      _previousPillColor = _pillColorAnimation.value ?? _getPillColor(_selectedIndex);
      _selectedIndex = index;
      widget.onFilterChanged(_filterOptions[_selectedIndex]);
    });

    _animationController.reset();
    _setupAnimations();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Define a fixed height for the widget
    const double widgetHeight = 65.0; // Reduced height
    const double horizontalPadding = 16.0;
    final double availableWidth = MediaQuery.of(context).size.width - (horizontalPadding * 2);
    final double itemWidth = availableWidth / _filterOptions.length;
    final double pillHeight = widgetHeight - 16; // Pill takes most of the height
    final double pillWidth = itemWidth - 8; // Pill is slightly narrower than item slot

    return Container(
      height: widgetHeight,
      padding: const EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8.0),
      decoration: BoxDecoration(
        // color: Colors.grey[100], // Optional background for the whole slider
        // borderRadius: BorderRadius.circular(30),
      ),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Animated Pill Background
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Positioned(
                left: _pillAnimation.value * itemWidth + (itemWidth - pillWidth) / 2,
                child: Container(
                  width: pillWidth,
                  height: pillHeight,
                  decoration: BoxDecoration(
                    color: _pillColorAnimation.value,
                    borderRadius: BorderRadius.circular(12), // Rounded pill
                  ),
                ),
              );
            },
          ),
          // Filter Items (Icons and Text)
          Row(
            children: List.generate(_filterOptions.length, (index) {
              final bool isSelected = index == _selectedIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _updateSelection(index),
                  behavior: HitTestBehavior.opaque, // Make sure empty space is tappable
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _filterIcons[index],
                        color: _getIconTextColor(index, isSelected),
                        size: 22, // Slightly smaller icons
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _filterOptions[index],
                        style: TextStyle(
                          fontSize: 10, // Smaller text
                          color: _getIconTextColor(index, isSelected),
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}