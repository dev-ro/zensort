import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<String?> signInWithGoogle();
  Future<void> signOut();
  Future<String?> getAccessToken();
}
