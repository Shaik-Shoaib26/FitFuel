import '../entities/nutrition_goals_entity.dart';
import '../entities/user_profile_entity.dart';

abstract class IUserProfileRepository {
  Future<void> createProfile(UserProfileEntity profile);
  Future<UserProfileEntity?> getProfile(String uid);
  Stream<UserProfileEntity?> getProfileStream(String uid);
  Future<void> updateProfile(UserProfileEntity profile);

  // Goals operations
  Future<void> saveGoals(String uid, NutritionGoalsEntity goals);
  Future<NutritionGoalsEntity?> getGoals(String uid);
  Stream<NutritionGoalsEntity?> getGoalsStream(String uid);
}
