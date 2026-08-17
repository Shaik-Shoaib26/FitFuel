import '../entities/action_recommendation_entity.dart';
import '../entities/health_insight_entity.dart';

class ActionRecommendationEngine {
  static ActionRecommendationEntity generate(InsightActionType type, InsightPriority priority) {
    switch (type) {
      case InsightActionType.logWater:
        return ActionRecommendationEntity(
          id: 'action_log_water',
          title: 'Log Water',
          description: 'Record your water intake to stay hydrated.',
          actionType: type,
          route: '/health',
          priority: priority,
        );
      case InsightActionType.viewMealPlan:
        return ActionRecommendationEntity(
          id: 'action_view_meal_plan',
          title: 'View Meal Plan',
          description: 'Check your personalized adaptive meal plan.',
          actionType: type,
          route: '/meal-planner',
          priority: priority,
        );
      case InsightActionType.findProteinFoods:
        return ActionRecommendationEntity(
          id: 'action_find_protein_foods',
          title: 'Find Protein Foods',
          description: 'Browse the food database for high-protein options.',
          actionType: type,
          route: '/food-search',
          priority: priority,
        );
      case InsightActionType.openGrocery:
        return ActionRecommendationEntity(
          id: 'action_open_grocery',
          title: 'Open Grocery',
          description: 'View list of items to buy for your meals.',
          actionType: type,
          route: '/grocery',
          priority: priority,
        );
      case InsightActionType.viewProgress:
        return ActionRecommendationEntity(
          id: 'action_view_progress',
          title: 'View Progress',
          description: 'Check your weight progress and logging streaks.',
          actionType: type,
          route: '/progress',
          priority: priority,
        );
      case InsightActionType.openWeeklyReport:
        return ActionRecommendationEntity(
          id: 'action_open_weekly_report',
          title: 'Open Weekly Report',
          description: 'Review your complete weekly health scores.',
          actionType: type,
          route: '/weekly-report',
          priority: priority,
        );
      case InsightActionType.openDailyRoutine:
        return ActionRecommendationEntity(
          id: 'action_open_daily_routine',
          title: 'Open Daily Routine',
          description: 'Check and complete your active routine checklist.',
          actionType: type,
          route: '/daily-routine',
          priority: priority,
        );
      case InsightActionType.openAnalytics:
        return ActionRecommendationEntity(
          id: 'action_open_analytics',
          title: 'Open Analytics',
          description: 'Explore trends across wellness, weight, and workouts.',
          actionType: type,
          route: '/analytics',
          priority: priority,
        );
      case InsightActionType.none:
        return ActionRecommendationEntity(
          id: 'action_none',
          title: 'Stay Consistent',
          description: 'Maintain your momentum to reach your goals.',
          actionType: InsightActionType.none,
          route: '/dashboard',
          priority: priority,
        );
    }
  }
}
