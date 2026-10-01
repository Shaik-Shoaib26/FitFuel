import '../enums/recommendation_priority.dart';
import 'recommendation_reason_entity.dart';

class SmartFoodRecommendationEntity {
  final String id;
  final String foodId;
  final String foodName;
  final String imageUrl;
  final String category;
  final double servingSize;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final int matchScore;
  final RecommendationPriority priority;
  final List<RecommendationReasonEntity> reasons;
  final List<String> tags;
  final bool pantryAvailable;
  final bool groceryAvailable;
  final bool recentlyConsumed;
  final bool isFavorite;
  final int estimatedPreparationMinutes;

  const SmartFoodRecommendationEntity({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.imageUrl,
    required this.category,
    required this.servingSize,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.matchScore,
    required this.priority,
    required this.reasons,
    required this.tags,
    required this.pantryAvailable,
    required this.groceryAvailable,
    required this.recentlyConsumed,
    required this.isFavorite,
    required this.estimatedPreparationMinutes,
  });

  SmartFoodRecommendationEntity copyWith({
    String? id,
    String? foodId,
    String? foodName,
    String? imageUrl,
    String? category,
    double? servingSize,
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    int? matchScore,
    RecommendationPriority? priority,
    List<RecommendationReasonEntity>? reasons,
    List<String>? tags,
    bool? pantryAvailable,
    bool? groceryAvailable,
    bool? recentlyConsumed,
    bool? isFavorite,
    int? estimatedPreparationMinutes,
  }) {
    return SmartFoodRecommendationEntity(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      servingSize: servingSize ?? this.servingSize,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      matchScore: matchScore ?? this.matchScore,
      priority: priority ?? this.priority,
      reasons: reasons ?? this.reasons,
      tags: tags ?? this.tags,
      pantryAvailable: pantryAvailable ?? this.pantryAvailable,
      groceryAvailable: groceryAvailable ?? this.groceryAvailable,
      recentlyConsumed: recentlyConsumed ?? this.recentlyConsumed,
      isFavorite: isFavorite ?? this.isFavorite,
      estimatedPreparationMinutes:
          estimatedPreparationMinutes ?? this.estimatedPreparationMinutes,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmartFoodRecommendationEntity &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          foodId == other.foodId &&
          foodName == other.foodName &&
          imageUrl == other.imageUrl &&
          category == other.category &&
          servingSize == other.servingSize &&
          calories == other.calories &&
          protein == other.protein &&
          carbs == other.carbs &&
          fat == other.fat &&
          fiber == other.fiber &&
          matchScore == other.matchScore &&
          priority == other.priority &&
          pantryAvailable == other.pantryAvailable &&
          groceryAvailable == other.groceryAvailable &&
          recentlyConsumed == other.recentlyConsumed &&
          isFavorite == other.isFavorite &&
          estimatedPreparationMinutes == other.estimatedPreparationMinutes;

  @override
  int get hashCode =>
      id.hashCode ^
      foodId.hashCode ^
      foodName.hashCode ^
      imageUrl.hashCode ^
      category.hashCode ^
      servingSize.hashCode ^
      calories.hashCode ^
      protein.hashCode ^
      carbs.hashCode ^
      fat.hashCode ^
      fiber.hashCode ^
      matchScore.hashCode ^
      priority.hashCode ^
      pantryAvailable.hashCode ^
      groceryAvailable.hashCode ^
      recentlyConsumed.hashCode ^
      isFavorite.hashCode ^
      estimatedPreparationMinutes.hashCode;
}
