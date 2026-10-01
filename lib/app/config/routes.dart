import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/widgets/fitfuel_identity.dart';
import '../../features/authentication/presentation/providers/auth_providers.dart';
import '../../features/authentication/presentation/screens/forgot_password_screen.dart';
import '../../features/authentication/presentation/screens/login_screen.dart';
import '../../features/authentication/presentation/screens/sign_up_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/nutrition/presentation/screens/history_screen.dart';
import '../../features/meal_planner/presentation/screens/meal_planner_screen.dart';
import '../../features/insights/presentation/screens/insights_screen.dart';
import '../../features/ai_assistant/presentation/screens/ai_assistant_screen.dart';
import '../../features/health/presentation/screens/health_screen.dart';
import '../../features/health_insights/presentation/screens/health_insights_screen.dart';
import '../../features/progress/presentation/screens/progress_screen.dart';
import '../../features/weekly_report/presentation/screens/weekly_report_screen.dart';
import '../../features/food/presentation/screens/food_search_screen.dart';
import '../../features/food/presentation/screens/food_route_screen.dart';
import '../../features/nutrition/presentation/screens/nutrition_screen.dart';
import '../../features/nutrition/presentation/screens/food_log_screen.dart';
import '../../features/health/presentation/screens/weight_screen.dart';
import '../../features/plan/presentation/screens/plan_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/account_settings_screen.dart';
import '../navigation/app_shell.dart';
import '../navigation/feature_action_navigation.dart';
import '../navigation/fitfuel_app_bar.dart';
import '../session/session_refresh_coordinator.dart';
import '../../features/food/presentation/widgets/custom_food_form.dart';
import '../../features/food/domain/entities/food_entity.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reminders/presentation/screens/daily_routine_screen.dart';
import '../../features/reminders/presentation/screens/reminder_settings_screen.dart';
import '../../features/grocery/presentation/screens/grocery_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';
import '../../features/smart_eat/presentation/screens/smart_eat_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  static const String mealPlan = '/meal-planner';
  static const String insights = '/insights';
  static const String aiAssistant = '/ai-assistant';
  static const String health = '/health';
  static const String healthInsights = '/health-insights';
  static const String weeklyReport = '/weekly-report';
  static const String foodSearch = '/food-search';
  static const String foodDetails = '/food-details';
  static const String customFood = '/custom-food';
  static const String dailyRoutine = '/daily-routine';
  static const String reminders = '/reminders';
  static const String grocery = '/grocery';
  static const String pantry = '/pantry';
  static const String analytics = '/analytics';
  static const String smartEat = '/smart-eat';
  static String? redirect(BuildContext context, GoRouterState state,
      AsyncValue<User?> authStateAsync) {
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
  }
}

class _AuthNavigationMemory {
  String? pendingLocation;
  String? lastUid;
}

class _AuthRouterRefresh extends ChangeNotifier {
  bool _disposed = false;
  void refresh() {
    // UID changes can dispose the old router during the same auth emission.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

final _authNavigationMemoryProvider =
    Provider((ref) => _AuthNavigationMemory());

// Router identity is stable within an account. A UID transition intentionally
// replaces navigator keys/stacks so another account cannot inherit retained pages.
final routerProvider = Provider<GoRouter>((ref) {
  final uid = ref
      .watch(authStateStreamProvider.select((auth) => auth.valueOrNull?.uid));
  final memory = ref.read(_authNavigationMemoryProvider);
  if (memory.lastUid != null && memory.lastUid != uid) {
    memory.pendingLocation = null;
  }
  memory.lastUid = uid;
  final refresh = _AuthRouterRefresh();
  ref.listen(authStateStreamProvider, (_, __) => refresh.refresh());
  final router = GoRouter(
    initialLocation:
        memory.pendingLocation ?? (uid == null ? AppRoutes.login : '/home'),
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateStreamProvider);
      final path = state.uri.path;
      final public = [
        '/',
        '/login',
        '/register',
        '/forgot-password',
        '/welcome'
      ].contains(path);
      if (auth.isLoading) {
        if (!public) memory.pendingLocation = state.uri.toString();
        return path == '/' ? null : '/';
      }
      if (auth.valueOrNull == null) {
        if (!public) memory.pendingLocation = state.uri.toString();
        return path == '/login' ||
                path == '/register' ||
                path == '/forgot-password'
            ? null
            : '/login';
      }
      if (public) {
        final target = memory.pendingLocation;
        memory.pendingLocation = null;
        return target == null ? '/home' : canonicalLocation(target);
      }
      return null;
    },
    errorBuilder: (context, state) => const Scaffold(
        appBar: FitFuelAppBar(title: Text('Page unavailable')),
        body: Center(
            child:
                Text('This page is unavailable. Use Back to return to Home.'))),
    routes: [
      GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: FitFuelSplashIdentity())),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/register', builder: (context, state) => const SignUpScreen()),
      GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            SessionRefreshCoordinator(child: AppShell(navigationShell: shell)),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/home',
                builder: (context, state) => const DashboardScreen())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/health',
                builder: (context, state) => HealthScreen(
                    section: state.uri.queryParameters['section'],
                    action: state.uri.queryParameters['action']),
                routes: [
                  GoRoute(
                      path: 'weight',
                      builder: (context, state) => const WeightScreen())
                ])
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/nutrition',
                builder: (context, state) => const NutritionScreen(),
                routes: [
                  GoRoute(
                      path: 'log',
                      builder: (context, state) => const FoodLogScreen()),
                  GoRoute(
                      path: 'log/:recordId/edit',
                      builder: (context, state) => FoodLogScreen(
                          recordId: state.pathParameters['recordId'])),
                  GoRoute(
                      path: 'search',
                      builder: (context, state) => FoodSearchScreen(
                          view: state.uri.queryParameters['view'])),
                  GoRoute(
                      path: 'food/:id',
                      builder: (context, state) => FoodRouteScreen(
                          id: state.pathParameters['id']!,
                          showRecipe: state.uri.queryParameters['section'] ==
                              'recipe')),
                  GoRoute(
                      path: 'custom/new',
                      builder: (context, state) => const CustomFoodForm()),
                  GoRoute(
                      path: 'custom/:id/edit',
                      builder: (context, state) => FoodRouteScreen(
                          id: state.pathParameters['id']!, editing: true)),
                ])
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/plan',
                builder: (context, state) => const PlanScreen(),
                routes: [
                  GoRoute(
                      path: 'meals',
                      builder: (context, state) => const MealPlannerScreen()),
                  GoRoute(
                      path: 'smart-eat',
                      builder: (context, state) => const SmartEatScreen()),
                  GoRoute(
                      path: 'routine',
                      builder: (context, state) => const DailyRoutineScreen()),
                  GoRoute(
                      path: 'grocery',
                      pageBuilder: (context, state) => const NoTransitionPage(
                          key: ValueKey('grocery-workspace'),
                          child: GroceryScreen())),
                  GoRoute(
                      path: 'grocery/pantry',
                      pageBuilder: (context, state) => const NoTransitionPage(
                          key: ValueKey('grocery-workspace'),
                          child: GroceryScreen(initialTab: 1))),
                ])
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/progress',
                builder: (context, state) => const ProgressScreen(),
                routes: [
                  GoRoute(
                      path: 'analytics',
                      builder: (context, state) => const AnalyticsScreen(),
                      routes: [
                        GoRoute(
                            path: 'nutrition',
                            builder: (context, state) => const HistoryScreen())
                      ]),
                  GoRoute(
                      path: 'weekly-report',
                      builder: (context, state) => const WeeklyReportScreen()),
                  GoRoute(
                      path: 'insights',
                      builder: (context, state) => const InsightsScreen(),
                      routes: [
                        GoRoute(
                            path: 'health',
                            builder: (context, state) =>
                                const HealthInsightsScreen())
                      ]),
                ])
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
                path: '/ai',
                builder: (context, state) => AiAssistantScreen(
                    initialPrompt: state.uri.queryParameters['prompt']))
          ]),
        ],
      ),
      GoRoute(
          path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [
            GoRoute(
                path: 'goals',
                builder: (context, state) => const GoalsSettingsScreen()),
            GoRoute(
                path: 'preferences',
                builder: (context, state) => const PreferencesScreen()),
            GoRoute(
                path: 'account',
                builder: (context, state) => const AccountSettingsScreen()),
            GoRoute(
                path: 'reminders',
                builder: (context, state) => const ReminderSettingsScreen()),
          ]),
      for (final alias in legacyRouteMap.entries)
        GoRoute(
            path: alias.key,
            redirect: (context, state) =>
                state.uri.replace(path: alias.value).toString()),
      GoRoute(
          path: '/food-details',
          redirect: (context, state) {
            final food = state.extra;
            return food is FoodEntity
                ? '/nutrition/food/${Uri.encodeComponent(food.id)}'
                : '/nutrition/search';
          }),
      GoRoute(
          path: '/custom-food',
          redirect: (context, state) {
            final food = state.extra;
            return food is FoodEntity
                ? '/nutrition/custom/${Uri.encodeComponent(food.id)}/edit'
                : '/nutrition/custom/new';
          }),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
