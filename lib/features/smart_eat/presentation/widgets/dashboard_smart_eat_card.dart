import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/fitfuel_button.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../providers/smart_eat_providers.dart';

/// Clean Home Dashboard Smart Eat Recommendation Card
class DashboardSmartEatCard extends ConsumerWidget {
  const DashboardSmartEatCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(smartEatControllerProvider);
    final recommendationsAsync = ref.watch(smartEatRecommendationsProvider);

    return FitFuelCard(
      border: const BorderSide(color: AppColors.ai, width: 1.2),
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.ai.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.ai,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: Text(
                  'What should I eat?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceSm),
          recommendationsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => Text(
              'Unable to load recommendation.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Text(
                  'No recommendations available.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                );
              }
              final rec = list.first;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Next meal: ${state.activeMealType}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary500.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        ),
                        child: Text(
                          '${rec.matchScore}% Match',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary500,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    rec.foodName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${rec.calories.round()} kcal • ${rec.protein.round()}g protein',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppConstants.spaceMd),
          FitFuelButton(
            label: 'View Recommendations',
            icon: Icons.auto_awesome_rounded,
            onPressed: () => context.go('/plan/smart-eat'),
          ),
        ],
      ),
    );
  }
}
