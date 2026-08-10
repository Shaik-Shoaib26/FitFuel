import '../../../../core/services/firestore_service.dart';
import '../models/nutrition_goals_model.dart';
import '../models/user_profile_model.dart';

abstract class IProfileRemoteDataSource {
  Future<void> createProfile(UserProfileModel profile);
  Future<UserProfileModel?> getProfile(String uid);
  Stream<UserProfileModel?> getProfileStream(String uid);
  Future<void> updateProfile(UserProfileModel profile);

  // Goals-related methods
  Future<void> saveGoals(String uid, NutritionGoalsModel goals);
  Future<NutritionGoalsModel?> getGoals(String uid);
  Stream<NutritionGoalsModel?> getGoalsStream(String uid);
}

class ProfileRemoteDataSourceImpl implements IProfileRemoteDataSource {
  final FirestoreService _firestoreService;

  ProfileRemoteDataSourceImpl(this._firestoreService);

  @override
  Future<void> createProfile(UserProfileModel profile) async {
    await _firestoreService.createUserProfile(
      uid: profile.uid,
      data: profile.toFirestore(),
    );
  }

  @override
  Future<UserProfileModel?> getProfile(String uid) async {
    final doc = await _firestoreService.getUserProfile(uid);
    if (!doc.exists || doc.data() == null) return null;
    return UserProfileModel.fromFirestore(doc);
  }

  @override
  Stream<UserProfileModel?> getProfileStream(String uid) {
    return _firestoreService.getUserProfileStream(uid).map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfileModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> updateProfile(UserProfileModel profile) async {
    await _firestoreService.updateUserProfile(
      uid: profile.uid,
      data: profile.toFirestore(),
    );
  }

  @override
  Future<void> saveGoals(String uid, NutritionGoalsModel goals) async {
    await _firestoreService.createUserGoals(
      uid: uid,
      data: goals.toFirestore(),
    );
  }

  @override
  Future<NutritionGoalsModel?> getGoals(String uid) async {
    final doc = await _firestoreService.getUserGoals(uid);
    if (!doc.exists || doc.data() == null) return null;
    return NutritionGoalsModel.fromFirestore(doc);
  }

  @override
  Stream<NutritionGoalsModel?> getGoalsStream(String uid) {
    return _firestoreService.getUserGoalsStream(uid).map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return NutritionGoalsModel.fromFirestore(doc);
    });
  }
}
