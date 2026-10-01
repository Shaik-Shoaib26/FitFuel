import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitfuel/core/widgets/food_image_resolver.dart';
import 'package:fitfuel/core/widgets/fitfuel_food_photo.dart';
import 'package:fitfuel/core/widgets/fitfuel_identity.dart';
import 'package:fitfuel/features/authentication/presentation/controllers/auth_controller.dart';
import 'package:fitfuel/features/authentication/domain/repositories/i_auth_repository.dart';
import 'package:fitfuel/features/authentication/presentation/screens/login_screen.dart';
import 'package:fitfuel/features/authentication/presentation/screens/sign_up_screen.dart';
import 'package:fitfuel/features/authentication/presentation/screens/forgot_password_screen.dart';

class _FakeAuthRepository extends Fake implements IAuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

Widget _createTestWidget(Widget child, {double width = 390, double textScale = 1.0, bool isDark = false}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(_FakeAuthRepository())),
    ],
    child: MaterialApp(
      theme: isDark ? ThemeData.dark() : ThemeData.light(),
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ),
  );
}

void main() {
  group('Phase 35.3I — Food Image Truthfulness & Fallback Tests', () {
    test('Mismatched Indian breakfast foods do not use western toast photo', () {
      const toastUrlPart = 'photo-1533089860892-a7c6f0a88666';

      // Masala Dosa should NOT resolve to toast
      final masalaDosa = FoodImageResolver.resolve('predefined_masala_dosa');
      expect(masalaDosa.contains(toastUrlPart), isFalse);
      expect(masalaDosa.contains('photo-1668236543090-82eba5ee5976'), isTrue);

      // Rava Dosa should NOT resolve to toast
      final ravaDosa = FoodImageResolver.resolve('predefined_rava_dosa');
      expect(ravaDosa.contains(toastUrlPart), isFalse);

      // Medu Vada should use branded fallback (empty string)
      final meduVada = FoodImageResolver.resolve('predefined_medu_vada');
      expect(meduVada, '');

      // Pongal should use branded fallback
      final pongal = FoodImageResolver.resolve('predefined_pongal');
      expect(pongal, '');

      // Idli should use branded fallback
      final idli = FoodImageResolver.resolve('predefined_idli');
      expect(idli, '');

      // Sambar and Rasam should use branded fallback
      final sambar = FoodImageResolver.resolve('predefined_sambar');
      expect(sambar, '');
      final rasam = FoodImageResolver.resolve('predefined_rasam');
      expect(rasam, '');
    });

    test('Paneer Paratha does not use yogurt bowl photo', () {
      const yogurtUrlPart = 'photo-1488477181946-6428a0291777';
      final paneerParatha = FoodImageResolver.resolve('predefined_paneer_paratha');
      expect(paneerParatha.contains(yogurtUrlPart), isFalse);
      expect(paneerParatha.contains('photo-1626074353765-517a681e40be'), isTrue);
    });

    testWidgets('FitFuelFoodPhoto renders branded fallback cleanly on empty or missing source', (tester) async {
      await tester.pumpWidget(_createTestWidget(
        const FitFuelFoodPhoto(
          source: '',
          description: 'Idli Sambar',
          width: 120,
          height: 120,
        ),
      ));
      await tester.pump();

      expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
      expect(find.text('FitFuel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 35.3I — Branding Identity Tests', () {
    testWidgets('FitFuelBrandMark renders cleanly', (tester) async {
      await tester.pumpWidget(_createTestWidget(
        const FitFuelBrandMark(size: 48),
      ));
      await tester.pump();

      expect(find.byType(FitFuelBrandMark), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FitFuelIdentity renders brand mark and text', (tester) async {
      await tester.pumpWidget(_createTestWidget(
        const FitFuelIdentity(),
      ));
      await tester.pump();

      expect(find.text('FitFuel'), findsOneWidget);
      expect(find.byType(FitFuelBrandMark), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FitFuelSplashIdentity renders cleanly', (tester) async {
      await tester.pumpWidget(_createTestWidget(
        const FitFuelSplashIdentity(),
      ));
      await tester.pump();

      expect(find.text('FitFuel'), findsOneWidget);
      expect(find.text('Opening FitFuel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Phase 35.3I — Auth Visual & Responsive Tests', () {
    for (final width in [320.0, 390.0, 768.0, 1440.0]) {
      testWidgets('LoginScreen renders at $width px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_createTestWidget(
          const LoginScreen(),
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Welcome Back'), findsOneWidget);
        expect(find.text('Sign In'), findsOneWidget);
        expect(find.byType(FitFuelBrandMark), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('SignUpScreen renders at $width px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_createTestWidget(
          const SignUpScreen(),
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Join FitFuel'), findsOneWidget);
        expect(find.text('Create Account'), findsWidgets);
        expect(find.byType(FitFuelBrandMark), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('ForgotPasswordScreen renders at $width px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(_createTestWidget(
          const ForgotPasswordScreen(),
          width: width,
        ));
        await tester.pumpAndSettle();

        expect(find.text('Reset Your Password'), findsOneWidget);
        expect(find.text('Send Reset Link'), findsOneWidget);
        expect(find.byType(FitFuelBrandMark), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('LoginScreen handles 1.4x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_createTestWidget(
        const LoginScreen(),
        width: 390,
        textScale: 1.4,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Welcome Back'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('SignUpScreen handles 1.4x text scale without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_createTestWidget(
        const SignUpScreen(),
        width: 390,
        textScale: 1.4,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Join FitFuel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
