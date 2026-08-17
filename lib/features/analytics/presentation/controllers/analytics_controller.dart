import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/health_analytics_entity.dart';
import '../../domain/repositories/i_analytics_repository.dart';

class AnalyticsState {
  final String range;
  final AsyncValue<HealthAnalyticsEntity> analytics;

  const AnalyticsState({
    this.range = '30D',
    this.analytics = const AsyncValue.loading(),
  });

  AnalyticsState copyWith({
    String? range,
    AsyncValue<HealthAnalyticsEntity>? analytics,
  }) {
    return AnalyticsState(
      range: range ?? this.range,
      analytics: analytics ?? this.analytics,
    );
  }
}

class AnalyticsController extends StateNotifier<AnalyticsState> {
  final IAnalyticsRepository _repository;
  final String? _uid;

  AnalyticsController(this._repository, this._uid) : super(const AnalyticsState()) {
    loadAnalytics();
  }

  Future<void> loadAnalytics() async {
    final uid = _uid;
    if (uid == null) {
      state = state.copyWith(
        analytics: AsyncValue.error('User not authenticated', StackTrace.current),
      );
      return;
    }
    try {
      final data = await _repository.getAnalytics(
        uid: uid,
        range: state.range,
        today: DateTime.now(),
      );
      state = state.copyWith(analytics: AsyncValue.data(data));
    } catch (e, st) {
      state = state.copyWith(analytics: AsyncValue.error(e, st));
    }
  }

  void changeRange(String newRange) {
    if (state.range == newRange) return;
    state = state.copyWith(
      range: newRange,
      analytics: const AsyncValue.loading(),
    );
    loadAnalytics();
  }
}
