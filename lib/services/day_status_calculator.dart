import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/colors.dart';

Color statusColor(DayStatus status) {
  switch (status) {
    case DayStatus.complete:
      return AppColors.statusComplete;
    case DayStatus.partial:
      return AppColors.statusPartial;
    case DayStatus.scheduled:
      return AppColors.statusScheduled;
    case DayStatus.skipped:
      return AppColors.statusSkipped;
    case DayStatus.exempt:
    case DayStatus.neutral:
      return AppColors.statusNeutral;
  }
}

/// Computes the display status for a single calendar day.
///
/// Priority: exempt → neutral → skipped → complete → partial → scheduled
DayStatus computeDayStatus(
  String dateStr,
  List<WorkoutInstance> instances,
  Set<String> exemptDates,
) {
  if (exemptDates.contains(dateStr)) return DayStatus.exempt;
  if (instances.isEmpty) return DayStatus.neutral;

  final active = instances.where((i) => i.status != WorkoutInstanceStatus.skipped).toList();
  if (active.isEmpty) return DayStatus.skipped;

  final hasSkipped = active.length < instances.length;
  final complete = active.where((i) => i.status == WorkoutInstanceStatus.complete).length;
  final partial = active.where((i) => i.status == WorkoutInstanceStatus.partial).length;
  final allActiveComplete = complete == active.length;

  if (allActiveComplete && !hasSkipped) return DayStatus.complete;
  if (allActiveComplete || complete + partial > 0 || hasSkipped) return DayStatus.partial;
  return DayStatus.scheduled;
}
