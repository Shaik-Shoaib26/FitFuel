import 'package:firebase_auth/firebase_auth.dart';
import '../errors/exceptions.dart';
import 'firestore_service.dart';
import 'logger_service.dart';

/// Low-level authentication service encapsulating FirebaseAuth instance.
/// Maps raw Firebase exceptions into clean, user-friendly exception messages.
class AuthService {
  final FirebaseAuth _firebaseAuth;
  final FirestoreService _firestoreService;

  AuthService({FirebaseAuth? firebaseAuth, FirestoreService? firestoreService})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _firestoreService = firestoreService ?? FirestoreService();

  /// Returns current authenticated Firebase user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream listening to authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Signs up a new user with Email and Password & provisions Firestore profile users/{uid}
  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final trimmedEmail = email.trim();
      final trimmedName = displayName?.trim() ?? '';
      LoggerService.info('Attempting Firebase Sign Up for email: $trimmedEmail');

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        if (trimmedName.isNotEmpty) {
          await user.updateDisplayName(trimmedName);
          await user.reload();
        }

        // Check if profile exists before creating to prevent duplicate creation
        final existingDoc = await _firestoreService.getUserProfile(user.uid);
        if (!existingDoc.exists) {
          LoggerService.info('Auto-provisioning Firestore profile document for UID: ${user.uid}');
          await _firestoreService.createUserProfile(
            uid: user.uid,
            data: {
              'uid': user.uid,
              'email': user.email ?? trimmedEmail,
              'displayName': trimmedName.isNotEmpty ? trimmedName : user.displayName,
              'photoUrl': user.photoURL,
              'emailVerified': user.emailVerified,
            },
          );
          LoggerService.info('Firestore profile document successfully created for UID: ${user.uid}');
        }
      }

      LoggerService.info('Sign Up Successful for UID: ${user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      LoggerService.error('FirebaseAuthException during Sign Up [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirebaseAuthException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error during Sign Up', e, stackTrace);
      throw ServerException(message: 'An unexpected authentication error occurred. Please try again.');
    }
  }

  /// Signs in an existing user with Email and Password
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final trimmedEmail = email.trim();
      LoggerService.info('Attempting Firebase Sign In for email: $trimmedEmail');
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        final existingDoc = await _firestoreService.getUserProfile(user.uid);
        if (!existingDoc.exists) {
          LoggerService.info('Provisioning missing Firestore profile on sign-in for UID: ${user.uid}');
          await _firestoreService.createUserProfile(
            uid: user.uid,
            data: {
              'uid': user.uid,
              'email': user.email ?? trimmedEmail,
              'displayName': user.displayName,
              'photoUrl': user.photoURL,
              'emailVerified': user.emailVerified,
            },
          );
        }
      }

      LoggerService.info('Sign In Successful for UID: ${user?.uid}');
      return credential;
    } on FirebaseAuthException catch (e, stackTrace) {
      LoggerService.error('FirebaseAuthException during Sign In [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirebaseAuthException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error during Sign In', e, stackTrace);
      throw ServerException(message: 'An unexpected authentication error occurred. Please try again.');
    }
  }

  /// Sends password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    final trimmedEmail = email.trim();
    try {
      LoggerService.info('Password reset requested for email: $trimmedEmail');
      await _firebaseAuth.sendPasswordResetEmail(email: trimmedEmail);
      LoggerService.info('Password reset email sent successfully to: $trimmedEmail');
    } on FirebaseAuthException catch (e, stackTrace) {
      if (e.code == 'user-not-found') {
        LoggerService.info('User not found during password reset (email enumeration protection)');
        return;
      }
      LoggerService.error('Password reset failed: ${e.code} - ${e.message}', e, stackTrace);
      throw ServerException(message: _mapFirebaseAuthException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error during Password Reset', e, stackTrace);
      throw ServerException(message: 'Unable to send password reset email. Please try again later.');
    }
  }

  /// Deletes current authenticated user's account and profile document.
  /// Reauthenticates if required by Firebase Auth.
  Future<void> deleteAccount({required String password}) async {
    final user = currentUser;
    if (user == null) {
      throw ServerException(message: 'No user is currently authenticated.');
    }

    try {
      final email = user.email;
      if (email != null) {
        LoggerService.info('Reauthenticating user UID: ${user.uid} before account deletion');
        final credential = EmailAuthProvider.credential(email: email, password: password);
        await user.reauthenticateWithCredential(credential);
      }

      final uid = user.uid;
      LoggerService.info('Deleting user profile from Firestore for UID: $uid');
      await _firestoreService.deleteUserProfile(uid);

      LoggerService.info('Deleting Firebase Auth user for UID: $uid');
      await user.delete();
      LoggerService.info('Account deleted successfully');
    } on FirebaseAuthException catch (e, stackTrace) {
      LoggerService.error('FirebaseAuthException during account deletion [Code: ${e.code}]', e, stackTrace);
      throw ServerException(message: _mapFirebaseAuthException(e));
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error during account deletion', e, stackTrace);
      throw ServerException(message: 'Failed to delete account. Please try again.');
    }
  }

  /// Signs out current user
  Future<void> signOut() async {
    try {
      final uid = currentUser?.uid;
      LoggerService.info('Signing out user UID: $uid');
      await _firebaseAuth.signOut();
      LoggerService.info('Sign Out Successful');
    } catch (e, stackTrace) {
      LoggerService.error('Unexpected error during Sign Out', e, stackTrace);
      throw ServerException(message: 'Failed to sign out. Please try again.');
    }
  }

  /// Converts raw FirebaseAuthException codes to user-friendly messages
  String _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email address is already registered. Please sign in or use another email.';
      case 'invalid-email':
        return 'The email address format is invalid. Please check and try again.';
      case 'weak-password':
        return 'The password provided is too weak. Please use a stronger password (minimum 8 characters).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This user account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network connection failed. Please check your internet connection.';
      default:
        return e.message ?? 'Authentication failed. Please verify your credentials and try again.';
    }
  }
}
