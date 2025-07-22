import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/youtube.readonly'],
  );

  AuthRepositoryImpl(this._firebaseAuth, this._firestore);

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Future<String?> signInWithGoogle() async {
    try {
      UserCredential? userCredential;
      String? accessToken;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope(
          'https://www.googleapis.com/auth/youtube.readonly',
        );
        userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
        // For web, we need to get the access token from the credential
        final oauthCredential = userCredential.credential as OAuthCredential?;
        accessToken = oauthCredential?.accessToken;
      } else {
        // IMPORTANT: If you change the scopes, users must sign out and sign back in
        // to grant the new permissions.
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser == null) {
          return null; // User cancelled the sign-in
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Store the access token before creating the credential
        accessToken = googleAuth.accessToken;

        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _firebaseAuth.signInWithCredential(credential);
      }
      await _createUserDocument(userCredential.user);
      return accessToken;
    } catch (e) {
      // It's better to let the BLoC handle the error state.
      rethrow;
    }
  }

  Future<void> _createUserDocument(User? user) async {
    if (user == null) return;
    final userRef = _firestore.collection('users').doc(user.uid);
    final doc = await userRef.get();
    if (!doc.exists) {
      userRef.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'photoURL': user.photoURL,
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  @override
  Future<String?> getAccessToken() async {
    // This method can be used to get a fresh access token
    if (!kIsWeb) {
      final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
      if (googleUser != null) {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        return googleAuth.accessToken;
      }
    }
    // For web, we might need to implement token refresh logic
    return null;
  }
}
