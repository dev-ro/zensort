import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_search_bar.dart';
import 'package:zensort/features/youtube/presentation/widgets/expandable_video_shelf.dart';
import 'package:zensort/features/youtube/presentation/widgets/responsive_video_grid.dart';
import 'package:zensort/features/youtube/presentation/widgets/topic_filter_menu.dart';
import 'package:zensort/features/youtube/presentation/widgets/loading_all_videos_sheet.dart';
import 'package:zensort/theme.dart';
import 'package:zensort/widgets/gradient_loader.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isWaitingForTokenRefresh = false;

  @override
  void initState() {
    super.initState();
    // Trigger initial load when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<YouTubeBloc>().add(LoadInitialVideos());
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSyncing = context.watch<YouTubeBloc>().state is YoutubeSyncProgress;

    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_isWaitingForTokenRefresh) {
          if (state is Authenticated && state.accessToken != null) {
            // Token refresh successful - reset flag and trigger sync
            _isWaitingForTokenRefresh = false;
            print('Token refreshed! Automatically triggering sync...');
            context.read<YouTubeBloc>().add(SyncLikedVideos());
          } else if (state is AuthError) {
            // Token refresh failed - reset flag and show error
            _isWaitingForTokenRefresh = false;
            print('Token refresh failed: ${state.message}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Failed to refresh YouTube authorization: ${state.message}',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          } else if (state is AuthUnauthenticated) {
            // User became unauthenticated during refresh - reset flag
            _isWaitingForTokenRefresh = false;
            print('User became unauthenticated during token refresh');
          }
        }
      },
      child: Scaffold(
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
                            print(
                              'No access token available. Attempting silent refresh...',
                            );

                            // Set flag to automatically sync after token refresh
                            setState(() {
                              _isWaitingForTokenRefresh = true;
                            });

                            // Show loading feedback to user
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Refreshing YouTube authorization...',
                                ),
                                duration: Duration(seconds: 3),
                              ),
                            );

                            // Trigger a silent token refresh
                            context.read<AuthBloc>().add(
                              RefreshTokenRequested(),
                            );
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
            // Show loading modal when eager loading all videos
            if (state is YoutubeAllLoading) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                enableDrag: false,
                builder: (_) => const LoadingAllVideosSheet(),
              );
            }
            // Close modal when fully loaded
            if (state is YoutubeLoaded && state.isFullyLoaded) {
              Navigator.of(context).maybePop();
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
              final isSearching =
                  state.searchQuery.isNotEmpty ||
                  (state.selectedTopic != null &&
                      state.selectedTopic!.isNotEmpty);
              return Column(
                children: [
                  const VideoSearchBar(),
                  if (state.availableTopics.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TopicFilterMenu(
                        availableTopics: state.availableTopics,
                        selectedTopic: state.selectedTopic,
                        onSelected: (value) => context
                            .read<YouTubeBloc>()
                            .add(TopicFilterChanged(value)),
                      ),
                    ),
                  Expanded(
                    child: isSearching
                        ? ListView(
                            children: [
                              // In search mode, show a single grid of filtered results without shelves
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: Text(
                                  state.selectedTopic != null &&
                                          state.selectedTopic!.isNotEmpty
                                      ? 'Filtered by ${state.selectedTopic}'
                                      : 'Search Results',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                ),
                                child: state.shelves.isNotEmpty
                                    ? ResponsiveVideoGrid(
                                        videos: state.shelves.first.videos,
                                      )
                                    : const SizedBox.shrink(),
                              ),
                              if (state.loadingMore)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0),
                                  child: Center(
                                    child: LinearProgressIndicator(),
                                  ),
                                ),
                            ],
                          )
                        : (state.shelves.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No liked videos found. Try syncing!',
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: state.shelves.length,
                                  itemBuilder: (context, index) {
                                    final shelf = state.shelves[index];
                                    final isExpanded =
                                        shelf.title == state.expandedShelfKey;
                                    return ExpandableVideoShelf(
                                      title: shelf.title,
                                      videos: shelf.videos,
                                      isExpanded: isExpanded,
                                      hasMore: state.hasMore,
                                      isLoading: state.loadingMore,
                                      onExpansionChanged: (expanded) {
                                        context.read<YouTubeBloc>().add(
                                          ShelfExpansionChanged(
                                            expanded ? shelf.title : null,
                                          ),
                                        );
                                      },
                                      onEndReached: () => context
                                          .read<YouTubeBloc>()
                                          .add(LoadMoreAllVideos()),
                                    );
                                  },
                                )),
                  ),
                ],
              );
            }
            return const Center(
              child: Text('Welcome! Please sync your videos.'),
            );
          },
        ),
      ),
    );
  }
}
