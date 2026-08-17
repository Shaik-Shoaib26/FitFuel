import 'package:flutter/material.dart';
import '../../domain/entities/health_insight_entity.dart';

class InsightCard extends StatelessWidget {
  final HealthInsightEntity insight;

  const InsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon = Icons.lightbulb_outline;
    Color color = Colors.amber;

    switch (insight.category) {
      case InsightCategory.hydration:
        icon = Icons.local_drink;
        color = Colors.blue;
        break;
      case InsightCategory.nutrition:
        icon = Icons.restaurant;
        color = Colors.green;
        break;
      case InsightCategory.exercise:
        icon = Icons.fitness_center;
        color = Colors.orange;
        break;
      case InsightCategory.habits:
        icon = Icons.done_all;
        color = Colors.teal;
        break;
      case InsightCategory.wellness:
        icon = Icons.favorite;
        color = Colors.red;
        break;
      case InsightCategory.weight:
        icon = Icons.monitor_weight;
        color = Colors.purple;
        break;
      case InsightCategory.positive:
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      default:
        break;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? Colors.grey[850]! : Colors.grey[200]!,
        ),
      ),
      color: isDark ? Colors.grey[900]?.withValues(alpha: 0.5) : Colors.grey[50]?.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    insight.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    insight.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    insight.recommendation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
