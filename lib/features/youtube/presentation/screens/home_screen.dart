import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_list_item.dart';
import 'package:zensort/screens/sync_progress_screen.dart';
import 'package:zensort/theme.dart';
import 'package:zensort/widgets/gradient_loader.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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

                      // Check authentication status from central state authority - AuthBloc
                      final authState = context.read<AuthBloc>().state;

                      if (authState is Authenticated) {
                        print(
                          'User is authenticated. Checking for access token...',
                        );

                        if (authState.accessToken != null) {
                          print(
                            'Access token available. First 20 chars: ${authState.accessToken!.substring(0, 20)}...',
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
              context.read<AuthBloc>().add(SignOutRequested());
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
            // The reactive stream will automatically update with new videos
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
            return ListView.builder(
              itemCount: state.videos.length,
              itemBuilder: (context, index) {
                return VideoListItem(video: state.videos[index]);
              },
            );
          }
          return const Center(child: Text('Welcome! Please sync your videos.'));
        },
      ),
    );
  }
}
