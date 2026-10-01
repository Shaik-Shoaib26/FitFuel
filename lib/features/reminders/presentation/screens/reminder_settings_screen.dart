import 'package:fitfuel/app/navigation/fitfuel_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import '../../domain/entities/reminder_settings_entity.dart';
import '../providers/reminders_providers.dart';

class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState
    extends ConsumerState<ReminderSettingsScreen> {
  ReminderSettingsEntity? _localSettings;

  @override
  void initState() {
    super.initState();
    // Fetch current settings on load
    Future.microtask(() {
      final current = ref.read(remindersSettingsStreamProvider).value;
      if (current != null) {
        setState(() {
          _localSettings = current;
        });
      }
    });
  }

  void _save(ReminderSettingsEntity settings) {
    setState(() {
      _localSettings = settings;
    });
    ref
        .read(remindersSettingsControllerProvider.notifier)
        .updateSettings(settings);
  }

  TimeOfDay _parseTimeString(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _selectTime(
      BuildContext context, String timeKey, String currentTime) async {
    final parsed = _parseTimeString(currentTime);
    final selected = await showTimePicker(
      context: context,
      initialTime: parsed,
    );
    if (selected != null) {
      final formatted = _formatTimeOfDay(selected);
      final current = _localSettings ?? const ReminderSettingsEntity();
      final updated = _updateSettingsField(current, timeKey, formatted);
      _save(updated);
    }
  }

  ReminderSettingsEntity _updateSettingsField(
      ReminderSettingsEntity current, String key, dynamic value) {
    switch (key) {
      case 'breakfastTime':
        return current.copyWith(breakfastTime: value);
      case 'lunchTime':
        return current.copyWith(lunchTime: value);
      case 'dinnerTime':
        return current.copyWith(dinnerTime: value);
      case 'snackTime':
        return current.copyWith(snackTime: value);
      case 'exerciseTime':
        return current.copyWith(exerciseTime: value);
      case 'weightTime':
        return current.copyWith(weightTime: value);
      case 'weeklyReviewTime':
        return current.copyWith(weeklyReviewTime: value);
      case 'aiCoachTime':
        return current.copyWith(aiCoachTime: value);
      default:
        return current;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsAsync = ref.watch(remindersSettingsStreamProvider);

    // Sync from stream if localSettings is not initialized yet
    final settings =
        _localSettings ?? settingsAsync.value ?? const ReminderSettingsEntity();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBgBase : AppColors.lightBgBase,
      appBar: const FitFuelAppBar(
        title: Text('Reminder Settings'),
        centerTitle: true,
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, __) => Center(child: Text('Failed to load settings: $e')),
        data: (_) => SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('Daily Habits & Hydration', isDark),
              const SizedBox(height: AppConstants.spaceSm),
              FitFuelCard(
                child: Column(
                  children: [
                    _buildSwitchRow(
                      title: 'Water Reminders',
                      subtitle: 'Sip reminders sent throughout the day',
                      value: settings.hydrationEnabled,
                      onChanged: (val) =>
                          _save(settings.copyWith(hydrationEnabled: val)),
                      isDark: isDark,
                    ),
                    const Divider(),
                    _buildSwitchRow(
                      title: 'Habit Reminders',
                      subtitle: 'Alerts to complete your habit checklist',
                      value: settings.habitEnabled,
                      onChanged: (val) =>
                          _save(settings.copyWith(habitEnabled: val)),
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceLg),
              _buildSectionHeader('Meal Reminders', isDark),
              const SizedBox(height: AppConstants.spaceSm),
              FitFuelCard(
                child: Column(
                  children: [
                    _buildSwitchRow(
                      title: 'Meal Reminders',
                      subtitle:
                          'Get alerts at designated breakfast/lunch/dinner times',
                      value: settings.mealEnabled,
                      onChanged: (val) =>
                          _save(settings.copyWith(mealEnabled: val)),
                      isDark: isDark,
                    ),
                    if (settings.mealEnabled) ...[
                      const Divider(),
                      _buildTimePickerRow(
                          'Breakfast Time',
                          settings.breakfastTime,
                          () => _selectTime(
                              context, 'breakfastTime', settings.breakfastTime),
                          isDark),
                      const Divider(),
                      _buildTimePickerRow(
                          'Lunch Time',
                          settings.lunchTime,
                          () => _selectTime(
                              context, 'lunchTime', settings.lunchTime),
                          isDark),
                      const Divider(),
                      _buildTimePickerRow(
                          'Snack Time',
                          settings.snackTime,
                          () => _selectTime(
                              context, 'snackTime', settings.snackTime),
                          isDark),
                      const Divider(),
                      _buildTimePickerRow(
                          'Dinner Time',
                          settings.dinnerTime,
                          () => _selectTime(
                              context, 'dinnerTime', settings.dinnerTime),
                          isDark),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceLg),
              _buildSectionHeader('Fitness & Progress tracking', isDark),
              const SizedBox(height: AppConstants.spaceSm),
              FitFuelCard(
                child: Column(
                  children: [
                    _buildSwitchRow(
                      title: 'Exercise Reminders',
                      subtitle: 'Notifications to log workouts',
                      value: settings.exerciseEnabled,
                      onChanged: (val) =>
                          _save(settings.copyWith(exerciseEnabled: val)),
                      isDark: isDark,
                    ),
                    if (settings.exerciseEnabled) ...[
                      const Divider(),
                      _buildTimePickerRow(
                          'Workout Slot',
                          settings.exerciseTime,
                          () => _selectTime(
                              context, 'exerciseTime', settings.exerciseTime),
                          isDark),
                    ],
                    const Divider(),
                    _buildSwitchRow(
                      title: 'Weight Reminders',
                      subtitle: 'Weigh-in tracker notifications',
                      value: settings.weightEnabled,
                      onChanged: (val) =>
                          _save(settings.copyWith(weightEnabled: val)),
                      isDark: isDark,
                    ),
                    if (settings.weightEnabled) ...[
                      const Divider(),
                      _buildTimePickerRow(
                          'Weigh-In Time',
                          settings.weightTime,
                          () => _selectTime(
                              context, 'weightTime', settings.weightTime),
                          isDark),
                      const Divider(),
                      _buildDropdownRow(
                        title: 'Weigh-In Day',
                        value: settings.weightDay,
                        items: const [
                          'Monday',
                          'Tuesday',
                          'Wednesday',
                          'Thursday',
                          'Friday',
                          'Saturday',
                          'Sunday'
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            _save(settings.copyWith(weightDay: val));
                          }
                        },
                        isDark: isDark,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceLg),
              _buildSectionHeader('General & Weekly Reviews', isDark),
              const SizedBox(height: AppConstants.spaceSm),
              FitFuelCard(
                child: Column(
                  children: [
                    _buildSwitchRow(
                      title: 'Nutrition Logs Check',
                      subtitle: 'Daily log summary notifications',
                      value: settings.nutritionLoggingEnabled,
                      onChanged: (val) => _save(
                          settings.copyWith(nutritionLoggingEnabled: val)),
                      isDark: isDark,
                    ),
                    const Divider(),
                    _buildSwitchRow(
                      title: 'Weekly Report Alert',
                      subtitle: 'When your weekly wellness scorecard is ready',
                      value: settings.weeklyReviewEnabled,
                      onChanged: (val) =>
                          _save(settings.copyWith(weeklyReviewEnabled: val)),
                      isDark: isDark,
                    ),
                    if (settings.weeklyReviewEnabled) ...[
                      const Divider(),
                      _buildTimePickerRow(
                          'Report Alert Time',
                          settings.weeklyReviewTime,
                          () => _selectTime(context, 'weeklyReviewTime',
                              settings.weeklyReviewTime),
                          isDark),
                    ],
                    const Divider(),
                    _buildSwitchRow(
                      title: 'AI Coaching Prompts',
                      subtitle: 'Daily smart reminder check-ins',
                      value: settings.aiCoachEnabled,
                      onChanged: (val) =>
                          _save(settings.copyWith(aiCoachEnabled: val)),
                      isDark: isDark,
                    ),
                    if (settings.aiCoachEnabled) ...[
                      const Divider(),
                      _buildTimePickerRow(
                          'AI Coach Slot',
                          settings.aiCoachTime,
                          () => _selectTime(
                              context, 'aiCoachTime', settings.aiCoachTime),
                          isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceXs),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.caption(isDark: isDark).copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.primary500,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return SwitchListTile(
      title: Text(title,
          style: AppTypography.bodyLarge(isDark: isDark)
              .copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: AppTypography.bodySmall(isDark: isDark)),
      value: value,
      onChanged: onChanged,
      activeTrackColor: AppColors.primary500.withAlpha(128),
      activeThumbColor: AppColors.primary500,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildTimePickerRow(
      String label, String value, VoidCallback onTap, bool isDark) {
    return ListTile(
      title: Text(label, style: AppTypography.bodyMedium(isDark: isDark)),
      trailing: TextButton.icon(
        icon: const Icon(Icons.access_time_rounded,
            size: 16, color: AppColors.primary500),
        label: Text(value,
            style: const TextStyle(
                color: AppColors.primary500, fontWeight: FontWeight.bold)),
        onPressed: onTap,
      ),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildDropdownRow({
    required String title,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return ListTile(
      title: Text(title, style: AppTypography.bodyMedium(isDark: isDark)),
      trailing: DropdownButton<String>(
        value: value,
        items: items
            .map((i) => DropdownMenuItem(
                  value: i,
                  child: Text(i,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87)),
                ))
            .toList(),
        onChanged: onChanged,
        underline: Container(),
      ),
      contentPadding: EdgeInsets.zero,
    );
  }
}
