import 'package:flutter/material.dart';
import 'health_today_grid.dart';

/// "Today's Health" asymmetric overview (Phase 35.6.3).
/// Delegates directly to [HealthTodayGrid] to match Option C approved reference.
class HealthOverviewSection extends StatelessWidget {
  final String waterValue;
  final double waterProgress;
  final int exerciseMinutes;
  final int habitsDone, habitsTotal;
  final double wellnessScore;
  final ValueChanged<String> onSelectSection;

  const HealthOverviewSection({
    super.key,
    required this.waterValue,
    required this.waterProgress,
    required this.exerciseMinutes,
    required this.habitsDone,
    required this.habitsTotal,
    required this.wellnessScore,
    required this.onSelectSection,
  });

  @override
  Widget build(BuildContext context) {
    return HealthTodayGrid(
      waterValue: waterValue,
      waterProgress: waterProgress,
      exerciseMinutes: exerciseMinutes,
      habitsDone: habitsDone,
      habitsTotal: habitsTotal,
      wellnessScore: wellnessScore,
      onSelectSection: onSelectSection,
    );
  }
}
