import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/sign_up_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';

abstract class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String onboarding = '/onboarding';
  static const String dashboard = '/dashboard';
  static const String scanner = '/scanner';
  static const String scanResult = '/scan-result';
  static const String history = '/history';
  static const String progress = '/progress';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String premium = '/premium';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authStateAsync = ref.watch(authStateStreamProvider);

  return GoRouter(
    initialLocation: AppRoutes.login,
    redirect: (BuildContext context, GoRouterState state) {
      final isLoading = authStateAsync.isLoading;
      final user = authStateAsync.value;
      final isAuthenticated = user != null;
      final location = state.matchedLocation;

      // Unauthenticated routes list
      final isAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.forgotPassword ||
          location == AppRoutes.welcome ||
          location == AppRoutes.splash;

      if (isLoading) {
        return null; // Stay on current splash/loading route while checking Firebase session
      }

      // If user is NOT authenticated and trying to access a protected route -> redirect to Login
      if (!isAuthenticated && !isAuthRoute) {
        return AppRoutes.login;
      }

      // If user IS authenticated and trying to access auth screens -> redirect to Dashboard
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.dashboard;
      }

      return null; // No redirection required
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const SignUpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
});
