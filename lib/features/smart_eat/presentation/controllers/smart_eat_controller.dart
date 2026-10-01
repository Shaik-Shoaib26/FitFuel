import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../../nutrition/presentation/providers/nutrition_providers.dart';
import '../../../ai_assistant/presentation/providers/ai_assistant_providers.dart';
import '../../../ai_assistant/domain/entities/chat_message.dart';
import '../../domain/entities/smart_food_recommendation_entity.dart';
import '../../domain/entities/nutrition_gap_entity.dart';
import '../../domain/repositories/i_smart_eat_repository.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/network/network_status_provider.dart';

class SmartEatState {
  final String activeMealType;
  final AsyncValue<List<SmartFoodRecommendationEntity>> recommendations;
  final AsyncValue<NutritionGapEntity> gap;
  final Map<String, List<SmartFoodRecommendationEntity>> swaps;
  final Object? error;

  const SmartEatState({
    required this.activeMealType,
    required this.recommendations,
    required this.gap,
    this.swaps = const {},
    this.error,
  });

  SmartEatState copyWith({
    String? activeMealType,
    AsyncValue<List<SmartFoodRecommendationEntity>>? recommendations,
    AsyncValue<NutritionGapEntity>? gap,
    Map<String, List<SmartFoodRecommendationEntity>>? swaps,
    Object? error,
  }) {
    return SmartEatState(
      activeMealType: activeMealType ?? this.activeMealType,
      recommendations: recommendations ?? this.recommendations,
      gap: gap ?? this.gap,
      swaps: swaps ?? this.swaps,
      error: error,
    );
  }
}

class SmartEatController extends StateNotifier<SmartEatState> {
  final ISmartEatRepository _repository;
  final Ref _ref;

  SmartEatController(this._repository, this._ref)
      : super(SmartEatState(
          activeMealType: _detectMealType(),
          recommendations: const AsyncValue.loading(),
          gap: const AsyncValue.loading(),
        )) {
    // Listen to auth user state to load when authenticated
    _ref.listen(authStateStreamProvider, (prev, next) {
      final user = next.value;
      if (user != null) {
        refresh();
      } else {
        state = SmartEatState(
          activeMealType: _detectMealType(),
          recommendations: const AsyncValue.loading(),
          gap: const AsyncValue.loading(),
          swaps: const {},
        );
      }
    });

    // Listen to network status changes to auto-refresh when online returns
    _ref.listen(networkStatusProvider, (prev, next) {
      if (next.value == NetworkStatus.online && prev?.value != NetworkStatus.online) {
        refresh();
      }
    });

    // Listen to nutrition logs updates to automatically recalculate gaps & scores
    _ref.listen(nutritionStreamProvider, (prev, next) {
      if (next.value != null) {
        refresh();
      }
    });
  }

  static String _detectMealType() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 11) {
      return 'Breakfast';
    } else if (hour >= 11 && hour < 16) {
      return 'Lunch';
    } else if (hour >= 16 && hour < 22) {
      return 'Dinner';
    }
    return 'Snack';
  }

  Future<void> changeMealType(String mealType) async {
    state = state.copyWith(activeMealType: mealType);
    await refreshRecommendations();
  }

  Future<void> refresh() async {
    await Future.wait([
      refreshGap(),
      refreshRecommendations(),
    ]);
  }

  Future<void> refreshGap() async {
    final networkStatus = _ref.read(networkStatusProvider).value ?? NetworkStatus.online;
    if (networkStatus == NetworkStatus.offline) {
      state = state.copyWith(gap: AsyncValue.error(Exception('No internet connection'), StackTrace.current));
      return;
    }
    final user = _ref.read(authStateStreamProvider).value;
    if (user == null) return;

    final hasPreviousData = state.gap.hasValue;

    try {
      final gap = await _repository.getNutritionGap(
        uid: user.uid,
        today: DateTime.now(),
      );
      state = state.copyWith(gap: AsyncValue.data(gap));
    } catch (e, stack) {
      if (!hasPreviousData) {
        state = state.copyWith(gap: AsyncValue.error(e, stack));
      }
    }
  }

  Future<void> refreshRecommendations() async {
    final networkStatus = _ref.read(networkStatusProvider).value ?? NetworkStatus.online;
    if (networkStatus == NetworkStatus.offline) {
      final error = Exception('No internet connection');
      state = state.copyWith(
        recommendations: AsyncValue.error(error, StackTrace.current),
        error: error,
      );
      return;
    }
    final user = _ref.read(authStateStreamProvider).value;
    if (user == null) return;

    final hasPreviousData = state.recommendations.hasValue && state.recommendations.value!.isNotEmpty;

    try {
      if (!hasPreviousData) {
        state = state.copyWith(recommendations: const AsyncValue.loading(), error: null);
      } else {
        state = state.copyWith(error: null);
      }
      final chatExclusions = _getChatExclusions();

      final list = await _repository.getRecommendations(
        uid: user.uid,
        currentMealType: state.activeMealType,
        today: DateTime.now(),
        chatExclusions: chatExclusions,
      );
      state = state.copyWith(recommendations: AsyncValue.data(list), error: null);
    } catch (e, stack) {
      if (hasPreviousData) {
        state = state.copyWith(error: e);
      } else {
        state = state.copyWith(recommendations: AsyncValue.error(e, stack), error: e);
      }
    }
  }

  Future<void> loadSwaps(SmartFoodRecommendationEntity original) async {
    final user = _ref.read(authStateStreamProvider).value;
    if (user == null) return;

    try {
      final chatExclusions = _getChatExclusions();
      final swapList = await _repository.getSwaps(
        uid: user.uid,
        original: original,
        today: DateTime.now(),
        chatExclusions: chatExclusions,
      );

      final updatedSwaps = Map<String, List<SmartFoodRecommendationEntity>>.from(state.swaps);
      updatedSwaps[original.foodId] = swapList;
      state = state.copyWith(swaps: updatedSwaps);
    } catch (_) {}
  }

  List<String> _getChatExclusions() {
    final Set<String> exclusions = {};
    final triggers = ['no', 'avoid', 'cannot eat', 'don\'t want', 'rather than', 'exclude', 'without', 'cannot prefer'];
    final foodsList = ['chicken', 'eggs', 'yogurt', 'dal', 'paneer', 'oats', 'banana', 'rice', 'milk', 'vegetables'];

    final chatState = _ref.read(aiAssistantControllerProvider);
    for (final msg in chatState.messages) {
      if (msg.sender == MessageSender.user) {
        final tLower = msg.text.toLowerCase();
        for (final trigger in triggers) {
          if (tLower.contains(trigger)) {
            for (final food in foodsList) {
              if (tLower.contains(food)) {
                exclusions.add(food);
              }
            }
          }
        }
      }
    }
    return exclusions.toList();
  }

  void swapRecommendation(SmartFoodRecommendationEntity original, SmartFoodRecommendationEntity replacement) {
    final currentList = state.recommendations.value;
    if (currentList == null) return;

    final updated = currentList.map((rec) => rec.foodId == original.foodId ? replacement : rec).toList();
    state = state.copyWith(recommendations: AsyncValue.data(updated));
  }
}
