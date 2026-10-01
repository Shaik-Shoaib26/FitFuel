import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../../core/widgets/fitfuel_card.dart';
import '../../../../core/widgets/fitfuel_empty_state.dart';
import '../../../../core/widgets/fitfuel_error_state.dart';
import '../../../../core/widgets/fitfuel_loading_state.dart';
import '../../../../core/widgets/fitfuel_section_header.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../progress/domain/utils/progress_calculator.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../providers/health_providers.dart';
import '../widgets/weight_panel.dart';

class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateStreamProvider).value?.uid;
    final history = ref.watch(weightHistoryStreamProvider);
    // valueOrNull keeps a failed stream from rethrowing during build.
    final nutrition = ref.watch(nutritionStreamProvider).valueOrNull ?? [];
    final health = ref.watch(healthStreamProvider).valueOrNull ?? [];
    final goals = ref.watch(nutritionGoalsStreamProvider).valueOrNull;
    final profile = ref.watch(currentProfileStreamProvider).valueOrNull;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const FitFuelAppBar(title: Text('Weight')),
      body: AdaptivePageLayout(
        maxWidth: 800,
        child: SafeArea(
          child: history.when(
            loading: () =>
                const FitFuelLoadingState(label: 'Loading your weight history'),
            error: (error, _) => FitFuelErrorState(
                error: error,
                onRetry: () => ref.invalidate(weightHistoryStreamProvider)),
            data: (items) => uid == null
                ? const FitFuelEmptyState(
                    icon: Icons.lock_outline,
                    title: 'Sign in to log weight',
                    description:
                        'Your weight history is private to your account.',
                  )
                : SingleChildScrollView(
                    key: const PageStorageKey('weight-scroll'),
                    padding: AdaptivePageLayout.pagePadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        WeightPanel(
                            uid: uid,
                            history: items,
                            summary: ProgressCalculator.calculateSummary(
                                nutritionHistory: nutrition,
                                healthHistory: health,
                                weightHistory: items,
                                goals: goals,
                                profile: profile,
                                daysCount: ref
                                    .watch(progressControllerProvider)
                                    .selectedRange)),
                        if (items.isNotEmpty) ...[
                          const SizedBox(height: AppConstants.spaceLg),
                          const FitFuelSectionHeader(title: 'History'),
                          const SizedBox(height: AppConstants.spaceSmd),
                          FitFuelCard(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            semanticsLabel: 'Weight history',
                            child: Column(
                              children: [
                                for (final item in items)
                                  ListTile(
                                    dense: true,
                                    leading: Icon(
                                        Icons.monitor_weight_outlined,
                                        size: 20,
                                        color: theme.colorScheme.primary),
                                    title: Text(
                                      '${item.weight.toStringAsFixed(1)} kg',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      item.recordedAt
                                          .toLocal()
                                          .toString()
                                          .split(' ')
                                          .first,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
