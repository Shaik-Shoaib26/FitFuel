import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../../features/food/presentation/screens/food_details_screen.dart';
import '../../features/food/presentation/widgets/custom_food_form.dart';
import '../../features/food/domain/entities/food_entity.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/reminders/presentation/screens/daily_routine_screen.dart';
import '../../features/reminders/presentation/screens/reminder_settings_screen.dart';
import '../../features/grocery/presentation/screens/grocery_screen.dart';
import '../../features/analytics/presentation/screens/analytics_screen.dart';

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
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.mealPlan,
        builder: (context, state) => const MealPlannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.dailyRoutine,
        builder: (context, state) => const DailyRoutineScreen(),
      ),
      GoRoute(
        path: AppRoutes.reminders,
        builder: (context, state) => const ReminderSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.insights,
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiAssistant,
        builder: (context, state) {
          final prompt = state.uri.queryParameters['prompt'];
          return AiAssistantScreen(initialPrompt: prompt);
        },
      ),
      GoRoute(
        path: AppRoutes.health,
        builder: (context, state) => const HealthScreen(),
      ),
      GoRoute(
        path: AppRoutes.healthInsights,
        builder: (context, state) => const HealthInsightsScreen(),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (context, state) => const ProgressScreen(),
      ),
      GoRoute(
        path: AppRoutes.weeklyReport,
        builder: (context, state) => const WeeklyReportScreen(),
      ),
      GoRoute(
        path: AppRoutes.foodSearch,
        builder: (context, state) => const FoodSearchScreen(),
      ),
      GoRoute(
        path: AppRoutes.foodDetails,
        builder: (context, state) {
          final food = state.extra as FoodEntity;
          return FoodDetailsScreen(food: food);
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.customFood,
        builder: (context, state) {
          final food = state.extra as FoodEntity?;
          return CustomFoodForm(existingFood: food);
        },
      ),
      GoRoute(
        path: AppRoutes.grocery,
        builder: (context, state) => const GroceryScreen(),
      ),
      GoRoute(
        path: AppRoutes.pantry,
        builder: (context, state) => const GroceryScreen(),
      ),
      GoRoute(
        path: AppRoutes.analytics,
        builder: (context, state) => const AnalyticsScreen(),
      ),
    ],
  );
});
