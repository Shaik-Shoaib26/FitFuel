import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../progress/presentation/controllers/progress_controller.dart';
import '../../data/datasources/analytics_remote_datasource.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../../domain/repositories/i_analytics_repository.dart';
import '../controllers/analytics_controller.dart';

final analyticsRemoteDataSourceProvider = Provider<IAnalyticsRemoteDataSource>((ref) {
  return AnalyticsRemoteDataSourceImpl();
});

final analyticsRepositoryProvider = Provider<IAnalyticsRepository>((ref) {
  final dataSource = ref.watch(analyticsRemoteDataSourceProvider);
  return AnalyticsRepositoryImpl(dataSource);
});

final analyticsControllerProvider = StateNotifierProvider<AnalyticsController, AnalyticsState>((ref) {
  // Listen to underlying stream updates to keep stats live
  ref.watch(nutritionStreamProvider);
  ref.watch(healthStreamProvider);
  ref.watch(weightHistoryStreamProvider);

  final authUser = ref.watch(authStateStreamProvider).value;
  final repository = ref.watch(analyticsRepositoryProvider);
  return AnalyticsController(repository, authUser?.uid);
});
