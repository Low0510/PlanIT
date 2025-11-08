import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final DateTime scheduleTime;
  final bool isOverdue;
  final bool isToday;
  final int calculatedHour;
  final Color priorityColor;

  const TaskCard({
    Key? key,
    required this.task,
    required this.scheduleTime,
    required this.isOverdue,
    required this.isToday,
    required this.calculatedHour,
    required this.priorityColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isOverdue 
            ? Colors.red.shade100 
            : (isToday 
              ? Colors.blue.shade100 
              : Colors.grey.shade200),
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {/* Show details */},
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Section
              _buildDateSection(),
              
              const SizedBox(width: 16),
              
              // Task Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTaskHeader(),
                    const SizedBox(height: 10),
                    _buildTaskDetails(),
                    if (task.emotion != null) 
                      const SizedBox(height: 10),
                      _buildEmotionTag(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    return Container(
      width: 60,
      height: 70,
      decoration: BoxDecoration(
        color: isOverdue
            ? Colors.red.shade50
            : (isToday ? Colors.blue.shade50 : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isOverdue
              ? Colors.red.shade200
              : (isToday ? Colors.blue.shade200 : Colors.grey.shade300),
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat('dd').format(scheduleTime),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isOverdue
                  ? Colors.red.shade700
                  : (isToday ? Colors.blue.shade700 : Colors.grey.shade700),
            ),
          ),
          Text(
            DateFormat('MMM').format(scheduleTime).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isOverdue
                  ? Colors.red.shade700
                  : (isToday ? Colors.blue.shade700 : Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskHeader() {
    return Row(
      children: [
        // Priority Chip
        Chip(
          label: Text(
            task.priority.toUpperCase(),
            style: TextStyle(
              color: priorityColor,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: priorityColor.withOpacity(0.1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),

        // Category Chip (if exists)
        if (task.category != null) ...[
          const SizedBox(width: 8),
          Chip(
            label: Text(
              task.category!,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
        ],

        // Repeat Icon
        if (task.isRepeated)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.repeat, size: 16, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildTaskDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          task.title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade900,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.access_time,
              size: 16,
              color: isOverdue ? Colors.red.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('HH:mm').format(scheduleTime),
              style: TextStyle(
                color: isOverdue ? Colors.red.shade400 : Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 12),
            _buildTimeStatus(),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeStatus() {
    Color statusColor = isOverdue
        ? Colors.red.shade400
        : (isToday ? Colors.blue.shade400 : Colors.grey.shade600);

    String statusText = isOverdue
        ? '$calculatedHour hours overdue'
        : (isToday
            ? 'Today Left $calculatedHour hours'
            : 'In $calculatedHour hours');

    return Text(
      statusText,
      style: TextStyle(
        color: statusColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildEmotionTag() {
    return task.emotion != null
        ? Align(
            alignment: Alignment.bottomRight,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                task.emotion!,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          )
        : const SizedBox.shrink();
  }
}