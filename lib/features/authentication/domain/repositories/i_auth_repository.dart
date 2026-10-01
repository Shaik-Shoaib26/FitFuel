import 'package:firebase_auth/firebase_auth.dart';
import '../entities/auth_user_entity.dart';

abstract class IAuthRepository {
  AuthUserEntity? get currentUser;
  Stream<User?> get authStateChanges;

  Future<AuthUserEntity> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  Future<AuthUserEntity> signIn({
    required String email,
    required String password,
  });

  Future<void> sendPasswordResetEmail({required String email});

  Future<void> signOut();

  Future<void> deleteAccount({required String password});
}
