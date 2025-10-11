import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/presentation/bloc/youtube_bloc.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_search_bar.dart';
import 'package:zensort/features/youtube/presentation/widgets/video_shelf_sliver.dart';
import 'package:zensort/features/youtube/presentation/widgets/responsive_video_grid.dart';
import 'package:zensort/features/youtube/presentation/widgets/full_screen_loading_overlay.dart';
import 'package:zensort/features/youtube/presentation/widgets/embedding_status_sheet.dart';
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
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (_isWaitingForTokenRefresh) {
          if (state is Authenticated && state.accessToken != null) {
            // Token refresh successful - reset flag and trigger sync
            _isWaitingForTokenRefresh = false;
            context.read<YouTubeBloc>().add(SyncLikedVideos());
          } else if (state is AuthError) {
            // Token refresh failed - reset flag and show error
            _isWaitingForTokenRefresh = false;
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
          }
        }
      },
      child: BlocBuilder<YouTubeBloc, YoutubeState>(
        builder: (context, youtubeState) {
          final isSyncing =
              youtubeState is YoutubeSyncProgress ||
              youtubeState is YoutubeSyncing;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Liked Videos'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.analytics),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => BlocProvider.value(
                        value: BlocProvider.of<YouTubeBloc>(context),
                        child: const EmbeddingStatusSheet(),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: isSyncing
                      ? null
                      : () async {
                          try {
                            // Check authentication status from central state authority - AuthBloc
                            final authState = context.read<AuthBloc>().state;

                            if (authState is Authenticated) {
                              if (authState.accessToken != null) {
                                context.read<YouTubeBloc>().add(
                                  SyncLikedVideos(),
                                );
                              } else {
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
                              // User not authenticated
                            }
                          } catch (e) {
                            // Catcherall for errors
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
            body: BlocListener<YouTubeBloc, YoutubeState>(
              listener: (context, state) {
                if (state is YoutubeSyncSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Sync successful!')),
                  );
                  // The reactive stream will automatically update with new videos
                }
                if (state is YoutubeFailure) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('An error occurred: ${state.error}'),
                    ),
                  );
                }
              },
              child: _buildBody(youtubeState),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(YoutubeState state) {
    // Show full-screen overlay when eager loading all videos
    if (state is YoutubeAllLoading) {
      return FullScreenLoadingOverlay(
        loaded: state.loadedCount,
        total: state.totalCount,
      );
    }
    if (state is YoutubeSyncing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const GradientLoader(),
            const SizedBox(height: 16),
            Text(state.message ?? 'Syncing your library...'),
          ],
        ),
      );
    }
    if (state is YoutubeLoading) {
      return const Center(child: GradientLoader());
    }
    if (state is YoutubeInitial) {
      return const Center(
        child: Text('Welcome! Please sync your liked videos.'),
      );
    }
    if (state is YoutubeSyncSuccess) {
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
              state.message ??
                  'Synced ${state.syncedCount} of ${state.totalCount} videos',
            ),
          ),
          const Expanded(child: Center(child: GradientLoader())),
        ],
      );
    }
    if (state is YoutubeLoaded) {
      final isSearching = state.searchQuery.isNotEmpty;
      return Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: VideoSearchBar(),
          ),
          Expanded(
            child: isSearching
                ? ListView(
                    children: [
                      // In search mode, show a single grid of filtered results without shelves
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Search Results',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: state.shelves.isNotEmpty
                            ? ResponsiveVideoGrid(
                                videos: state.shelves.first.videos,
                              )
                            : const SizedBox.shrink(),
                      ),
                      if (state.loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.0),
                          child: Center(child: LinearProgressIndicator()),
                        ),
                    ],
                  )
                : (state.shelves.isEmpty
                      ? const Center(
                          child: Text('No liked videos found. Try syncing!'),
                        )
                      : CustomScrollView(
                          slivers: [
                            // Build slivers for each shelf
                            ...state.shelves.map((shelf) {
                              final isExpanded =
                                  shelf.title == state.expandedShelfKey;
                              return VideoShelfSliver(
                                shelf: shelf,
                                isExpanded: isExpanded,
                                showBusy:
                                    state.activeShelfKey == shelf.title &&
                                    state.activeShelfBusy,
                                onExpansionChanged: (expanded) {
                                  context.read<YouTubeBloc>().add(
                                    ShelfExpansionChanged(
                                      expanded ? shelf.title : null,
                                    ),
                                  );
                                },
                              );
                            }),
                            // Load more indicator
                            if (state.loadingMore)
                              const SliverToBoxAdapter(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                          ],
                        )),
          ),
        ],
      );
    }
    return const Center(child: Text('An unknown state occurred.'));
  }
}
