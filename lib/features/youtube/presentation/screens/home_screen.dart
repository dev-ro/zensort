import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_list_item.dart';
import 'package:zensort/screens/sync_progress_screen.dart';
import 'package:zensort/theme.dart';
import 'package:zensort/widgets/gradient_loader.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  bool _onScrollNotification(
    ScrollNotification notification,
    BuildContext context,
  ) {
    if (notification is ScrollUpdateNotification && notification.depth == 0) {
      final metrics = notification.metrics;
      if (metrics.pixels >= (metrics.maxScrollExtent * 0.9)) {
        // Trigger when 90% scrolled
        context.read<YouTubeBloc>().add(MoreVideosLoaded());
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    bool isSyncing = context.watch<YouTubeBloc>().state is YoutubeSyncProgress;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liked Videos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: isSyncing
                ? null
                : () async {
                    try {
                      print('Sync button pressed.');

                      // Check authentication status directly from repository
                      final authRepository = context.read<AuthRepository>();
                      final currentUser =
                          await authRepository.currentUser.first;

                      if (currentUser != null) {
                        print(
                          'User is authenticated. Checking for access token...',
                        );

                        final accessToken = await authRepository
                            .getAccessToken();
                        if (accessToken != null) {
                          print(
                            'Access token available. First 20 chars: ${accessToken.substring(0, 20)}...',
                          );
                          print(
                            'Dispatching SyncLikedVideos event to YouTubeBloc...',
                          );
                          context.read<YouTubeBloc>().add(SyncLikedVideos());
                        } else {
                          print('No access token available.');
                        }
                      } else {
                        print('User is not authenticated. Cannot sync.');
                      }
                    } catch (e) {
                      print('Error in sync button onPressed: $e');
                      print('Stack trace: ${StackTrace.current}');
                    }
                  },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthRepository>().signOut();
            },
          ),
        ],
      ),
      body: BlocConsumer<YouTubeBloc, YoutubeState>(
        listener: (context, state) {
          if (state is YoutubeSyncSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Sync successful!')));
            // After successful sync, reload the initial videos
            context.read<YouTubeBloc>().add(InitialVideosLoaded());
          }
          if (state is YoutubeFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('An error occurred: ${state.error}')),
            );
          }
        },
        builder: (context, state) {
          if (state is YoutubeLoading || state is YoutubeInitial) {
            return const Center(child: GradientLoader());
          }
          if (state is YoutubeSyncProgress) {
            return Column(
              children: [
                LinearProgressIndicator(
                  value: state.totalCount > 0
                      ? state.syncedCount / state.totalCount
                      : 0,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    ZenSortTheme.primaryColor,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Synced ${state.syncedCount} of ${state.totalCount} videos',
                  ),
                ),
                const Expanded(child: Center(child: GradientLoader())),
              ],
            );
          }
          if (state is YoutubeLoaded) {
            if (state.videos.isEmpty) {
              return const Center(
                child: Text('No liked videos found. Try syncing!'),
              );
            }
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) =>
                  _onScrollNotification(notification, context),
              child: ListView.builder(
                itemCount: state.videos.length + (state.hasReachedMax ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index >= state.videos.length) {
                    // Show loading indicator at the end when more videos are being fetched
                    return state.isLoadingMore
                        ? const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(child: GradientLoader()),
                          )
                        : const SizedBox.shrink();
                  }
                  return VideoListItem(video: state.videos[index]);
                },
              ),
            );
          }
          return const Center(child: Text('Welcome! Please sync your videos.'));
        },
      ),
    );
  }
}
