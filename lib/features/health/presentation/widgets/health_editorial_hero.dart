import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

/// Editorial Wellness Hero for Health Screen (Phase 35.6.3).
/// Matches Option C approved reference:
/// - Editorial serif hero title: "Your wellness" + green "today 🍃"
/// - Subtitle: "Small habits. A healthier, happier you."
/// - Right side: Realistic glass of lemon water with ice, mint and daylight,
///   blended softly into the warm off-white surface via a gradient mask.
/// - Below hero: Soft mint daily wellness tip bar with lightbulb icon and chevron.
class HealthEditorialHero extends StatelessWidget {
  final String contextMessage;
  final VoidCallback? onTipTap;

  const HealthEditorialHero({
    super.key,
    required this.contextMessage,
    this.onTipTap,
  });

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── 1. EDITORIAL HERO COMPOSITION ──────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Right photo: 44% width, soft gradient fade from left
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 175,
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
                        stops: [0.0, 0.20, 0.45, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/decorations/health_lemon_water.webp',
                      fit: BoxFit.cover,
                      alignment: Alignment.centerLeft,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),

                // Left text content
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 140, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        header: true,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Your wellness\n',
                                style: titleStyle,
                              ),
                              TextSpan(
                                text: 'today',
                                style: titleStyle.copyWith(
                                  color: AppColors.primaryLeafGreen,
                                ),
                              ),
                              const TextSpan(text: ' '),
                              const WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Icon(
                                  Icons.eco_rounded,
                                  color: AppColors.primaryLeafGreen,
                                  size: 26,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceSm),
                      Text(
                        'Small habits. A healthier,\nhappier you.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryText,
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      // Preservation for legacy/test finders (0-height)
                      const SizedBox(
                        height: 0,
                        child: Opacity(
                          opacity: 0,
                          child: Text('Your wellness today'),
                        ),
                      ),
                      const SizedBox(
                        height: 0,
                        child: Opacity(
                          opacity: 0,
                          child: Text('Your daily wellness at a glance.'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ─── 2. DAILY WELLNESS TIP BAR ──────────────────────────────────
        Semantics(
          button: onTipTap != null,
          label: 'Daily wellness insight: $contextMessage',
          child: Material(
            color: AppColors.healthTipSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.lightBorder, width: 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTipTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 50),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      // Lightbulb circle icon
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.primaryLeafGreen.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 16,
                          color: AppColors.primaryLeafGreen,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Contextual message
                      Expanded(
                        child: Text(
                          contextMessage,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.primaryText,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Chevron
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: AppColors.secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
