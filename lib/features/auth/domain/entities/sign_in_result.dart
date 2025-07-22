import 'package:firebase_auth/firebase_auth.dart';

class SignInResult {
  final User user;
  final String accessToken;

  const SignInResult({required this.user, required this.accessToken});
}
