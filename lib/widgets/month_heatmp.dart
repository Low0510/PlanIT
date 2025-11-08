import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import 'package:planit_schedule_manager/models/task.dart';
import 'package:planit_schedule_manager/screens/task_details_screen.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';
import 'package:planit_schedule_manager/widgets/tasks_display_widget.dart'; // For max function

// Helper function for text contrast
Color getTextColorForBackground(Color backgroundColor) {
  // Calculate luminance (standard formula)
  double luminance = (0.299 * backgroundColor.red +
          0.587 * backgroundColor.green +
          0.114 * backgroundColor.blue) /
      255;
  return luminance > 0.5 ? Colors.black87 : Colors.white;
}

class MonthlyTaskHeatmap extends StatefulWidget {
  final Map<DateTime, int> taskTrends;
  final DateTime initialFocusMonth;
  final String title;
  final Color baseColor;
  final Function(DateTime date, int taskCount)? onDateSelected; // Callback

  MonthlyTaskHeatmap({
    Key? key,
    required this.taskTrends,
    DateTime? focusMonth,
    this.title = 'Task Activity',
    this.baseColor = Colors.blue,
    this.onDateSelected,
  })  : initialFocusMonth = focusMonth ?? DateTime.now(),
        super(key: key);

  @override
  _MonthlyTaskHeatmapState createState() => _MonthlyTaskHeatmapState();
}

class _MonthlyTaskHeatmapState extends State<MonthlyTaskHeatmap> {
  late DateTime _focusMonth;
  int _maxTaskCount = 1; // Default to 1 to avoid division by zero

  @override
  void initState() {
    super.initState();
    _focusMonth = DateTime(
        widget.initialFocusMonth.year, widget.initialFocusMonth.month, 1);
    _updateMaxTaskCount();
  }

  @override
  void didUpdateWidget(covariant MonthlyTaskHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Optional: If you want the heatmap to react if the input taskTrends changes
    // while the widget is displayed, recalculate max count here.
    if (widget.taskTrends != oldWidget.taskTrends) {
      _updateMaxTaskCount();
    }
    // If initialFocusMonth changes externally, update the state
    if (widget.initialFocusMonth.year != oldWidget.initialFocusMonth.year ||
        widget.initialFocusMonth.month != oldWidget.initialFocusMonth.month) {
      setState(() {
        _focusMonth = DateTime(
            widget.initialFocusMonth.year, widget.initialFocusMonth.month, 1);
        _updateMaxTaskCount();
      });
    }
  }

  void _updateMaxTaskCount() {
    final monthTasks = widget.taskTrends.entries
        .where((entry) =>
            entry.key.year == _focusMonth.year &&
            entry.key.month == _focusMonth.month)
        .map((e) => e.value);

    if (monthTasks.isNotEmpty) {
      _maxTaskCount = monthTasks.reduce(max);
      if (_maxTaskCount == 0)
        _maxTaskCount = 1; // Ensure it's at least 1 if max is 0
    } else {
      _maxTaskCount = 1; // Default if no tasks this month
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusMonth = DateTime(_focusMonth.year, _focusMonth.month + delta, 1);
      _updateMaxTaskCount(); // Recalculate max for the new month
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter data for the current focus month upfront
    final monthlyData = Map.fromEntries(widget.taskTrends.entries.where(
        (entry) =>
            entry.key.year == _focusMonth.year &&
            entry.key.month == _focusMonth.month));

    return Card(
      color: Colors.white.withOpacity(0.75),
      elevation: 3,
      margin: const EdgeInsets.all(12.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for Column height
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildHeatmapGrid(context, monthlyData),
            const SizedBox(height: 16),
            _buildLegend(context),
            const SizedBox(height: 16),
            _buildMonthlyInsight(context, monthlyData),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Title on the left
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('MMMM yyyy').format(_focusMonth),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        // Navigation buttons on the right
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _NavigationButton(
              icon: Icons.chevron_left,
              tooltip: 'Previous Month',
              onPressed: () => _changeMonth(-1),
            ),
            _NavigationButton(
              icon: Icons.chevron_right,
              tooltip: 'Next Month',
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeatmapGrid(
      BuildContext context, Map<DateTime, int> monthlyData) {
    // Calculate first day of grid (may include days from previous month)
    final firstDayOfMonth = _focusMonth; // Already day 1
    // DateTime.weekday returns 1 for Monday, 7 for Sunday.
    // We want Sunday as 0, Saturday as 6 for indexing.
    final firstDayWeekday =
        firstDayOfMonth.weekday % 7; // 0 for Sunday, 1 for Monday...

    // Calculate the days to display
    final daysInMonth =
        DateTime(_focusMonth.year, _focusMonth.month + 1, 0).day;
    final totalCells = ((daysInMonth + firstDayWeekday) / 7).ceil() * 7;

    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: const [
            _WeekdayLabel('S'),
            _WeekdayLabel('M'),
            _WeekdayLabel('T'),
            _WeekdayLabel('W'),
            _WeekdayLabel('T'),
            _WeekdayLabel('F'),
            _WeekdayLabel('S'),
          ],
        ),
        const SizedBox(height: 8),
        // Calendar grid using AspectRatio for square cells
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true, // Important for GridView inside Column
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.1, // Slightly wider than tall for text
            crossAxisSpacing: 5.0,
            mainAxisSpacing: 5.0,
          ),
          itemCount: totalCells,
          itemBuilder: (context, index) {
            final dayOffset = index - firstDayWeekday;

            // Days outside the current month
            if (dayOffset < 0 || dayOffset >= daysInMonth) {
              return Container(
                decoration: BoxDecoration(
                  // Optional: slightly different background for empty cells
                  // color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
              ); // Empty cell
            }

            final day = dayOffset + 1;
            final date = DateTime(_focusMonth.year, _focusMonth.month, day);
            // Find the data for this specific date (handle time component mismatch)
            final dateKey = monthlyData.keys.firstWhere(
              (k) =>
                  k.year == date.year &&
                  k.month == date.month &&
                  k.day == date.day,
              orElse: () => date, // Use date itself if not found
            );
            final taskCount = monthlyData[dateKey] ?? 0;

            // Normalize intensity (ensure maxTaskCount is not 0)
            final intensity = _maxTaskCount > 0
                ? (taskCount / _maxTaskCount).clamp(0.0, 1.0)
                : 0.0;

            return _HeatmapCell(
              date: date,
              day: day,
              intensity: intensity,
              taskCount: taskCount,
              baseColor: widget.baseColor,
              isToday: _isToday(date),
              onTap: () {
                _showTasksForDate(context, date, taskCount);
                widget.onDateSelected?.call(date, taskCount);
              },
            );
          },
        ),
      ],
    );
  }

  // Add this to your MonthlyTaskHeatmap class
  void _showTasksForDate(
      BuildContext context, DateTime date, int taskCount) async {
    if (taskCount == 0) {
      // Show a message if there are no tasks
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No tasks scheduled for ${DateFormat('MMMM d, yyyy').format(date)}'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }


    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Task Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_today_rounded,
                    color: Colors.blue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                // Loading Indicator
                const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
                const SizedBox(height: 24),

                // Loading Text
                const Text(
                  'Loading Tasks Created',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please wait while we fetch your tasks...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );

    // Get tasks for the selected date
    ScheduleService _scheduleService = ScheduleService();
    List<Task> tasks = await _scheduleService.getCreatedSchedulesDate(date);

    // Close the loading dialog
    Navigator.of(context).pop();

    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'No tasks found for ${DateFormat('MMMM d, yyyy').format(date)}'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show beautiful modal with tasks
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => TasksDisplayModal(
        date: date,
        tasks: tasks,
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildLegend(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Fewer',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(width: 6),
        _LegendItem(color: widget.baseColor.withOpacity(0.1)),
        const SizedBox(width: 3),
        _LegendItem(color: widget.baseColor.withOpacity(0.3)),
        const SizedBox(width: 3),
        _LegendItem(color: widget.baseColor.withOpacity(0.5)),
        const SizedBox(width: 3),
        _LegendItem(color: widget.baseColor.withOpacity(0.7)),
        const SizedBox(width: 3),
        _LegendItem(
            color: widget.baseColor.withOpacity(0.95)), // Use near full opacity
        const SizedBox(width: 6),
        Text(
          'More',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildMonthlyInsight(
      BuildContext context, Map<DateTime, int> monthlyData) {
    if (monthlyData.isEmpty) {
      return Center(
        child: Text(
          "No task activity recorded for this month.",
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey[600]),
        ),
      );
    }

    // --- Calculate Insights ---
    List<MapEntry<DateTime, int>> sortedEntries = monthlyData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort descending by count

    final mostProductiveEntry = sortedEntries.first;
    final mostProductiveDate = mostProductiveEntry.key;
    final mostProductiveCount = mostProductiveEntry.value;

    final totalTasks = monthlyData.values.fold(0, (sum, count) => sum + count);
    final activeDays = monthlyData.entries.where((e) => e.value > 0).length;
    final avgTasksPerActiveDay = activeDays > 0 ? totalTasks / activeDays : 0.0;

    // Calculate longest streak
    int longestStreak = 0;
    int currentStreak = 0;
    List<DateTime> sortedDates = monthlyData.keys.toList()..sort();
    DateTime? previousDate;

    for (final currentDate in sortedDates) {
      if (monthlyData[currentDate]! > 0) {
        // Only count days with tasks for streak
        if (previousDate != null &&
            currentDate.difference(previousDate).inDays == 1) {
          currentStreak++;
        } else {
          currentStreak = 1; // Start new streak
        }
        if (currentStreak > longestStreak) {
          longestStreak = currentStreak;
        }
        previousDate = currentDate;
      } else {
        // Reset streak if a day with 0 tasks is encountered within the sorted list
        previousDate = currentDate; // Still update previousDate
        // Don't reset currentStreak here if we only care about consecutive *active* days
        // If we wanted consecutive days *including* zero, logic would differ.
      }
    }
    // Handle case where the streak continues to the last day
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Monthly Summary",
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _InsightRow(
            icon: Icons.star_border_purple500_outlined,
            label: "Peak Day:",
            value:
                "${DateFormat('MMM d').format(mostProductiveDate)} ($mostProductiveCount tasks)",
          ),
          _InsightRow(
            icon: Icons.functions,
            label: "Avg/Active Day:",
            value: "${avgTasksPerActiveDay.toStringAsFixed(1)} tasks",
          ),
          _InsightRow(
            icon: Icons.trending_up,
            label: "Longest Streak:",
            value: "$longestStreak day${longestStreak != 1 ? 's' : ''}",
          ),
        ],
      ),
    );
  }
}

// --- Helper Widgets ---

class _NavigationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _NavigationButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      color: Theme.of(context).colorScheme.primary,
      constraints: const BoxConstraints(), // Remove default padding
      padding: const EdgeInsets.all(8), // Add custom padding
      splashRadius: 20,
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String text;

  const _WeekdayLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 35, // Slightly wider for better spacing
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey[700],
          fontWeight: FontWeight.w600, // Bolder
          fontSize: 12,
        ),
      ),
    );
  }
}

class _HeatmapCell extends StatelessWidget {
  final DateTime date;
  final int day;
  final double intensity;
  final int taskCount;
  final Color baseColor;
  final bool isToday;
  final VoidCallback onTap;

  const _HeatmapCell({
    required this.date,
    required this.day,
    required this.intensity,
    required this.taskCount,
    required this.baseColor,
    required this.isToday,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine cell color based on intensity
    // Give a very slight color even for 0 tasks to distinguish from empty cells
    final cellColor = taskCount > 0
        ? baseColor
            .withOpacity(max(0.08, intensity)) // Ensure minimum opacity if > 0
        : Colors.grey.shade200; // Distinct color for zero tasks

    final textColor = getTextColorForBackground(cellColor);

    final tooltipMessage =
        "${DateFormat('MMM d, yyyy').format(date)}\nTasks: $taskCount";

    return Semantics(
      label: "Date: ${DateFormat('MMMM d').format(date)}, Tasks: $taskCount",
      button: true, // Indicate it's tappable
      excludeSemantics: true, // Tooltip provides info
      child: Tooltip(
        message: tooltipMessage,
        preferBelow: false,
        waitDuration: const Duration(milliseconds: 400), // Slight delay
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            decoration: BoxDecoration(
              color: cellColor,
              borderRadius: BorderRadius.circular(6),
              border: isToday
                  ? Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .primary, // Use primary color for today
                      width: 2.5, // Thicker border
                    )
                  : null,
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    day.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: isToday
                          ? Theme.of(context).colorScheme.primary
                          : textColor,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
                // Now the conditional widget can be properly placed in the Stack
                if (taskCount > 0)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Text(
                      taskCount.toString(),
                      style: TextStyle(
                        fontSize: 7,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;

  const _LegendItem({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18, // Slightly larger
      height: 18,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4), // Rounded corners
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Expanded(
            // Allow value to wrap if needed
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.end, // Align value to the right
            ),
          ),
        ],
      ),
    );
  }
}

