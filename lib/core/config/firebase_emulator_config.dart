import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../services/logger_service.dart';

/// Configures local Firebase Authentication and Firestore Emulators for testing and debug mode.
/// Guarantees that emulators cannot be silently activated in release or production environments.
class FirebaseEmulatorConfig {
  static bool _configured = false;

  /// Returns the appropriate host for emulator connections:
  /// - '10.0.2.2' for Android Virtual Devices (AVD host-loopback alias)
  /// - '127.0.0.1' for Web, iOS simulator, Desktop, and local test host
  static String get defaultHost {
    if (kIsWeb) return '127.0.0.1';
    if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
    return '127.0.0.1';
  }

  /// Connects the Flutter Firebase SDK to local Firebase Emulators safely.
  /// Throws [UnsupportedError] in release mode to prevent accidental production redirection.
  static void useEmulators({
    String? host,
    int authPort = 9099,
    int firestorePort = 8080,
  }) {
    if (kReleaseMode) {
      throw UnsupportedError('Firebase emulators cannot be enabled in release or production builds.');
    }
    if (_configured) {
      LoggerService.info('Firebase emulators already configured.');
      return;
    }

    final targetHost = host ?? defaultHost;
    LoggerService.info(
      'Configuring Flutter Firebase Emulators -> Auth: $targetHost:$authPort, Firestore: $targetHost:$firestorePort',
    );

    try {
      FirebaseAuth.instance.useAuthEmulator(targetHost, authPort);
      FirebaseFirestore.instance.useFirestoreEmulator(targetHost, firestorePort);
      _configured = true;
    } catch (e) {
      LoggerService.warning('Failed to attach Firebase Emulators: $e');
    }
  }

  /// Returns true if emulators have been attached to the current process.
  static bool get isConfigured => _configured;
}
