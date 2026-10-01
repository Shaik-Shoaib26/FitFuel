import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app/app.dart';
import 'app/config/env_config.dart';
import 'core/services/logger_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Environment Configurations
    await EnvConfig.init();

    // Initialize Firebase Core Engine
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      LoggerService.info('Firebase Core Initialized Successfully [Project ID: fitfuel-ab042]');
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        LoggerService.info('Firestore Offline Cache Enabled Successfully');
      } catch (e) {
        LoggerService.warning('Failed to configure Firestore settings: $e');
      }
    } catch (e, stackTrace) {
      LoggerService.error('Firebase Core Initialization Failed', e, stackTrace);
      rethrow;
    }

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
