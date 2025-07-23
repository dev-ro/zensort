import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/auth/domain/entities/sign_in_result.dart';

abstract class AuthRepository {
  /// Stream of Firebase User objects for Firebase-specific operations
  Stream<User?> get authStateChanges;
  
  /// Stream of current user state - the single source of truth for authentication
  /// This stream is cached and immediately provides the current state to new subscribers
  Stream<User?> get currentUser;
  
  Future<SignInResult?> signInWithGoogle();
  Future<void> signOut();
  Future<String?> getAccessToken();
  Future<String?> signInSilentlyWithGoogle();
}
