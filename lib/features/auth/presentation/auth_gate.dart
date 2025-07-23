import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';
import 'package:zensort/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:zensort/features/youtube/presentation/screens/home_screen.dart';
import 'package:zensort/widgets/gradient_loader.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: context.read<AuthRepository>().currentUser,
      builder: (context, snapshot) {
        // While waiting for connection or data, show loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: GradientLoader(size: 40)));
        }

        // If we have a user (authenticated), show the main app
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // No user (unauthenticated), show sign-in screen
        return const SignInScreen();
      },
    );
  }
}
