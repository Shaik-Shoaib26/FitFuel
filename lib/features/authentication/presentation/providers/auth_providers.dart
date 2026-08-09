import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/i_auth_repository.dart';

/// Service Provider for low-level AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Remote Data Source Provider
final authRemoteDataSourceProvider = Provider<IAuthRemoteDataSource>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthRemoteDataSourceImpl(authService);
});

/// Repository Provider for Clean Architecture IAuthRepository
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final dataSource = ref.watch(authRemoteDataSourceProvider);
  return AuthRepositoryImpl(dataSource);
});

/// StreamProvider exposing Firebase Auth state changes
final authStateStreamProvider = StreamProvider<User?>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return repository.authStateChanges;
});
