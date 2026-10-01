import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import '../../../analytics/presentation/providers/analytics_providers.dart';
import '../../../analytics/domain/utils/analytics_insight_engine.dart';

class DashboardAnalyticsCard extends ConsumerWidget {
  const DashboardAnalyticsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analyticsState = ref.watch(analyticsControllerProvider);

    return analyticsState.analytics.when(
      loading: () => const FitFuelCard(
        border: BorderSide(color: AppColors.carbs, width: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Analytics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppConstants.spaceSm),
            Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
      error: (err, st) => const FitFuelCard(
        border: BorderSide(color: AppColors.carbs, width: 1.5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Health Analytics',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppConstants.spaceSm),
            Text('Could not load health analytics.'),
          ],
        ),
      ),
      data: (entity) {
        final summary = entity.summary;

        if (summary.activeLoggingDays == 0) {
          return FitFuelCard(
            border: const BorderSide(color: AppColors.carbs, width: 1.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Health Analytics',
                      style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 16),
                    ),
                    const Icon(Icons.analytics_outlined, color: AppColors.primary500),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'Start logging meals, water, or workouts to build your Health Analytics dashboard.',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.push('/analytics'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('View Analytics'),
                  ),
                ),
              ],
            ),
          );
        }

        final focusArea = AnalyticsInsightEngine.detectFocusArea(summary, entity.dataPoints);
        final strongest = AnalyticsInsightEngine.detectStrongestCategory(summary);

        return FitFuelCard(
          border: const BorderSide(color: AppColors.carbs, width: 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Health Analytics',
                    style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 16),
                  ),
                  const Icon(Icons.analytics_outlined, color: AppColors.primary500),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Overall Consistency',
                        style: AppTypography.bodySmall(isDark: isDark),
                      ),
                      Text(
                        '${summary.overallConsistencyPercentage.toStringAsFixed(0)}%',
                        style: AppTypography.heading1(isDark: isDark).copyWith(
                          fontSize: 28,
                          color: AppColors.primary500,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary500.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${summary.currentLoggingStreak} Days Streak',
                          style: AppTypography.bodySmall(isDark: isDark).copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: _buildBadge(
                      isDark: isDark,
                      icon: Icons.star_rounded,
                      iconColor: Colors.amber,
                      label: 'Top: $strongest',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBadge(
                      isDark: isDark,
                      icon: Icons.warning_amber_rounded,
                      iconColor: Colors.orange,
                      label: 'Focus: ${focusArea.category}',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => context.push('/analytics'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View Analytics'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 14),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
