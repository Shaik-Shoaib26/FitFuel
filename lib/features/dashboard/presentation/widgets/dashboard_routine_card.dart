import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import '../../../reminders/presentation/providers/reminders_providers.dart';

class DashboardRoutineCard extends ConsumerWidget {
  const DashboardRoutineCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final routine = ref.watch(dailyRoutineProvider);

    return FitFuelCard(
      border: const BorderSide(color: AppColors.primary, width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Today's Routine",
                  style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 16),
                ),
              ),
              Text(
                '${routine.completionPercentage.toStringAsFixed(0)}%',
                style: AppTypography.heading2(isDark: isDark).copyWith(
                  fontSize: 16,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),

          // Completion Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: routine.completionPercentage / 100.0,
              backgroundColor: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
              color: AppColors.primary500,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${routine.completedReminders} of ${routine.totalReminders} completed',
                style: AppTypography.bodySmall(isDark: isDark),
              ),
              if (routine.nextReminder != null)
                Text(
                  'Next: ${routine.nextReminder!.title} — ${routine.nextReminder!.scheduledTime}',
                  style: AppTypography.bodySmall(isDark: isDark).copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/daily-routine'),
              child: const Text('View Routine'),
            ),
          ),
        ],
      ),
    );
  }
}
