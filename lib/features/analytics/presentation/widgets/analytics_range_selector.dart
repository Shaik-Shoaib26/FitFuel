import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

/// Range Selector for Analytics Screen
class AnalyticsRangeSelector extends StatelessWidget {
  final String selectedRange;
  final ValueChanged<String> onRangeChanged;

  const AnalyticsRangeSelector({
    super.key,
    required this.selectedRange,
    required this.onRangeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ranges = ['7D', '30D', '90D', '1Y'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ranges.map((range) {
          final isSelected = range == selectedRange;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: InkWell(
              onTap: () => onRangeChanged(range),
              borderRadius: BorderRadius.circular(AppConstants.radiusSm),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary500 : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: Text(
                  range,
                  style: TextStyle(
                    color: isSelected
                        ? Colors.white
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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
