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
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is Authenticated) {
          return const HomeScreen();
        }
        if (state is AuthUnauthenticated) {
          return const SignInScreen();
        }
        return const Scaffold(body: Center(child: GradientLoader(size: 40)));
      },
    );
  }
}
