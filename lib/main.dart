import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/config/env_config.dart';
import 'core/services/logger_service.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Environment Configurations
    await EnvConfig.init();

    LoggerService.info('FitFuel Foundation Initialized [Env: ${EnvConfig.environment}]');

    runApp(
      const ProviderScope(
        child: FitFuelApp(),
      ),
    );
  }, (error, stackTrace) {
    LoggerService.error('Global Unhandled Exception', error, stackTrace);
  });
}
