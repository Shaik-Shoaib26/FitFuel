import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/nutrition_goals_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/i_user_profile_repository.dart';
import '../datasources/user_profile_remote_datasource.dart';
import '../models/user_profile_model.dart';

class UserProfileRepositoryImpl implements IUserProfileRepository {
  final IUserProfileRemoteDataSource _remoteDataSource;

  UserProfileRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> createProfile(UserProfileEntity profile) async {
    try {
      final model = UserProfileModel.fromEntity(profile);
      await _remoteDataSource.createUserProfile(model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<UserProfileEntity?> getProfile(String uid) async {
    try {
      final model = await _remoteDataSource.getUserProfile(uid);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<UserProfileEntity?> getProfileStream(String uid) {
    return _remoteDataSource
        .getUserProfileStream(uid)
        .map((model) => model?.toEntity());
  }

  @override
  Future<void> updateProfile(UserProfileEntity profile) async {
    try {
      final model = UserProfileModel.fromEntity(profile);
      await _remoteDataSource.updateUserProfile(model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> saveGoals(String uid, NutritionGoalsEntity goals) {
    throw UnimplementedError('Use IProfileRepository instead.');
  }

  @override
  Future<NutritionGoalsEntity?> getGoals(String uid) {
    throw UnimplementedError('Use IProfileRepository instead.');
  }

  @override
  Stream<NutritionGoalsEntity?> getGoalsStream(String uid) {
    throw UnimplementedError('Use IProfileRepository instead.');
  }
}
