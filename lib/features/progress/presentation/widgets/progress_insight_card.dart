import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../insights/domain/entities/health_insight_entity.dart';
import '../../domain/entities/progress_summary_entity.dart';

/// Key Insights Card matching Option A:
/// - Header: "Key Insights" + "See all >"
/// - Soft mint container with lightbulb icon, real concise insight text, and chevron
class ProgressInsightCard extends StatelessWidget {
  final ProgressSummaryEntity summary;
  final List<HealthInsightEntity>? insights;

  const ProgressInsightCard({
    super.key,
    required this.summary,
    this.insights,
  });

  String _resolveInsightMessage() {
    // 1. If we have active loaded insights, pick the highest priority one with a friendly tone
    if (insights != null && insights!.isNotEmpty) {
      final top = insights!.first;
      if (top.description.isNotEmpty) {
        return top.description;
      } else if (top.title.isNotEmpty) {
        return top.title;
      }
    }

    // 2. Fallbacks based on live calculated summary
    if (summary.currentStreak >= 2) {
      return "You've been consistent with your nutrition for ${summary.currentStreak} days! Keep it up.";
    }
    if (summary.waterConsistencyPercent >= 75) {
      return "Your hydration is right on track! You're consistently meeting your daily water target.";
    }
    if (summary.exerciseActiveDays >= 3) {
      return 'Strong momentum! You completed ${summary.exerciseTotalMinutes} active minutes over ${summary.exerciseActiveDays} days.';
    }
    if (summary.habitsAvgCompletionRate >= 70) {
      return "Great habit adherence! You're completing ${summary.habitsAvgCompletionRate.round()}% of your daily habits.";
    }

    return 'Track your meals, hydration, and workouts to unlock personalized AI health insights.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final message = _resolveInsightMessage();

    final cardBg = isDark
        ? AppColors.darkBgSurface
        : const Color(0xFFF0F8F3);
    final borderColor = isDark
        ? AppColors.darkBorder
        : const Color(0xFFDCEDE2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Key Insights',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.primaryText,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => context.go('/progress/insights'),
              borderRadius: BorderRadius.circular(8),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryLeafGreen,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.primaryLeafGreen,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Insight Tile
        InkWell(
          onTap: () => context.go('/progress/insights'),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                // Lightbulb Icon in circular badge
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primaryLeafGreen.withValues(alpha: 0.2)
                        : const Color(0xFFD8EFE0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: AppColors.primaryLeafGreen,
                  ),
                ),
                const SizedBox(width: 14),

                // Concise Insight Text
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'PlusJakartaSans',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : AppColors.primaryText,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Chevron
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.secondaryText,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
