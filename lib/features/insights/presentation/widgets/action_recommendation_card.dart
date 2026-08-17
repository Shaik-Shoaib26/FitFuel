import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/action_recommendation_entity.dart';
import '../../domain/entities/health_insight_entity.dart';

class ActionRecommendationCard extends StatelessWidget {
  final ActionRecommendationEntity recommendation;

  const ActionRecommendationCard({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color color = Colors.amber;

    switch (recommendation.actionType) {
      case InsightActionType.logWater:
        color = Colors.blue;
        break;
      case InsightActionType.findProteinFoods:
        color = Colors.green;
        break;
      case InsightActionType.viewMealPlan:
        color = Colors.teal;
        break;
      case InsightActionType.openGrocery:
        color = Colors.indigo;
        break;
      case InsightActionType.viewProgress:
        color = Colors.purple;
        break;
      case InsightActionType.openWeeklyReport:
        color = Colors.red;
        break;
      case InsightActionType.openDailyRoutine:
        color = Colors.deepOrange;
        break;
      case InsightActionType.openAnalytics:
        color = Colors.blueGrey;
        break;
      default:
        break;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
        ),
      ),
      color: isDark ? Colors.grey[900]?.withValues(alpha: 0.3) : Colors.grey[50]?.withValues(alpha: 0.3),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          recommendation.title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          recommendation.description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () {
            context.push(recommendation.route);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Go'),
        ),
      ),
    );
  }
}
