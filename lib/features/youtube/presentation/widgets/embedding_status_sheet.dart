import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/embedding_progress_cubit.dart';
import 'package:zensort/theme.dart';

class EmbeddingStatusSheet extends StatelessWidget {
  const EmbeddingStatusSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<EmbeddingProgressCubit>().state;
    final percent = progress.percentComplete;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Embeddings Status',
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'We generate semantic embeddings for your liked videos. This powers clustering (k-means) and smarter discovery beyond simple metadata. You can keep browsing while we process in the background.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: percent.clamp(0, 1),
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(
                ZenSortTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(label: 'Total', value: progress.total.toString()),
                const SizedBox(width: 8),
                _InfoChip(label: 'Completed', value: progress.completed.toString()),
                const SizedBox(width: 8),
                _InfoChip(label: 'Failed', value: progress.failed.toString()),
                const SizedBox(width: 8),
                _InfoChip(label: 'Pending', value: progress.pending.toString()),
                const Spacer(),
                Text('${(percent * 100).toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 16),
            if (progress.isComplete)
              Row(
                children: [
                  Icon(Icons.check_circle, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'All embeddings are up to date. Enjoy clustering and search!',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              )
            else
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Processing in the background. This can take a while for larger libraries.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$label: $value',
      child: Chip(
        label: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            Text(value, style: theme.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}


