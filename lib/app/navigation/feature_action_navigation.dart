import '../../features/reminders/domain/entities/reminder_entity.dart';
import '../../features/insights/domain/entities/action_recommendation_entity.dart';
import '../../features/insights/domain/entities/health_insight_entity.dart';

const legacyRouteMap = <String, String>{
  '/dashboard': '/home',
  '/history': '/progress/analytics/nutrition',
  '/meal-planner': '/plan/meals',
  '/smart-eat': '/plan/smart-eat',
  '/grocery': '/plan/grocery',
  '/pantry': '/plan/grocery/pantry',
  '/daily-routine': '/plan/routine',
  '/reminders': '/settings/reminders',
  '/analytics': '/progress/analytics',
  '/weekly-report': '/progress/weekly-report',
  '/insights': '/progress/insights',
  '/health-insights': '/progress/insights/health',
  '/food-search': '/nutrition/search',
  '/ai-assistant': '/ai',
};

String canonicalLocation(String location) {
  final uri = Uri.tryParse(location);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !uri.path.startsWith('/')) {
    return '/home';
  }
  return uri.replace(path: legacyRouteMap[uri.path] ?? uri.path).toString();
}

String reminderLocation(ReminderEntity item) => switch (item.type) {
      ReminderType.hydration => '/health?section=hydration&action=add',
      ReminderType.exercise => '/health?section=exercise&action=add',
      ReminderType.habit => '/health?section=habits',
      ReminderType.weight => '/health/weight',
      ReminderType.nutritionLogging => '/nutrition/log',
      _ => canonicalLocation(item.actionRoute),
    };

String insightLocation(ActionRecommendationEntity action) =>
    switch (action.actionType) {
      InsightActionType.logWater => '/health?section=hydration&action=add',
      _ => canonicalLocation(action.route),
    };
