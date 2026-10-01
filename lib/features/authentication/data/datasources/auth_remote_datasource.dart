import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/auth_service.dart';

abstract class IAuthRemoteDataSource {
  User? get currentUser;
  Stream<User?> get authStateChanges;
  Future<UserCredential> signUp({required String email, required String password, String? displayName});
  Future<UserCredential> signIn({required String email, required String password});
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> signOut();
  Future<void> deleteAccount({required String password});
}

class AuthRemoteDataSourceImpl implements IAuthRemoteDataSource {
  final AuthService _authService;

  AuthRemoteDataSourceImpl(this._authService);

  @override
  User? get currentUser => _authService.currentUser;

  @override
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? displayName,
  }) =>
      _authService.signUp(email: email, password: password, displayName: displayName);

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) =>
      _authService.signIn(email: email, password: password);

  @override
  Future<void> sendPasswordResetEmail({required String email}) =>
      _authService.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => _authService.signOut();

  @override
  Future<void> deleteAccount({required String password}) =>
      _authService.deleteAccount(password: password);
}
