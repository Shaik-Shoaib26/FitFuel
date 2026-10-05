import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/entities/progress_summary_entity.dart';

/// Milestones and Achievements Section matching Option A:
/// Displays real unlocked achievements and progress towards upcoming milestones.
class ProgressMilestonesSection extends StatelessWidget {
  final List<MilestoneEntity> milestones;

  const ProgressMilestonesSection({
    super.key,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context) {
    if (milestones.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Show unlocked first, then upcoming
    final sorted = List<MilestoneEntity>.from(milestones)
      ..sort((a, b) {
        if (a.isUnlocked && !b.isUnlocked) return -1;
        if (!a.isUnlocked && b.isUnlocked) return 1;
        return b.progressPercent.compareTo(a.progressPercent);
      });

    // Display top 4 most relevant milestones for modern & minimal density
    final displayed = sorted.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Milestones & Achievements',
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
            Text(
              '${milestones.where((m) => m.isUnlocked).length}/${milestones.length} Unlocked',
              style: TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...displayed.map((m) => _buildMilestoneTile(m, isDark)),
      ],
    );
  }

  Widget _buildMilestoneTile(MilestoneEntity milestone, bool isDark) {
    final isUnlocked = milestone.isUnlocked;

    final badgeColor = isUnlocked
        ? const Color(0xFFF59E0B) // Amber gold
        : (isDark ? AppColors.darkBorder : const Color(0xFFCBD5E1));

    final badgeBg = isUnlocked
        ? const Color(0xFFFEF3C7)
        : (isDark ? AppColors.darkBgSurface : const Color(0xFFF1F5F9));

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgSurface : AppColors.pureWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: badgeBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked ? Icons.emoji_events_rounded : Icons.lock_outline_rounded,
              color: badgeColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        milestone.title,
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.primaryText,
                        ),
                      ),
                    ),
                    Text(
                      milestone.progressText,
                      style: TextStyle(
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isUnlocked
                            ? AppColors.primaryLeafGreen
                            : (isDark ? AppColors.darkTextSecondary : AppColors.secondaryText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  milestone.description,
                  style: TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.secondaryText,
                  ),
                ),
                if (!isUnlocked) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: milestone.progressPercent.clamp(0.0, 1.0),
                      backgroundColor: isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryLeafGreen),
                      minHeight: 4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
