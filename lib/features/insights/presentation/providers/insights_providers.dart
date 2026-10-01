import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../data/datasources/insights_remote_datasource.dart';
import '../../data/repositories/insights_repository_impl.dart';
import '../../domain/repositories/i_insights_repository.dart';
import '../../domain/entities/health_insight_entity.dart';
import '../../domain/entities/action_recommendation_entity.dart';
import '../../domain/utils/action_recommendation_engine.dart';
import '../controllers/insights_controller.dart';

final insightsRemoteDataSourceProvider =
    Provider<IInsightsRemoteDataSource>((ref) {
  return InsightsRemoteDataSourceImpl();
});

final insightsRepositoryProvider = Provider<IInsightsRepository>((ref) {
  final dataSource = ref.watch(insightsRemoteDataSourceProvider);
  return InsightsRepositoryImpl(dataSource);
});

final insightsControllerProvider =
    StateNotifierProvider<InsightsController, InsightsState>((ref) {
  final uid =
      ref.watch(authStateStreamProvider.select((auth) => auth.value?.uid));
  final repository = ref.watch(insightsRepositoryProvider);
  final controller = InsightsController(repository, uid);
  ref.listen(nutritionStreamProvider, (_, next) {
    if (next.hasValue) controller.loadInsights();
  });
  ref.listen(healthStreamProvider, (_, next) {
    if (next.hasValue) controller.loadInsights();
  });
  ref.listen(weightHistoryStreamProvider, (_, next) {
    if (next.hasValue) controller.loadInsights();
  });
  return controller;
});

final dailyFocusProvider = Provider<AsyncValue<dynamic>>((ref) {
  final state = ref.watch(insightsControllerProvider);
  return state.dailyFocus;
});

int _priorityWeight(InsightPriority p) {
  switch (p) {
    case InsightPriority.critical:
      return 0;
    case InsightPriority.high:
      return 1;
    case InsightPriority.medium:
      return 2;
    case InsightPriority.low:
      return 3;
    case InsightPriority.positive:
      return 4;
  }
}

final priorityInsightsProvider =
    Provider<AsyncValue<List<HealthInsightEntity>>>((ref) {
  final state = ref.watch(insightsControllerProvider);
  return state.insights.whenData((list) {
    // Filter out positive ones from active priority insights
    final activeInsights =
        list.where((i) => i.category != InsightCategory.positive).toList();

    // Sort by priority ascending (0 = critical, etc.)
    activeInsights.sort((a, b) {
      final wa = _priorityWeight(a.priority);
      final wb = _priorityWeight(b.priority);
      if (wa != wb) return wa.compareTo(wb);

      // Largest deficit check
      final defA = (a.targetValue ?? 0.0) - (a.metricValue ?? 0.0);
      final defB = (b.targetValue ?? 0.0) - (b.metricValue ?? 0.0);
      return defB.compareTo(defA); // descending order of deficit
    });

    return activeInsights.take(3).toList();
  });
});

final recommendedActionsProvider =
    Provider<AsyncValue<List<ActionRecommendationEntity>>>((ref) {
  final priorityAsync = ref.watch(priorityInsightsProvider);
  return priorityAsync.whenData((insights) {
    final List<ActionRecommendationEntity> actions = [];
    final Set<InsightActionType> seen = {};

    for (final insight in insights) {
      if (insight.actionType != InsightActionType.none &&
          !seen.contains(insight.actionType)) {
        seen.add(insight.actionType);
        actions.add(ActionRecommendationEngine.generate(
            insight.actionType, insight.priority));
      }
    }

    // Default action if empty
    if (actions.isEmpty) {
      actions.add(ActionRecommendationEngine.generate(
          InsightActionType.none, InsightPriority.positive));
    }
    return actions;
  });
});
