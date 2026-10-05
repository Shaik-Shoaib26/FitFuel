import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';

/// Single compact date navigation row for Nutrition screen (Phase 35.6.4).
/// Structure: < [calendar_icon] Today, Oct 5 >
class NutritionDateSelector extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const NutritionDateSelector({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(date.year, date.month, date.day);

    if (current == today) {
      return 'Today, ${DateFormat('MMM d').format(date)}';
    }
    final yesterday = today.subtract(const Duration(days: 1));
    if (current == yesterday) {
      return 'Yesterday, ${DateFormat('MMM d').format(date)}';
    }
    final tomorrow = today.add(const Duration(days: 1));
    if (current == tomorrow) {
      return 'Tomorrow, ${DateFormat('MMM d').format(date)}';
    }
    return DateFormat('EEE, MMM d').format(date);
  }

  Future<void> _selectDateFromPicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primaryLeafGreen,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onDateChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryText = isDark ? Colors.white : AppColors.primaryText;
    final secondaryText = isDark ? Colors.white70 : AppColors.secondaryText;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Previous day (<)
        Semantics(
          button: true,
          label: 'Previous date',
          child: IconButton(
            icon: const Icon(Icons.chevron_left_rounded, size: 22),
            color: secondaryText,
            tooltip: 'Previous date',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () =>
                onDateChanged(selectedDate.subtract(const Duration(days: 1))),
          ),
        ),

        // Date Display with Calendar Icon
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _selectDateFromPicker(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: primaryText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(selectedDate),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Next day (>)
        Semantics(
          button: true,
          label: 'Next date',
          child: IconButton(
            icon: const Icon(Icons.chevron_right_rounded, size: 22),
            color: secondaryText,
            tooltip: 'Next date',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () =>
                onDateChanged(selectedDate.add(const Duration(days: 1))),
          ),
        ),
      ],
    );
  }
}
