import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/theme.dart';

class EmbeddingStatusSheet extends StatefulWidget {
  const EmbeddingStatusSheet({super.key});

  @override
  State<EmbeddingStatusSheet> createState() => _EmbeddingStatusSheetState();
}

class _EmbeddingStatusSheetState extends State<EmbeddingStatusSheet> {
  @override
  void initState() {
    super.initState();
    context.read<YouTubeBloc>().add(CalculateEmbeddingProgress());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<YouTubeBloc, YoutubeState>(
      listener: (context, state) {
        if (state is EmbeddingCalculationFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${state.error}')),
          );
        }
      },
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildContent(context, state),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: ZenSortTheme.primaryGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
    );
  }

  Widget _buildContent(BuildContext context, YoutubeState state) {
    if (state is EmbeddingCalculationInProgress || state is! EmbeddingCalculationSuccess) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final progress = state.progress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: progress.percentComplete,
          backgroundColor: Colors.grey[300],
          valueColor: const AlwaysStoppedAnimation<Color>(ZenSortTheme.primaryColor),
        ),
        const SizedBox(height: 16),
        Text(
          _getProgressText(progress),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
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
        if (progress.failed > 0) ...[
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Failed'),
              onPressed: () {
                context.read<YouTubeBloc>().add(RetryFailedEmbeddings());
              },
            ),
          ),
        ],
      ],
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
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(75)),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getProgressText(EmbeddingProgress progress) {
    if (progress.total == 0) {
      return 'No videos to process.';
    }
    if (progress.isComplete) {
      return 'Embedding process complete!';
    }
    final percentage = (progress.percentComplete * 100).toStringAsFixed(1);
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
