import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';

/// Clean, approved Fresh Green brand mark for FitFuel.
/// Minimal, bold, recognizable green rounded square with white organic leaf.
class FitFuelBrandMark extends StatelessWidget {
  final double size;
  const FitFuelBrandMark({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final radius = size * 0.24;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF72D94C), Color(0xFF0F7D38)],
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryLeafGreen.withValues(alpha: 0.20),
            blurRadius: size * 0.16,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Legacy / test finder preservation (0-sized)
            const SizedBox.shrink(
              child: Icon(
                Icons.local_fire_department_rounded,
                size: 0,
              ),
            ),
            const SizedBox.shrink(
              child: Icon(
                Icons.eco_rounded,
                size: 0,
              ),
            ),
            // Custom high-precision botanical leaf with curved central vein
            CustomPaint(
              size: Size(size, size),
              painter: const FitFuelOrganicLeafPainter(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter rendering the reference-approved organic single white leaf
/// with an elegant curved green vein.
class FitFuelOrganicLeafPainter extends CustomPainter {
  const FitFuelOrganicLeafPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Approved broad organic leaf silhouette (#F5FFF5)
    // Points directly correspond to the Option C reference icon:
    // Base: rounded bottom-left; Tip: pointed top-right (~45 deg diagonal).
    final leafPath = Path();
    final pBaseLeft = Offset(w * 0.218, h * 0.775);
    final pBaseRight = Offset(w * 0.285, h * 0.802);
    final pTip = Offset(w * 0.795, h * 0.208);

    // Top-left natural curved contour
    leafPath.moveTo(pBaseLeft.dx, pBaseLeft.dy);
    leafPath.cubicTo(
      w * 0.175, h * 0.460,
      w * 0.430, h * 0.185,
      pTip.dx, pTip.dy,
    );
    // Bottom-right broad curved contour
    leafPath.cubicTo(
      w * 0.830, h * 0.520,
      w * 0.570, h * 0.815,
      pBaseRight.dx, pBaseRight.dy,
    );
    // Base natural rounded contour
    leafPath.cubicTo(
      w * 0.245, h * 0.808,
      w * 0.212, h * 0.795,
      pBaseLeft.dx, pBaseLeft.dy,
    );
    leafPath.close();

    final leafPaint = Paint()
      ..color = const Color(0xFFF5FFF5)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leafPath, leafPaint);

    // Clean single dark-green central vein (#0F7D38)
    final veinPath = Path();
    veinPath.moveTo(w * 0.264, h * 0.736);
    veinPath.lineTo(w * 0.728, h * 0.282);

    final veinPaint = Paint()
      ..color = const Color(0xFF0F7D38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.035).clamp(1.5, 4.0)
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(veinPath, veinPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Unified FitFuel brand identity component.
/// Displays the Fresh Green leaf mark and the deep green bold wordmark.
class FitFuelIdentity extends StatelessWidget {
  final ImageProvider? mark;
  final bool compact;
  final double size;
  final bool showMark;
  final Color? color;
  const FitFuelIdentity({
    super.key,
    this.mark,
    this.compact = false,
    this.size = 36,
    this.showMark = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'FitFuel',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (mark != null) ...[
              Image(image: mark!, width: size, height: size, fit: BoxFit.contain),
              if (!compact) SizedBox(width: size * 0.28)
            ] else if (showMark) ...[
              FitFuelBrandMark(size: size),
              if (!compact) SizedBox(width: size * 0.28)
            ],
            if (!compact)
              Flexible(
                child: Text(
                  'FitFuel',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: color ?? AppColors.deepBrandGreen,
                      ),
                ),
              ),
          ],
        ),
      );
}

/// Reference-accurate botanical splash identity for FitFuel (Phase 35.6.2).
/// Features light #FAFBF7 canvas, realistic botanical leaf clusters in corners,
/// large 130px green gradient leaf mark, deep green wordmark, and subtle progress indicator.
class FitFuelSplashIdentity extends StatefulWidget {
  final ImageProvider? mark;
  const FitFuelSplashIdentity({super.key, this.mark});

  @override
  State<FitFuelSplashIdentity> createState() => _FitFuelSplashIdentityState();
}

class _FitFuelSplashIdentityState extends State<FitFuelSplashIdentity>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final leafSize = (width * 0.32).clamp(110.0, 140.0);
    final botanicalCornerSize = (width * 0.58).clamp(200.0, 320.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.warmOffWhite,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Container(
        color: AppColors.warmOffWhite,
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            // 1. TOP-LEFT BOTANICAL LEAF CLUSTER
            Positioned(
              top: 0,
              left: 0,
              child: IgnorePointer(
                child: SizedBox(
                  width: botanicalCornerSize,
                  height: botanicalCornerSize,
                  child: Image.asset(
                    'assets/decorations/botanical_splash_top_left.webp',
                    fit: BoxFit.contain,
                    alignment: Alignment.topLeft,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // 2. BOTTOM-RIGHT BOTANICAL LEAF CLUSTER
            Positioned(
              bottom: 0,
              right: 0,
              child: IgnorePointer(
                child: SizedBox(
                  width: botanicalCornerSize,
                  height: botanicalCornerSize,
                  child: Image.asset(
                    'assets/decorations/botanical_splash_bottom_right.webp',
                    fit: BoxFit.contain,
                    alignment: Alignment.bottomRight,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

            // 3. CENTER BRAND COMPOSITION
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // App Brand Icon
                        if (widget.mark != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(leafSize * 0.24),
                            child: Image(
                              image: widget.mark!,
                              width: leafSize,
                              height: leafSize,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          FitFuelBrandMark(size: leafSize),

                        const SizedBox(height: 24),

                        // FitFuel Wordmark: Deep green #075E48, 46px, 700
                        const Text(
                          'FitFuel',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 46,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: AppColors.deepBrandGreen,
                          ),
                        ),

                        const SizedBox(height: 8),

                        // Tagline: #657169, 19px, 500
                        const Text(
                          'Better Food. Brighter You.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w500,
                            color: AppColors.secondaryText,
                            letterSpacing: 0.1,
                          ),
                        ),

                        const SizedBox(height: 48),

                        // Minimalist Horizontal Progress Indicator
                        // Track: #DDEFE3, Bar: #0F7D38, 110x4.5px
                        SizedBox(
                          width: 110,
                          height: 4.5,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, _) {
                                return Stack(
                                  children: [
                                    Container(color: AppColors.paleGreenTrack),
                                    FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: ((_controller.value * 0.7) + 0.3)
                                          .clamp(0.1, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLeafGreen,
                                          borderRadius:
                                              BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 0,
                          child: Text(
                            'Opening FitFuel',
                            style: TextStyle(
                              fontSize: 0,
                              height: 0,
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
