import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/nutrition_goals_entity.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../../domain/repositories/i_profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/nutrition_goals_model.dart';
import '../models/user_profile_model.dart';

class ProfileRepositoryImpl implements IProfileRepository {
  final IProfileRemoteDataSource _remoteDataSource;

  ProfileRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> createProfile(UserProfileEntity profile) async {
    try {
      final model = UserProfileModel.fromEntity(profile);
      await _remoteDataSource.createProfile(model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<UserProfileEntity?> getProfile(String uid) async {
    try {
      final model = await _remoteDataSource.getProfile(uid);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<UserProfileEntity?> getProfileStream(String uid) {
    return _remoteDataSource
        .getProfileStream(uid)
        .map((model) => model?.toEntity());
  }

  @override
  Future<void> updateProfile(UserProfileEntity profile) async {
    try {
      final model = UserProfileModel.fromEntity(profile);
      await _remoteDataSource.updateProfile(model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<void> saveGoals(String uid, NutritionGoalsEntity goals) async {
    try {
      final model = NutritionGoalsModel.fromEntity(goals);
      await _remoteDataSource.saveGoals(uid, model);
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Future<NutritionGoalsEntity?> getGoals(String uid) async {
    try {
      final model = await _remoteDataSource.getGoals(uid);
      return model?.toEntity();
    } on ServerException catch (e) {
      throw ServerFailure(e.message);
    }
  }

  @override
  Stream<NutritionGoalsEntity?> getGoalsStream(String uid) {
    return _remoteDataSource
        .getGoalsStream(uid)
        .map((model) => model?.toEntity());
  }
}
