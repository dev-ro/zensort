import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:rxdart/rxdart.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';
import 'package:zensort/features/auth/domain/entities/sign_in_result.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId:
        '630957314497-52e7nhm73i52je3j0uqdfb2lsq5956q9.apps.googleusercontent.com',
    scopes: ['email', 'https://www.googleapis.com/auth/youtube.readonly'],
  );

  /// BehaviorSubject caches the latest user state and immediately emits it to new subscribers
  /// This is the single source of truth for authentication status
  final _userSubject = BehaviorSubject<User?>.seeded(null);

  /// CRITICAL: Single source of truth - only Firebase authStateChanges updates the subject
  /// This establishes a pure, unidirectional data flow that prevents race conditions
  AuthRepositoryImpl(this._firebaseAuth, this._firestore) {
    _firebaseAuth.authStateChanges().listen(_userSubject.add);
  }

  @override
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  @override
  Stream<User?> get currentUser => _userSubject.stream;

  /// Performs Google Sign-In action only - does NOT manually update state
  /// State updates happen automatically via Firebase authStateChanges listener
  @override
  Future<SignInResult?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        try {
          // 1. Use GoogleSignIn to get the account and authentication details
          final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
          if (googleUser == null) {
            // User cancelled the sign-in
            return null;
          }
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;

          // 2. Extract the accessToken (THIS IS THE CRITICAL STEP)
          final String? accessToken = googleAuth.accessToken;

          if (accessToken == null) {
            throw Exception(
              'Google Sign-In failed to provide an access token.',
            );
          }

          // 3. Create the Firebase credential
          final AuthCredential credential = GoogleAuthProvider.credential(
            accessToken: accessToken,
            idToken: googleAuth.idToken,
          );

          // 4. Sign in to Firebase - this triggers authStateChanges automatically
          final UserCredential userCredential = await _firebaseAuth
              .signInWithCredential(credential);
          final User user = userCredential.user!;

          await _createUserDocument(user);

          // 5. Return the result - NO manual state updates needed
          return SignInResult(user: user, accessToken: accessToken);
        } catch (e) {
          // Handle errors
          print('Error during Google sign-in: $e');
          return null;
        }
      } else {
        // Mobile implementation would still use the GoogleSignIn flow if needed
        // For now, throw an exception as this app is web-first
        throw Exception(
          'Mobile sign-in not implemented in this web-first version',
        );
      }
    } catch (e) {
      // Let the BLoC handle the error state
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

  /// Performs sign-out action only - does NOT manually update state
  /// State updates happen automatically via Firebase authStateChanges listener
  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
    // Firebase authStateChanges will automatically emit null
  }

  @override
  Future<String?> getAccessToken() async {
    // Get a fresh access token from the current Google Sign-In session
    final GoogleSignInAccount? googleUser = _googleSignIn.currentUser;
    if (googleUser != null) {
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      return googleAuth.accessToken;
    }
    return null;
  }

  /// Performs silent sign-in only - does NOT manually update state
  /// Any resulting auth state changes are handled by Firebase authStateChanges listener
  @override
  Future<String?> signInSilentlyWithGoogle() async {
    try {
      if (kIsWeb) {
        // Attempt to sign in silently (no user interaction required)
        final GoogleSignInAccount? googleUser = await _googleSignIn
            .signInSilently();
        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          return googleAuth.accessToken;
        }
      }
      return null;
    } catch (e) {
      // Silent sign-in failed, return null to indicate no token available
      print('Silent sign-in failed: $e');
      return null;
    }
  }

  /// Dispose method to close the BehaviorSubject and prevent memory leaks
  void dispose() {
    _userSubject.close();
  }
}
