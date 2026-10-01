import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/auth_user_entity.dart';
import '../../domain/repositories/i_auth_repository.dart';
import '../providers/auth_providers.dart';

abstract class AuthUiState {
  const AuthUiState();
}

class AuthUiStateInitial extends AuthUiState {
  const AuthUiStateInitial();
}

class AuthUiStateLoading extends AuthUiState {
  const AuthUiStateLoading();
}

class AuthUiStateSuccess extends AuthUiState {
  final AuthUserEntity? user;
  final String? successMessage;
  const AuthUiStateSuccess({this.user, this.successMessage});
}

class AuthUiStateError extends AuthUiState {
  final String message;
  const AuthUiStateError(this.message);
}

class AuthController extends StateNotifier<AuthUiState> {
  final IAuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AuthUiStateInitial());

  Future<bool> signIn({required String email, required String password}) async {
    state = const AuthUiStateLoading();
    try {
      final user = await _authRepository.signIn(email: email, password: password);
      state = AuthUiStateSuccess(user: user);
      return true;
    } on AuthFailure catch (e) {
      state = AuthUiStateError(e.message);
      return false;
    } catch (e) {
      state = const AuthUiStateError('An unexpected authentication error occurred.');
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    state = const AuthUiStateLoading();
    try {
      final user = await _authRepository.signUp(
        email: email,
        password: password,
        displayName: name,
      );
      state = AuthUiStateSuccess(user: user);
      return true;
    } on AuthFailure catch (e) {
      state = AuthUiStateError(e.message);
      return false;
    } catch (e) {
      state = const AuthUiStateError('An unexpected registration error occurred.');
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail({required String email}) async {
    state = const AuthUiStateLoading();
    try {
      await _authRepository.sendPasswordResetEmail(email: email);
      state = const AuthUiStateSuccess(
        successMessage: 'If an account exists for this email, a password reset email has been sent.',
      );
      return true;
    } on AuthFailure catch (e) {
      state = AuthUiStateError(e.message);
      return false;
    } catch (e) {
      state = const AuthUiStateError('Unable to send password reset email.');
      return false;
    }
  }

  Future<void> signOut() async {
    state = const AuthUiStateLoading();
    try {
      await _authRepository.signOut();
      state = const AuthUiStateInitial();
    } on AuthFailure catch (e) {
      state = AuthUiStateError(e.message);
    }
  }

  Future<bool> deleteAccount({required String password}) async {
    state = const AuthUiStateLoading();
    try {
      await _authRepository.deleteAccount(password: password);
      state = const AuthUiStateInitial();
      return true;
    } on AuthFailure catch (e) {
      state = AuthUiStateError(e.message);
      return false;
    } catch (e) {
      state = const AuthUiStateError('An unexpected error occurred during account deletion.');
      return false;
    }
  }

  void resetState() {
    state = const AuthUiStateInitial();
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthUiState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});
