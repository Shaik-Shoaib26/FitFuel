import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../data/datasources/user_profile_remote_datasource.dart';
import '../../data/repositories/user_profile_repository_impl.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/i_user_profile_repository.dart';

/// Provider for low-level FirestoreService
final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService();
});

/// Provider for IUserProfileRemoteDataSource
final userProfileRemoteDataSourceProvider = Provider<IUserProfileRemoteDataSource>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return UserProfileRemoteDataSourceImpl(firestoreService);
});

/// Provider for IUserProfileRepository
final userProfileRepositoryProvider = Provider<IUserProfileRepository>((ref) {
  final dataSource = ref.watch(userProfileRemoteDataSourceProvider);
  return UserProfileRepositoryImpl(dataSource);
});

/// StreamProvider listening to current authenticated user's profile document from users/{uid}
final currentProfileStreamProvider = StreamProvider<UserProfileEntity?>((ref) {
  final authUser = ref.watch(authStateStreamProvider).value;
  if (authUser == null) {
    return Stream.value(null);
  }
  final repository = ref.watch(userProfileRepositoryProvider);
  return repository.getProfileStream(authUser.uid);
});
