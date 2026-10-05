import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../food/presentation/providers/food_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../../grocery/presentation/providers/grocery_providers.dart';
import '../../data/datasources/smart_eat_remote_datasource.dart';
import '../../data/repositories/smart_eat_repository_impl.dart';
import '../../domain/repositories/i_smart_eat_repository.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';
import '../../domain/entities/nutrition_gap_entity.dart';
import '../controllers/smart_eat_controller.dart';

final smartEatDataSourceProvider = Provider<SmartEatRemoteDataSource>((ref) {
  try {
    final foodRepo = ref.watch(foodRepositoryProvider);
    final profileRepo = ref.watch(profileRepositoryProvider);
    final nutritionRepo = ref.watch(nutritionRepositoryProvider);
    final healthRepo = ref.watch(healthRepositoryProvider);
    final groceryRepo = ref.watch(groceryRepositoryProvider);

    return SmartEatRemoteDataSourceImpl(
      foodRepository: foodRepo,
      profileRepository: profileRepo,
      nutritionRepository: nutritionRepo,
      healthRepository: healthRepo,
      groceryRepository: groceryRepo,
    );
  } catch (_) {
    return const FallbackSmartEatRemoteDataSource();
  }
});

final smartEatRepositoryProvider = Provider<ISmartEatRepository>((ref) {
  final dataSource = ref.watch(smartEatDataSourceProvider);
  return SmartEatRepositoryImpl(dataSource);
});

final smartEatControllerProvider =
    StateNotifierProvider<SmartEatController, SmartEatState>((ref) {
  final repo = ref.watch(smartEatRepositoryProvider);
  final controller = SmartEatController(repo, ref);
  // Initial refresh trigger
  Future.microtask(() => controller.refresh());
  return controller;
});

final smartEatRecommendationsProvider =
    Provider<AsyncValue<List<SmartFoodRecommendationEntity>>>((ref) {
  return ref.watch(smartEatControllerProvider.select((s) => s.recommendations));
});

final smartEatTopRecommendationProvider =
    Provider<AsyncValue<SmartFoodRecommendationEntity?>>((ref) {
  final asyncList = ref.watch(smartEatRecommendationsProvider);
  return asyncList.whenData((list) => list.isNotEmpty ? list.first : null);
});

final nutritionGapProvider = Provider<AsyncValue<NutritionGapEntity>>((ref) {
  return ref.watch(smartEatControllerProvider.select((s) => s.gap));
});

final smartFoodSwapProvider =
    Provider.family<List<SmartFoodRecommendationEntity>, SmartFoodRecommendationEntity>((ref, original) {
  final state = ref.watch(smartEatControllerProvider);
  final list = state.swaps[original.foodId];
  if (list == null) {
    // Trigger swap load asynchronously
    Future.microtask(() {
      ref.read(smartEatControllerProvider.notifier).loadSwaps(original);
    });
    return const [];
  }
  return list;
});
