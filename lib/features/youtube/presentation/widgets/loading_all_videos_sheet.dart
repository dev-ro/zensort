import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/theme.dart';

class LoadingAllVideosSheet extends StatelessWidget {
  const LoadingAllVideosSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: BlocBuilder<YouTubeBloc, YoutubeState>(
          builder: (context, state) {
            int loaded = 0;
            int? total;
            double? value;
            if (state is YoutubeAllLoading) {
              loaded = state.loadedCount;
              total = state.totalCount;
              value = (total == null || total == 0) ? null : state.progress;
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.video_library,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Loading your library',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'For larger libraries this can take a while. You can keep browsing; shelves and search will populate as data arrives.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: value,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ZenSortTheme.primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                if (total != null)
                  Row(
                    children: [
                      Text('Loaded $loaded of $total'),
                      const Spacer(),
                      Text(
                        '${(((value ?? 0) * 100).clamp(0, 100)).toStringAsFixed(0)}%',
                      ),
                    ],
                  )
                else
                  Text('Loading... ($loaded items so far)'),
              ],
            );
          },
        ),
      ),
    );
  }
}
