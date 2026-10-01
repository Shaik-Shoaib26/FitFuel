import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/navigation/fitfuel_app_bar.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';
import '../../../../core/widgets/adaptive_page_layout.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../widgets/home_focus_card.dart';
import '../widgets/home_header.dart';
import '../widgets/home_health_summary.dart';
import '../widgets/home_next_meal_card.dart';
import '../widgets/home_nutrition_hero.dart';
import '../widgets/home_quick_actions.dart';

/// Home is a bounded overview that links into canonical feature pages.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline =
        ref.watch(networkStatusProvider).value == NetworkStatus.offline;
    // Premium tinted canvas in light mode via theme tokens; dark mode keeps
    // the existing dark scaffold background from the theme untouched.
    final pageBackground = Theme.of(context).brightness == Brightness.dark
        ? null
        : Theme.of(context).colorScheme.surfaceContainerLow;
    return Scaffold(
      appBar: const FitFuelAppBar(title: Text('Home')),
      backgroundColor: pageBackground,
      body: AdaptivePageLayout(
        child: RefreshIndicator(
          onRefresh: () async {
            if (offline) return;
            ref.invalidate(currentProfileStreamProvider);
            ref.invalidate(nutritionStreamProvider);
            ref.invalidate(nutritionGoalsStreamProvider);
            ref.invalidate(healthStreamProvider);
          },
          child: SingleChildScrollView(
            key: const PageStorageKey('home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AdaptivePageLayout.pagePadding(context),
            child: Column(
              key: const ValueKey('home-content'),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (offline) const _OfflineNotice(),
                const HomeHeader(),
                const SizedBox(height: AppConstants.spaceLg),
                const _HomeBody(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      // Desktop two-column composition from ~740px of content width: a 1024px
      // window shares space with the 224px sidebar (~752px of content) and
      // still gets the deliberate desktop layout, while 768px tablets (with
      // the icon rail) remain a clean single column.
      final twoColumn = constraints.maxWidth >= 740;
      if (!twoColumn) {
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeNutritionHero(),
            SizedBox(height: AppConstants.spaceLg),
            HomeFocusCard(),
            SizedBox(height: AppConstants.spaceLg),
            HomeNextMealCard(),
            SizedBox(height: AppConstants.spaceLg),
            HomeQuickActions(),
            SizedBox(height: AppConstants.spaceLg),
            HomeHealthSummary(),
          ],
        );
      }
      // Desktop: ~65% primary column (nutrition + focus), ~35% support
      // column (next meal, quick actions, health).
      return const Row(
        key: ValueKey('home-desktop-columns'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 13,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeNutritionHero(),
                SizedBox(height: AppConstants.spaceLg),
                HomeFocusCard(),
              ],
            ),
          ),
          SizedBox(width: AppConstants.spaceLg),
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeNextMealCard(),
                SizedBox(height: AppConstants.spaceLg),
                HomeQuickActions(),
                SizedBox(height: AppConstants.spaceLg),
                HomeHealthSummary(),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceSmd, vertical: AppConstants.spaceSm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppConstants.radiusControl),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: AppConstants.spaceSm),
            Expanded(
              child: Text(
                'No internet connection. Connect to log or refresh your information.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
