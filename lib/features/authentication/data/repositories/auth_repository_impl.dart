import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final IAuthRemoteDataSource _remoteDataSource;

  AuthRepositoryImpl(this._remoteDataSource);

  @override
  AuthUserEntity? get currentUser {
    final user = _remoteDataSource.currentUser;
    if (user == null) return null;
    return _mapFirebaseUserToEntity(user);
  }

  @override
  Stream<User?> get authStateChanges => _remoteDataSource.authStateChanges;

  @override
  Future<AuthUserEntity> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _remoteDataSource.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('User creation succeeded but no user details returned.');
      }
      return _mapFirebaseUserToEntity(user);
    } on ServerException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<AuthUserEntity> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _remoteDataSource.signIn(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure('Sign in succeeded but no user details returned.');
      }
      return _mapFirebaseUserToEntity(user);
    } on ServerException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email: email);
    } on ServerException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _remoteDataSource.signOut();
    } on ServerException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    try {
      await _remoteDataSource.deleteAccount(password: password);
    } on ServerException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  AuthUserEntity _mapFirebaseUserToEntity(User user) {
    return AuthUserEntity(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      emailVerified: user.emailVerified,
    );
  }
}
