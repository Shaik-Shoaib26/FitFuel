import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../data/datasources/analytics_remote_datasource.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/repositories/i_analytics_repository.dart';
import '../controllers/analytics_controller.dart';

final analyticsRemoteDataSourceProvider =
    Provider<IAnalyticsRemoteDataSource>((ref) {
  return AnalyticsRemoteDataSourceImpl();
});

final analyticsRepositoryProvider = Provider<IAnalyticsRepository>((ref) {
  final dataSource = ref.watch(analyticsRemoteDataSourceProvider);
  return AnalyticsRepositoryImpl(dataSource);
});

final analyticsControllerProvider =
    StateNotifierProvider<AnalyticsController, AnalyticsState>((ref) {
  final uid =
      ref.watch(authStateStreamProvider.select((auth) => auth.value?.uid));
  final repository = ref.watch(analyticsRepositoryProvider);
  final controller = AnalyticsController(repository, uid);
  ref.listen(nutritionStreamProvider, (_, next) {
    if (next.hasValue) controller.loadAnalytics();
  });
  ref.listen(healthStreamProvider, (_, next) {
    if (next.hasValue) controller.loadAnalytics();
  });
  ref.listen(weightHistoryStreamProvider, (_, next) {
    if (next.hasValue) controller.loadAnalytics();
  });
  return controller;
});
