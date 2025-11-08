import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui'
    show ImageFilter, lerpDouble; // Import lerpDouble for smooth interpolation

class DistributionChart extends StatefulWidget {
  final Map<String, int> distributionData;
  final String title;
  final Color accentColor;
  final IconData? icon;

  const DistributionChart({
    Key? key,
    required this.distributionData,
    required this.title,
    this.accentColor = Colors.blue,
    this.icon,
  }) : super(key: key);

  @override
  State<DistributionChart> createState() => _DistributionChartState();
}

class _DistributionChartState extends State<DistributionChart>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  int? _selectedPartIndex;
  late AnimationController _expandController;
  late AnimationController _glowController;
  late Animation<double> _expandAnimation;
  late Animation<double> _glowAnimation;

  // Define compact and expanded values to animate between them
  static const double _compactChartHeight = 140.0;
  static const double _expandedChartHeight = 200.0;
  static const double _compactChartRadius = 45.0;
  static const double _expandedChartRadius = 60.0;
  static const double _compactCenterSpace = 25.0;
  static const double _expandedCenterSpace = 40.0;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      duration: const Duration(
          milliseconds: 400), // Slightly longer for a smoother feel
      vsync: this,
    );
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We only need one AnimatedBuilder for everything now.
    return AnimatedBuilder(
      animation: Listenable.merge([_expandAnimation, _glowAnimation]),
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.25),
                Colors.white.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor
                    .withOpacity(0.1 + _glowAnimation.value * 0.1),
                blurRadius: 15 + _glowAnimation.value * 8,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: InkWell(
              onTap: _toggleExpansion,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildCompactHeader(),
                    const SizedBox(height: 16),
                    // *** KEY CHANGE ***
                    // Instead of replacing the widget, we build a unified,
                    // animated layout.
                    _buildAnimatedChartContent(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactHeader() {
    return Row(
      children: [
        if (widget.icon != null) ...[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: widget.accentColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: widget.accentColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(
              widget.icon,
              color: widget.accentColor.withOpacity(0.9),
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.black.withOpacity(0.85),
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _buildTotalCount(),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: widget.accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.accentColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            color: widget.accentColor.withOpacity(0.8),
            size: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalCount() {
    final int total =
        widget.distributionData.values.fold(0, (sum, count) => sum + count);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            widget.accentColor.withOpacity(0.2),
            widget.accentColor.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        'Total: $total',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black.withOpacity(0.8),
        ),
      ),
    );
  }

  /// **MAJOR REFACTOR: This now builds a single, animated layout.**
  /// **MAJOR REFACTOR: This now builds a single, animated layout.**
  Widget _buildAnimatedChartContent() {
    if (widget.distributionData.isEmpty) {
      // No changes here
      return Container(
        height: 120,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              'No data available',
              style: TextStyle(
                color: Colors.black.withOpacity(0.6),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final List<Color> categoryColors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEF4444),
      const Color(0xFF8B5CF6),
      const Color(0xFF06B6D4),
      const Color(0xFFF97316),
      const Color(0xFFEC4899),
      const Color(0xFF84CC16),
      const Color(0xFF6B7280),
    ];
    final int totalTasks =
        widget.distributionData.values.fold(0, (sum, count) => sum + count);

    final double currentChartHeight = lerpDouble(
        _compactChartHeight, _expandedChartHeight, _expandAnimation.value)!;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Part 1: The Pie Chart (no changes here)
            Expanded(
              flex: 3,
              child: Container(
                height: currentChartHeight,
                child: _buildAnimatedPieChart(categoryColors, totalTasks),
              ),
            ),
            const SizedBox(width: 12),

            // *** FIX: Corrected Fade Transition for Compact Legend ***
            // The compact legend should fade OUT as the chart expands.
            Expanded(
              flex: 2,
              child: FadeTransition(
                // Use a Tween to animate from 1.0 (visible) to 0.0 (invisible).
                opacity: _expandController
                    .drive(Tween<double>(begin: 1.0, end: 1.0)),
                child: IgnorePointer(
                  // When expanded, prevent touch events on the invisible legend.
                  ignoring: _isExpanded,
                  child: _buildCompactLegend(
                      widget.distributionData, categoryColors),
                ),
              ),
            ),
          ],
        ),
        // Part 3: The expanded-only stats (no changes here)
        SizeTransition(
          sizeFactor: _expandAnimation,
          axisAlignment: -1.0,
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: FadeTransition(
              opacity: _expandAnimation,
              child: _buildDetailedStats(
                  widget.distributionData, categoryColors, totalTasks),
            ),
          ),
        )
      ],
    );
  }

  /// Builds the PieChart whose properties are driven by the animation controller.
  Widget _buildAnimatedPieChart(List<Color> categoryColors, int totalTasks) {
    // Animate the radius and text size based on the expand animation
    final double currentRadius = lerpDouble(
        _compactChartRadius, _expandedChartRadius, _expandAnimation.value)!;
    final double currentSelectedRadius = currentRadius + 5;
    final double currentCenterSpace = lerpDouble(
        _compactCenterSpace, _expandedCenterSpace, _expandAnimation.value)!;
    final double currentTitleFontSize =
        lerpDouble(0, 12, _expandAnimation.value)!;

    final sections = widget.distributionData.entries
        .toList()
        .asMap()
        .entries
        .map((indexedEntry) {
      final int index = indexedEntry.key;
      final MapEntry<String, int> entry = indexedEntry.value;
      final double percentage =
          totalTasks > 0 ? (entry.value / totalTasks) * 100 : 0;
      final Color color = categoryColors[index % categoryColors.length];
      final bool isSelected = _selectedPartIndex == index;

      return PieChartSectionData(
        color: color.withOpacity(0.8),
        value: entry.value.toDouble(),
        // The title (percentage) fades in as the chart expands
        title:
            currentTitleFontSize > 2 ? '${percentage.toStringAsFixed(0)}%' : '',
        radius: isSelected ? currentSelectedRadius : currentRadius,
        titleStyle: TextStyle(
          fontSize: currentTitleFontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      );
    }).toList();

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: currentCenterSpace,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {
            if (!event.isInterestedForInteractions ||
                pieTouchResponse == null ||
                pieTouchResponse.touchedSection == null) {
              setState(() {
                _selectedPartIndex = null;
              });
              return;
            }

            final sectionIndex =
                pieTouchResponse.touchedSection!.touchedSectionIndex;
            setState(() {
              _selectedPartIndex = sectionIndex;
            });
          },
        ),
      ),
    );
  }

  // No changes needed for the legend widget itself
  Widget _buildCompactLegend(Map<String, int> data, List<Color> colors) {
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: data.entries.toList().asMap().entries.map((indexedEntry) {
          final index = indexedEntry.key;
          final entry = indexedEntry.value;
          final color = colors[index % colors.length];
          final bool isSelected = _selectedPartIndex == index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPartIndex = isSelected ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected ? color.withOpacity(0.1) : null,
                  border: isSelected
                      ? Border.all(
                          color: color.withOpacity(0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: Colors.black.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // No changes needed for the detailed stats widget itself
  Widget _buildDetailedStats(
      Map<String, int> data, List<Color> colors, int totalTasks) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final highest = sortedEntries.first;
    final lowest = sortedEntries.last;
    final averageValue = totalTasks / data.length;
    final aboveAverage =
        sortedEntries.where((e) => e.value > averageValue).length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: widget.accentColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _buildStatCard(
                      'Highest', highest.key, highest.value, colors[0])),
              const SizedBox(width: 8),
              Expanded(
                  child: _buildStatCard(
                      'Lowest', lowest.key, lowest.value, colors[1])),
            ],
          ),
          const SizedBox(height: 12),
          ...sortedEntries.take(5).map((entry) {
            final index = data.keys.toList().indexOf(entry.key);
            final color = colors[index % colors.length];
            final percentage = (entry.value / totalTasks) * 100;

            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.black.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      height: 16,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white.withOpacity(0.2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 35,
                    child: Text(
                      '${entry.value}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  // No changes needed for this helper
  Widget _buildStatCard(String label, String value, int? count, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.black.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            count != null ? count.toString() : value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (count != null)
            Text(
              value,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: Colors.black.withOpacity(0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (!_isExpanded) {
        // Clear selection when collapsing for a cleaner look
        _selectedPartIndex = null;
      }
    });

    if (_isExpanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }
}
