import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/nutrition_remote_datasource.dart';
import '../../data/repositories/nutrition_repository_impl.dart';
import '../../domain/entities/nutrition_record_entity.dart';
import '../../domain/repositories/i_nutrition_repository.dart';



/// Provider for low-level INutritionRemoteDataSource
final nutritionRemoteDataSourceProvider = Provider<INutritionRemoteDataSource>((ref) {
  return NutritionRemoteDataSourceImpl();
});

/// Provider for INutritionRepository
final nutritionRepositoryProvider = Provider<INutritionRepository>((ref) {
  final dataSource = ref.watch(nutritionRemoteDataSourceProvider);
  return NutritionRepositoryImpl(dataSource);
});

/// StreamProvider listening to the currently authenticated user's nutrition subcollection
final nutritionStreamProvider = StreamProvider<List<NutritionRecordEntity>>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) {
    return Stream.value([]);
  }
  final repository = ref.watch(nutritionRepositoryProvider);
  return repository.streamRecords(authUser.uid);
});
