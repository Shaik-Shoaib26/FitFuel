import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_theme.dart';
import 'config/routes.dart';
import '../features/appearance/domain/appearance_repository.dart';
import '../features/appearance/presentation/appearance_controller.dart';

class FitFuelApp extends ConsumerWidget {
  const FitFuelApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: switch (ref.watch(appearanceControllerProvider).valueOrNull) {
        AppearanceMode.system => ThemeMode.system,
        AppearanceMode.dark => ThemeMode.dark,
        _ => ThemeMode.light,
      },
      routerConfig: router,
    );
  }
}
