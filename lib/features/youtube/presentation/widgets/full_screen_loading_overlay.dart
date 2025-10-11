import 'package:flutter/material.dart';

class FullScreenLoadingOverlay extends StatelessWidget {
  final int? loaded;
  final int? total;

  const FullScreenLoadingOverlay({super.key, this.loaded, this.total});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double? value = (loaded != null && total != null && total! > 0)
        ? (loaded! / total!).clamp(0.0, 1.0).toDouble()
        : null;

    return Container(
      color: Colors.black.withAlpha(150),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Loading your videos',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'This can take a while for larger libraries. Please wait while we prepare your shelves and search.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: value),
                if (loaded != null && total != null) ...[
                  const SizedBox(height: 12),
                  Text('Loaded $loaded of $total', textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
