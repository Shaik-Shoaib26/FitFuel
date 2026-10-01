import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_card.dart';

class AnalyticsEmptyState extends StatelessWidget {
  const AnalyticsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spaceMd),
          child: FitFuelCard(
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Icon(
                    Icons.analytics_outlined,
                    size: 32,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Text(
                  'No health data yet',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'Log nutrition, water, exercise, or habits to generate health insights and trends.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceLg),
                Wrap(
                  spacing: AppConstants.spaceSm,
                  runSpacing: AppConstants.spaceSm,
                  alignment: WrapAlignment.center,
                  children: [
                    _buildActionChip(
                      context,
                      icon: Icons.restaurant,
                      label: 'Log Meal',
                      onTap: () => context.go('/nutrition'),
                      isDark: isDark,
                    ),
                    _buildActionChip(
                      context,
                      icon: Icons.local_drink,
                      label: 'Track Water',
                      onTap: () => context.go('/health'),
                      isDark: isDark,
                    ),
                    _buildActionChip(
                      context,
                      icon: Icons.fitness_center,
                      label: 'Log Exercise',
                      onTap: () => context.go('/health'),
                      isDark: isDark,
                    ),
                    _buildActionChip(
                      context,
                      icon: Icons.monitor_weight_outlined,
                      label: 'Log Weight',
                      onTap: () => context.go('/health'),
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgSurface : AppColors.lightBgSurface,
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorderSubtle
                : AppColors.lightBorderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
