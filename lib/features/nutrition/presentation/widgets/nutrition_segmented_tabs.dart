import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Top Segmented Tabs for Nutrition screen matching Option B reference:
/// Tabs: Food Diary, Macros, Insights.
/// Selected: Primary Green (#0F7D38) pill with white text.
/// Unselected: Transparent with secondary gray text.
class NutritionSegmentedTabs extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const NutritionSegmentedTabs({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  static const List<String> _tabLabels = [
    'Food Diary',
    'Macros',
    'Insights',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final containerBg = isDark
        ? AppColors.darkSurfaceVariant
        : const Color(0xFFF1F5F2);

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (int i = 0; i < _tabLabels.length; i++) ...[
            Expanded(
              child: Semantics(
                button: true,
                selected: selectedIndex == i,
                label: '${_tabLabels[i]} tab',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onTabSelected(i),
                    child: Container(
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selectedIndex == i
                            ? (isDark
                                ? AppColors.darkPrimaryContainer
                                : AppColors.primaryLeafGreen)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        _tabLabels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 13.5,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedIndex == i
                              ? (isDark
                                  ? AppColors.primary300
                                  : Colors.white)
                              : (isDark
                                  ? Colors.white70
                                  : AppColors.secondaryText),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
