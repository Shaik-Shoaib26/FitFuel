import '../../../../core/services/firestore_service.dart';
import '../models/user_profile_model.dart';

abstract class IUserProfileRemoteDataSource {
  Future<void> createUserProfile(UserProfileModel profile);
  Future<UserProfileModel?> getUserProfile(String uid);
  Stream<UserProfileModel?> getUserProfileStream(String uid);
  Future<void> updateUserProfile(UserProfileModel profile);
}

class UserProfileRemoteDataSourceImpl implements IUserProfileRemoteDataSource {
  final FirestoreService _firestoreService;

  UserProfileRemoteDataSourceImpl(this._firestoreService);

  @override
  Future<void> createUserProfile(UserProfileModel profile) async {
    await _firestoreService.createUserProfile(
      uid: profile.uid,
      data: profile.toFirestore(),
    );
  }

  @override
  Future<UserProfileModel?> getUserProfile(String uid) async {
    final doc = await _firestoreService.getUserProfile(uid);
    if (!doc.exists || doc.data() == null) return null;
    return UserProfileModel.fromFirestore(doc);
  }

  @override
  Stream<UserProfileModel?> getUserProfileStream(String uid) {
    return _firestoreService.getUserProfileStream(uid).map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserProfileModel.fromFirestore(doc);
    });
  }

  @override
  Future<void> updateUserProfile(UserProfileModel profile) async {
    await _firestoreService.updateUserProfile(
      uid: profile.uid,
      data: profile.toFirestore(),
    );
  }
}
