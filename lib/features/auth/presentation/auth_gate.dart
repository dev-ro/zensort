import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:zensort/features/youtube/presentation/screens/home_screen.dart';
import 'package:zensort/widgets/gradient_loader.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Connect to the central state authority - AuthBloc provides stable authentication state
    // This establishes the hierarchical flow: Repository -> AuthBloc -> UI
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        // Show loading during initial state or loading
        if (state is AuthInitial || state is AuthLoading) {
          return const Scaffold(body: Center(child: GradientLoader(size: 40)));
        }

        // If user is authenticated, show the main app
        if (state is Authenticated) {
          return const HomeScreen();
        }

        // Show error state temporarily, then fall back to sign-in
        if (state is AuthError) {
          // In production, you might want to show an error dialog
          // For now, fall through to sign-in screen
        }

        // Default to sign-in screen for unauthenticated or error states
        return const SignInScreen();
      },
    );
  }
}
