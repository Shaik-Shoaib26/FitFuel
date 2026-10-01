import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/health_insight_entity.dart';
import '../../domain/entities/daily_focus_entity.dart';
import '../../domain/repositories/i_insights_repository.dart';

class InsightsState {
  final AsyncValue<List<HealthInsightEntity>> insights;
  final AsyncValue<DailyFocusEntity> dailyFocus;
  final String filter; // 'All', 'Nutrition', 'Fitness', 'Wellness', 'Progress'

  const InsightsState({
    this.insights = const AsyncValue.loading(),
    this.dailyFocus = const AsyncValue.loading(),
    this.filter = 'All',
  });

  InsightsState copyWith({
    AsyncValue<List<HealthInsightEntity>>? insights,
    AsyncValue<DailyFocusEntity>? dailyFocus,
    String? filter,
  }) {
    return InsightsState(
      insights: insights ?? this.insights,
      dailyFocus: dailyFocus ?? this.dailyFocus,
      filter: filter ?? this.filter,
    );
  }
}

class InsightsController extends StateNotifier<InsightsState> {
  final IInsightsRepository _repository;
  final String? _uid;
  int _request = 0;

  InsightsController(this._repository, this._uid)
      : super(const InsightsState()) {
    loadInsights();
  }

  Future<void> loadInsights() async {
    final request = ++_request;
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(
        insights:
            AsyncValue.error('User not authenticated', StackTrace.current),
        dailyFocus:
            AsyncValue.error('User not authenticated', StackTrace.current),
      );
      return;
    }
    try {
      final today = DateTime.now();
      final insightsList =
          await _repository.getInsights(uid: uid, today: today);
      final focus = await _repository.getDailyFocus(uid: uid, today: today);

      if (!mounted || request != _request) return;
      state = state.copyWith(
        insights: AsyncValue.data(insightsList),
        dailyFocus: AsyncValue.data(focus),
      );
    } catch (e, st) {
      if (!mounted || request != _request) return;
      state = state.copyWith(
        insights: AsyncValue.error(e, st),
        dailyFocus: AsyncValue.error(e, st),
      );
    }
  }

  void changeFilter(String newFilter) {
    state = state.copyWith(filter: newFilter);
  }
}
