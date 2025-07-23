import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/auth/domain/entities/sign_in_result.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<SignInResult?> signInWithGoogle();
  Future<void> signOut();
  Future<String?> getAccessToken();
  Future<String?> signInSilentlyWithGoogle();
}
