import 'package:flutter/material.dart';
import 'package:zensort/widgets/animated_gradient_app_bar.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(child: GradientLoader(size: 80)),
    );
  }
}
