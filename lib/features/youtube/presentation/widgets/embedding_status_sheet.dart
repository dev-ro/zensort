import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';
import 'package:zensort/features/youtube/presentation/bloc/embedding_progress_cubit.dart';
import 'package:zensort/theme.dart';

class EmbeddingStatusSheet extends StatelessWidget {
  const EmbeddingStatusSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: ZenSortTheme.primaryGradient,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.analytics, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Embedding Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: BlocBuilder<EmbeddingProgressCubit, EmbeddingProgress>(
              builder: (context, progress) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Progress Bar
                    LinearProgressIndicator(
                      value: progress.percentComplete,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        ZenSortTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Progress Text
                    Text(
                      _getProgressText(progress),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),

                    // Statistics Grid
                    _buildStatisticsGrid(context, progress),

                    if (progress.lastUpdated != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Last updated: ${_formatDateTime(progress.lastUpdated!)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid(
    BuildContext context,
    EmbeddingProgress progress,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'Total',
            progress.total.toString(),
            Icons.video_library,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            'Completed',
            progress.completed.toString(),
            Icons.check_circle,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            'Pending',
            progress.pending.toString(),
            Icons.schedule,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(
            context,
            'Failed',
            progress.failed.toString(),
            Icons.error,
            Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getProgressText(EmbeddingProgress progress) {
    if (progress.total == 0) {
      return 'No embeddings in progress';
    }

    if (progress.isComplete) {
      return 'Embedding process completed!';
    }

    final percentage = (progress.percentComplete * 100).round();
    return 'Processing embeddings: $percentage% complete';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
