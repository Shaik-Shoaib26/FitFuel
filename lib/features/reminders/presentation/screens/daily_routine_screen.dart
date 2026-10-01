import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/navigation/feature_action_navigation.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../domain/entities/daily_routine_entity.dart';
import '../../domain/entities/reminder_entity.dart';
import '../../domain/utils/daily_routine_calculator.dart';
import '../providers/reminders_providers.dart';

/// Premium Daily Routine Screen — Interactive timeline, task checklist,
/// and smart check-in progress.
class DailyRoutineScreen extends ConsumerWidget {
  const DailyRoutineScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final routine = ref.watch(dailyRoutineProvider);
    final greeting = _getGreeting();
    final summary = DailyRoutineCalculator.generateSummaryText(routine);

    // Filter next pending reminders for the "UP NEXT" section
    final upcomingReminders = routine.pendingItems.take(3).toList();

    return Scaffold(
      appBar: FitFuelAppBar(
        title: const Text('Daily Routine'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Reminder Settings',
            onPressed: () => context.push('/settings/reminders'),
          ),
        ],
      ),
      body: AdaptivePageLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 950;

              final leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Greeting Header
                  Text(
                    '$greeting 👋',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Stay on track with today\'s schedule and habits.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceMd),

                  // Today's Progress Card
                  _buildProgressCard(context, routine, isDark),
                  const SizedBox(height: AppConstants.spaceMd),

                  // Smart Check-in AI Insight Banner
                  _buildSmartCheckInBanner(context, summary, isDark),
                  const SizedBox(height: AppConstants.spaceMd),

                  // UP NEXT Highlight
                  if (upcomingReminders.isNotEmpty) ...[
                    const FitFuelSectionHeader(
                      title: 'Up Next',
                      subtitle: 'Upcoming scheduled activities for today.',
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    ...upcomingReminders.map(
                      (item) => _buildUpNextCard(context, item, isDark),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),
                  ],
                ],
              );

              final rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const FitFuelSectionHeader(
                    title: 'Daily Checklist',
                    subtitle: 'Tap any activity to log or view details.',
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                  if (routine.routineItems.isEmpty)
                    Center(
                      child: FitFuelEmptyState(
                        icon: Icons.checklist_rounded,
                        title: 'No Routine Configured',
                        description:
                            'Customize your daily hydration, meal, and exercise schedule in reminder settings.',
                        actionLabel: 'Configure Reminders',
                        onActionPressed: () =>
                            context.push('/settings/reminders'),
                      ),
                    )
                  else
                    FitFuelCard(
                      padding: EdgeInsets.zero,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: routine.routineItems.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark
                              ? AppColors.darkBorderSubtle
                              : AppColors.lightBorderSubtle,
                        ),
                        itemBuilder: (context, index) {
                          final item = routine.routineItems[index];
                          return _buildChecklistItem(context, item, isDark);
                        },
                      ),
                    ),
                ],
              );

              if (isDesktop) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 10, child: leftColumn),
                    const SizedBox(width: AppConstants.spaceLg),
                    Expanded(flex: 11, child: rightColumn),
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftColumn,
                    const SizedBox(height: AppConstants.spaceMd),
                    rightColumn,
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    BuildContext context,
    DailyRoutineEntity routine,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final double completionFraction =
        (routine.completionPercentage / 100.0).clamp(0.0, 1.0);

    return FitFuelCard(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AppConstants.spaceSm,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Progress',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${routine.completedReminders} of ${routine.totalReminders} activities completed',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceSm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary500.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  '${routine.completionPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppColors.primary500,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: completionFraction,
              backgroundColor: isDark
                  ? AppColors.darkBorderSubtle
                  : AppColors.primary500.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartCheckInBanner(
    BuildContext context,
    String summary,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.primary500.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: AppColors.primary500.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary500.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary500,
              size: 18,
            ),
          ),
          const SizedBox(width: AppConstants.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Smart Check-in',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  summary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpNextCard(
    BuildContext context,
    ReminderEntity item,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final iconData = _getEventIcon(item.type);
    final iconColor = _getEventColor(item.type);

    return FitFuelCard(
      margin: const EdgeInsets.only(bottom: AppConstants.spaceSm),
      padding: const EdgeInsets.all(AppConstants.spaceSm),
      onTap: () => context.go(reminderLocation(item)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.scheduledTime,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.description.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    item.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(
    BuildContext context,
    ReminderEntity item,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final iconData = _getEventIcon(item.type);
    final iconColor = _getEventColor(item.type);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceMd,
        vertical: 4,
      ),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: item.completed
              ? AppColors.stateSuccess.withValues(alpha: 0.1)
              : iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          item.completed ? Icons.check_rounded : iconData,
          color: item.completed ? AppColors.stateSuccess : iconColor,
          size: 18,
        ),
      ),
      title: Text(
        item.title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          decoration: item.completed ? TextDecoration.lineThrough : null,
          color: item.completed
              ? (isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary)
              : null,
        ),
      ),
      subtitle: Text(
        '${item.scheduledTime}${item.description.isNotEmpty ? " • ${item.description}" : ""}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: isDark
              ? AppColors.darkTextSecondary
              : AppColors.lightTextSecondary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing:
          const Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey),
      onTap: () => context.go(reminderLocation(item)),
    );
  }

  IconData _getEventIcon(ReminderType type) {
    return switch (type) {
      ReminderType.hydration => Icons.water_drop_rounded,
      ReminderType.breakfast ||
      ReminderType.lunch ||
      ReminderType.dinner ||
      ReminderType.snack =>
        Icons.restaurant_rounded,
      ReminderType.exercise => Icons.directions_run_rounded,
      ReminderType.habit => Icons.check_box_outlined,
      ReminderType.weight => Icons.scale_rounded,
      ReminderType.weeklyReview => Icons.analytics_rounded,
      _ => Icons.alarm_rounded,
    };
  }

  Color _getEventColor(ReminderType type) {
    return switch (type) {
      ReminderType.hydration => AppColors.hydration,
      ReminderType.exercise => AppColors.calories,
      ReminderType.weight => AppColors.fat,
      ReminderType.weeklyReview => AppColors.ai,
      ReminderType.habit => AppColors.carbs,
      _ => AppColors.primary500,
    };
  }
}
