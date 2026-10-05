import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

/// Deep Exploration Navigation Section for Progress Screen:
/// Fast access to Health Analytics, Weekly Report, and Smart Health Insights.
class ProgressDeepExploration extends StatelessWidget {
  const ProgressDeepExploration({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Deep Exploration',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.primaryText,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Detailed analytics, reports, and insights.',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 12),
        _buildNavTile(
          context: context,
          isDark: isDark,
          title: 'Health Analytics',
          subtitle: 'Interactive charts and multi-metric trend analysis',
          icon: Icons.bar_chart_rounded,
          iconColor: AppColors.primaryLeafGreen,
          iconBg: const Color(0xFFEAF8F0),
          onTap: () => context.go('/progress/analytics'),
        ),
        const SizedBox(height: 8),
        _buildNavTile(
          context: context,
          isDark: isDark,
          title: 'Weekly Health Report',
          subtitle: 'Comprehensive 7-day review and performance',
          icon: Icons.summarize_outlined,
          iconColor: const Color(0xFFFF8A34),
          iconBg: const Color(0xFFFFF3EB),
          onTap: () => context.go('/progress/weekly-report'),
        ),
        const SizedBox(height: 8),
        _buildNavTile(
          context: context,
          isDark: isDark,
          title: 'Smart Health Insights',
          subtitle: 'AI priority alerts, daily focus, and actions',
          icon: Icons.lightbulb_outline_rounded,
          iconColor: const Color(0xFF3B82F6),
          iconBg: const Color(0xFFEFF6FF),
          onTap: () => context.go('/progress/insights'),
        ),
      ],
    );
  }

  Widget _buildNavTile({
    required BuildContext context,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppColors.primaryText,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          size: 20,
          color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
        ),
      ),
    );
  }
}
