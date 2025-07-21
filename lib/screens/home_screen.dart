import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/widgets/zen_sort_scaffold.dart';
import 'package:zensort/widgets/animated_gradient_app_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // This screen should only be reached if the user is authenticated,
    // but as a safeguard, we'll handle the null case.
    if (user == null) {
      return ZenSortScaffold(
        appBar: const AnimatedGradientAppBar(),
        body: const Center(
          child: Text('Error: User not found. Please sign in again.'),
        ),
      );
    }

    return ZenSortScaffold(
      appBar: const AnimatedGradientAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: user.photoURL != null
                    ? NetworkImage(user.photoURL!)
                    : null,
                child: user.photoURL == null
                    ? const Icon(Icons.person, size: 50)
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome, ${user.displayName ?? 'User'}!',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (user.email != null)
                Text(
                  user.email!,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
