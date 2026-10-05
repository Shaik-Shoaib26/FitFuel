import 'package:flutter/material.dart';
import 'package:fitfuel/core/constants/app_colors.dart';
import 'package:fitfuel/core/constants/app_constants.dart';
import 'package:fitfuel/features/food_scan/domain/entities/detected_food_candidate.dart';

class ScanConfidenceChip extends StatelessWidget {
  final ScanConfidenceLevel level;
  final double? score;

  const ScanConfidenceChip({
    super.key,
    required this.level,
    this.score,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    switch (level) {
      case ScanConfidenceLevel.high:
        bg = AppColors.softSage;
        fg = AppColors.primaryLeafGreen;
        label = 'High Match';
        icon = Icons.verified_rounded;
        break;
      case ScanConfidenceLevel.medium:
        bg = const Color(0xFFFEF3C7);
        fg = AppColors.stateWarning;
        label = 'Needs Confirmation';
        icon = Icons.help_outline_rounded;
        break;
      case ScanConfidenceLevel.low:
        bg = const Color(0xFFFEE2E2);
        fg = AppColors.stateError;
        label = 'Low Confidence';
        icon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.radiusControl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
