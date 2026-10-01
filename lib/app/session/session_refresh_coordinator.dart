import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/network_status.dart';
import '../../core/network/network_status_provider.dart';
import '../../features/profile/presentation/providers/profile_providers.dart';
import '../../features/nutrition/presentation/providers/nutrition_providers.dart';
import '../../features/health/presentation/providers/health_providers.dart';
import '../../features/progress/presentation/controllers/progress_controller.dart';
import '../../features/grocery/presentation/providers/grocery_providers.dart';

/// Stream refresh previously owned by Dashboard. Planner and Smart Eat retain
/// their existing reconnect listeners and are not explicitly reloaded here.
class SessionRefreshCoordinator extends ConsumerWidget {
  final Widget child;
  const SessionRefreshCoordinator({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(networkStatusProvider, (previous, next) {
      if (previous?.value == NetworkStatus.offline &&
          next.value == NetworkStatus.online) {
        ref.invalidate(currentProfileStreamProvider);
        ref.invalidate(nutritionGoalsStreamProvider);
        ref.invalidate(nutritionStreamProvider);
        ref.invalidate(healthStreamProvider);
        ref.invalidate(weightHistoryStreamProvider);
        ref.invalidate(pantryProvider);
        ref.invalidate(groceryListsProvider);
      }
    });
    return child;
  }
}
