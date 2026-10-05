import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Modern & Minimal Segmented Time-Range Selector for Progress Dashboard.
/// Matches Option A visual target: "7 Days" | "30 Days" | "90 Days".
class ProgressRangeSelector extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onRangeSelected;

  const ProgressRangeSelector({
    super.key,
    required this.selectedDays,
    required this.onRangeSelected,
  });

  static const List<int> _ranges = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerBg = isDark
        ? AppColors.darkBgSurface
        : const Color(0xFFEFF2ED);

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: _ranges.map((days) {
          final isSelected = selectedDays == days;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: '$days Days time range',
              child: InkWell(
                onTap: () => onRangeSelected(days),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryLeafGreen
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primaryLeafGreen.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$days Days',
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.secondaryText),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
