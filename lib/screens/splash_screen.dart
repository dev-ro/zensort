import 'package:flutter/material.dart';
import 'package:zensort/widgets/gradient_loader.dart';

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
