import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

/// Editorial Nutrition Hero for Nutrition Screen (Phase 35.6.4).
/// Matches Option B approved reference:
/// - Editorial serif hero title:
///   "Fuel a" (dark text)
///   "healthier you" (primary leaf green #0F7D38)
/// - Subtitle: "Nutritious choices.\nMore energy. Brighter days."
/// - Right side: Realistic healthy meal bowl photography with soft fade
///   merging seamlessly into the warm off-white surface without hard borders.
class NutritionEditorialHero extends StatelessWidget {
  const NutritionEditorialHero({super.key});

  TextStyle _editorialTitle(BuildContext context) {
    try {
      return GoogleFonts.playfairDisplay(
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryText,
      );
    } catch (_) {
      return const TextStyle(
        fontFamily: 'serif',
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryText,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleStyle = _editorialTitle(context);
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // On very compact mobile (<340px) or extreme text scale, adjust layout
        final isCompact = width < 330;

        return ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                // ─── RIGHT FOOD BOWL PHOTO ──────────────────────────────────
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: isCompact ? -20 : -10,
                  width: width * 0.48,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Color(0x33000000),
                          Color(0xBB000000),
                          Colors.black,
                        ],
                        stops: [0.0, 0.18, 0.42, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/decorations/nutrition_hero_bowl.webp',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // ─── LEFT EDITORIAL TEXT CONTENT ─────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    4,
                    10,
                    width * 0.42,
                    14,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        label: 'Fuel a healthier you',
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Fuel a\n',
                                style: titleStyle.copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.primaryText,
                                ),
                              ),
                              TextSpan(
                                text: 'healthier you',
                                style: titleStyle.copyWith(
                                  color: AppColors.primaryLeafGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Nutritious choices.\nMore energy. Brighter days.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
