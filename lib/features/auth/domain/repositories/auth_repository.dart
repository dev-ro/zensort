import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;
  Future<UserCredential?> signInWithGoogle();
  Future<void> signOut();
}
