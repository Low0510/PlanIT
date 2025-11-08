import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:planit_schedule_manager/services/schedule_service.dart';

class TimeConflictManager {
  final ScheduleService _scheduleService;
  
  TimeConflictManager(this._scheduleService);
  
  // Get alternative times - suggests times before and after the conflict
  List<DateTime> getAlternativeTimes(DateTime conflictTime) {
    List<DateTime> alternatives = [];
    
    // Add 30-minute intervals before the conflict (2 options)
    alternatives.add(conflictTime.subtract(const Duration(minutes: 30)));
    alternatives.add(conflictTime.subtract(const Duration(minutes: 60)));
    
    // Add 30-minute intervals after the conflict (3 options)
    alternatives.add(conflictTime.add(const Duration(minutes: 30)));
    alternatives.add(conflictTime.add(const Duration(minutes: 60)));
    alternatives.add(conflictTime.add(const Duration(minutes: 90)));
    
    return alternatives;
  }
  
  // Find the next available time slot on the same day
  Future<DateTime?> findNextAvailableSlot(DateTime startTime) async {
    // Check slots in 30-minute increments until the end of day
    final endOfDay = DateTime(startTime.year, startTime.month, startTime.day, 23, 59);
    DateTime currentSlot = startTime.add(const Duration(minutes: 30));
    
    while (currentSlot.isBefore(endOfDay)) {
      final conflicts = await _scheduleService.getConflictTasks(newTaskTime: currentSlot);
      if (conflicts.isEmpty) {
        return currentSlot;
      }
      currentSlot = currentSlot.add(const Duration(minutes: 30));
    }
    
    return null; // No available slots found today
  }
}
