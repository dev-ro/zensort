import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_list_item.dart';
import 'package:zensort/theme.dart';
import 'package:zensort/widgets/gradient_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Dispatch the initial videos load event
    context.read<YouTubeBloc>().add(InitialVideosLoaded());
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_isBottom) {
      // Dispatch more videos load event for infinite scroll
      context.read<YouTubeBloc>().add(MoreVideosLoaded());
    }
  }

  bool get _isBottom {
    if (!_scrollController.hasClients) return false;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    return currentScroll >= (maxScroll * 0.9); // Trigger when 90% scrolled
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
                : () {
                    try {
                      print(
                        'Sync button pressed. Current Auth State: ${context.read<AuthBloc>().state}',
                      );
                      final authState = context.read<AuthBloc>().state;
                      if (authState is Authenticated) {
                        print(
                          'Auth state is Authenticated. Access token available: ${authState.accessToken != null}',
                        );
                        print(
                          'Payload being sent to sync: access_token available = ${authState.accessToken != null}',
                        );
                        if (authState.accessToken != null) {
                          print(
                            'Access token first 20 chars: ${authState.accessToken!.substring(0, 20)}...',
                          );
                        }
                        print(
                          'Dispatching SyncLikedVideos event to YouTubeBloc...',
                        );
                        context.read<YouTubeBloc>().add(SyncLikedVideos());
                      } else {
                        print(
                          'Auth state is NOT Authenticated. Doing nothing.',
                        );
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
            return ListView.builder(
              controller: _scrollController,
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
            );
          }
          return const Center(child: Text('Welcome! Please sync your videos.'));
        },
      ),
    );
  }
}
