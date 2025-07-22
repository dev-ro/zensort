import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/widgets/gradient_loader.dart';
import 'package:zensort/widgets/logo_heading.dart';

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LogoHeading(title: "Welcome to ZenSort"),
            const SizedBox(height: 48),
            BlocConsumer<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is Unauthenticated && state.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign-in failed: ${state.error}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              builder: (context, state) {
                if (state is AuthLoading) {
                  return const GradientLoader(size: 40);
                }
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    minimumSize: const Size(250, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 2,
                    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: () {
                    context.read<AuthBloc>().add(SignInWithGoogle());
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        'assets/images/google_logo.svg',
                        height: 24,
                        width: 24,
                      ),
                      const SizedBox(width: 16),
                      const Text('Sign in with Google'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
