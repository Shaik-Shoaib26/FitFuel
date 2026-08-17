import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/daily_focus_entity.dart';
import '../../domain/entities/health_insight_entity.dart';

class DailyFocusCard extends StatelessWidget {
  final DailyFocusEntity dailyFocus;

  const DailyFocusCard({
    super.key,
    required this.dailyFocus,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    IconData icon = Icons.star;
    Color color = Colors.amber;

    switch (dailyFocus.category) {
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
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      default:
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  "TODAY'S FOCUS",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              dailyFocus.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dailyFocus.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.4,
              ),
            ),
            if (dailyFocus.recommendedActions.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...dailyFocus.recommendedActions.map((action) {
                return ElevatedButton.icon(
                  onPressed: () {
                    context.push(action.route);
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(action.title),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
