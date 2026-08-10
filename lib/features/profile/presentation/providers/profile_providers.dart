import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/entities/nutrition_goals_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/i_profile_repository.dart';

/// Provider for low-level FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider for IProfileRemoteDataSource
final profileRemoteDataSourceProvider = Provider<IProfileRemoteDataSource>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return ProfileRemoteDataSourceImpl(firestoreService);
});

/// Provider for IProfileRepository
final profileRepositoryProvider = Provider<IProfileRepository>((ref) {
  final dataSource = ref.watch(profileRemoteDataSourceProvider);
  return ProfileRepositoryImpl(dataSource);
});

/// StreamProvider listening to current authenticated user's profile document from users/{uid}
final currentProfileStreamProvider = StreamProvider<UserProfileEntity?>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) {
    return Stream.value(null);
  }
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getProfileStream(authUser.uid);
});

/// StreamProvider listening to current authenticated user's nutrition goals from users/{uid}/goals/currentGoal
final nutritionGoalsStreamProvider = StreamProvider<NutritionGoalsEntity?>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) {
    return Stream.value(null);
  }
  final repository = ref.watch(profileRepositoryProvider);
  return repository.getGoalsStream(authUser.uid);
});
