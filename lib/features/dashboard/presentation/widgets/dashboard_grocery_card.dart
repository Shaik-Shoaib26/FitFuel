import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/core/constants/app_typography.dart';
import 'package:fitfuel/core/widgets/fitfuel_card.dart';
import '../../../grocery/presentation/providers/grocery_providers.dart';

class DashboardGroceryCard extends ConsumerWidget {
  const DashboardGroceryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final listAsync = ref.watch(currentGroceryListProvider);
    final pantryAsync = ref.watch(pantryProvider);

    return listAsync.when(
      data: (list) {
        if (list == null) {
          // Fallback card when no grocery list exists
          return FitFuelCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Smart Grocery',
                      style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 16),
                    ),
                    const Icon(Icons.shopping_cart_outlined, color: AppColors.primary500),
                  ],
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Text(
                  'No grocery list generated yet.',
                  style: AppTypography.bodySmall(isDark: isDark),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.push('/grocery'),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Create Grocery List'),
                  ),
                ),
              ],
            ),
          );
        }

        final pantryCount = pantryAsync.value?.length ?? 0;

        return FitFuelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Smart Grocery',
                    style: AppTypography.heading2(isDark: isDark).copyWith(fontSize: 16),
                  ),
                  Text(
                    '${list.completionPercentage.toStringAsFixed(0)}%',
                    style: AppTypography.heading2(isDark: isDark).copyWith(
                      fontSize: 16,
                      color: AppColors.primary500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceSm),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: list.completionPercentage / 100.0,
                  backgroundColor: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
                  color: AppColors.primary500,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: AppConstants.spaceSm),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🛒 ${list.remainingItems} items remaining',
                        style: AppTypography.bodySmall(isDark: isDark).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pantryCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '📦 $pantryCount items already in pantry',
                            style: AppTypography.caption(isDark: isDark).copyWith(
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/grocery'),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('View Grocery List'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const FitFuelCard(
        child: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => FitFuelCard(
        child: Text('Error loading grocery card: $err'),
      ),
    );
  }
}
