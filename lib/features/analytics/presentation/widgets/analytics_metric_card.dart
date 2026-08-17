import 'package:flutter/material.dart';

class AnalyticsMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final String trend; // 'Improving', 'Stable', 'Declining', 'Insufficient'
  final List<Widget> details;
  final IconData icon;
  final Color color;

  const AnalyticsMetricCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.trend,
    required this.details,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  radius: 20,
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                _buildTrendBadge(context),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            ...details,
          ],
        ),
      ),
    );
  }

  Widget _buildTrendBadge(BuildContext context) {
    Color badgeColor = Colors.grey;
    IconData trendIcon = Icons.remove;
    String text = trend;

    switch (trend) {
      case 'Improving':
        badgeColor = Colors.green;
        trendIcon = Icons.trending_up;
        break;
      case 'Declining':
        badgeColor = Colors.red;
        trendIcon = Icons.trending_down;
        break;
      case 'Stable':
        badgeColor = Colors.blue;
        trendIcon = Icons.trending_flat;
        break;
      case 'Insufficient':
      default:
        badgeColor = Colors.grey;
        trendIcon = Icons.info_outline;
        text = 'No Data';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(trendIcon, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
