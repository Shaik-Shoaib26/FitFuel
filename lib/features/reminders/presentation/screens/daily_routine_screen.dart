import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import 'package:fitfuel/core/widgets/fitfuel_progress_ring.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/reminder_entity.dart';
import '../../domain/utils/daily_routine_calculator.dart';
import '../providers/reminders_providers.dart';

class DailyRoutineScreen extends ConsumerWidget {
  const DailyRoutineScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final routine = ref.watch(dailyRoutineProvider);
    final greeting = _getGreeting();
    final summary = DailyRoutineCalculator.generateSummaryText(routine);

    // Filter next three pending reminders for the "UP NEXT" section
    final upcomingReminders = routine.pendingItems.take(3).toList();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgBase : AppColors.lightBgBase,
      appBar: AppBar(
        title: const Text('Daily Routine'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/reminders'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Time-based greeting header
            Text(
              greeting,
              style: AppTypography.heading1(isDark: isDark),
            ),
            Text(
              'Your FitFuel routine',
              style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppConstants.spaceMd),

            // Today's Progress Card
            FitFuelCard(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "TODAY'S PROGRESS",
                          style: AppTypography.caption(isDark: isDark).copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceXs),
                        Text(
                          '${routine.completedReminders} of ${routine.totalReminders} completed',
                          style: AppTypography.bodyLarge(isDark: isDark).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceMd),
                  FitFuelProgressRing(
                    value: routine.completionPercentage / 100.0,
                    size: 90,
                    strokeWidth: 8,
                    centerTitle: '${routine.completionPercentage.toStringAsFixed(0)}%',
                    centerSubtitle: 'Done',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spaceMd),

            // Smart Check-in Recommendation Banner
            Container(
              padding: const EdgeInsets.all(AppConstants.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.primary500.withAlpha(20),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.primary500.withAlpha(40)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.favorite_rounded,
                    color: AppColors.primary500,
                    size: 20,
                  ),
                  const SizedBox(width: AppConstants.spaceSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SMART CHECK-IN',
                          style: AppTypography.caption(isDark: isDark).copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary,
                          style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spaceLg),

            // UP NEXT reminders list
            if (upcomingReminders.isNotEmpty) ...[
              _buildSectionHeader('UP NEXT', isDark),
              const SizedBox(height: AppConstants.spaceSm),
              FitFuelCard(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcomingReminders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = upcomingReminders[index];
                    return _buildTimelineItem(context, item, isDark);
                  },
                ),
              ),
              const SizedBox(height: AppConstants.spaceLg),
            ],

            // Full routine checklists
            _buildSectionHeader('CHECKLIST', isDark),
            const SizedBox(height: AppConstants.spaceSm),
            FitFuelCard(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: routine.routineItems.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = routine.routineItems[index];
                  return ListTile(
                    leading: Icon(
                      item.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: item.completed ? AppColors.primary500 : (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle),
                    ),
                    title: Text(
                      item.title,
                      style: AppTypography.bodyMedium(isDark: isDark).copyWith(
                        fontWeight: FontWeight.bold,
                        decoration: item.completed ? TextDecoration.lineThrough : null,
                        color: item.completed
                            ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                            : null,
                      ),
                    ),
                    subtitle: Text(
                      item.description,
                      style: AppTypography.bodySmall(isDark: isDark),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 16),
                    contentPadding: EdgeInsets.zero,
                    onTap: () => context.push(item.actionRoute),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceXs),
      child: Text(
        title,
        style: AppTypography.caption(isDark: isDark).copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, ReminderEntity item, bool isDark) {
    IconData getIcon() {
      switch (item.type) {
        case ReminderType.hydration:
          return Icons.local_drink_rounded;
        case ReminderType.breakfast:
        case ReminderType.lunch:
        case ReminderType.dinner:
        case ReminderType.snack:
          return Icons.restaurant_rounded;
        case ReminderType.exercise:
          return Icons.directions_run_rounded;
        case ReminderType.habit:
          return Icons.check_box_outlined;
        case ReminderType.weight:
          return Icons.scale_rounded;
        case ReminderType.weeklyReview:
          return Icons.analytics_rounded;
        default:
          return Icons.alarm_rounded;
      }
    }

    Color getIconColor() {
      switch (item.type) {
        case ReminderType.hydration:
          return AppColors.hydration;
        case ReminderType.exercise:
          return AppColors.calories;
        default:
          return AppColors.primary500;
      }
    }

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: getIconColor().withAlpha(15),
          shape: BoxShape.circle,
        ),
        child: Icon(getIcon(), color: getIconColor(), size: 20),
      ),
      title: Text(
        item.title,
        style: AppTypography.bodyMedium(isDark: isDark).copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        item.scheduledTime,
        style: AppTypography.bodySmall(isDark: isDark).copyWith(
          color: AppColors.primary500,
          fontWeight: FontWeight.bold,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
      contentPadding: EdgeInsets.zero,
      onTap: () => context.push(item.actionRoute),
    );
  }
}
