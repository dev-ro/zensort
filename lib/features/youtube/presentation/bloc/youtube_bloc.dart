import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:rxdart/rxdart.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';
import 'package:zensort/features/youtube/domain/entities/video_shelf.dart';

part 'youtube_event.dart';
part 'youtube_state.dart';

EventTransformer<E> _debounceRestartable<E>(Duration duration) {
  return (events, mapper) {
    return events.debounceTime(duration).switchMap(mapper);
  };
}

class YouTubeBloc extends HydratedBloc<YoutubeEvent, YoutubeState> {
  final YoutubeRepository _youtubeRepository;
  final AuthBloc _authBloc;
  StreamSubscription<SyncProgress>? _syncProgressSubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  StreamSubscription<List<LikedVideo>>? _likedVideosSubscription;

  // Boolean latch to prevent race conditions from rapid auth state emissions
  bool _isInitialLoadDispatched = false;

  // Flag to track if we need to check for empty videos and auto-sync
  bool _shouldCheckForAutoSync = false;

  // Verify remote total vs local only once per session
  bool _hasVerifiedRemoteTotal = false;

  YouTubeBloc(this._youtubeRepository, this._authBloc)
    : super(YoutubeInitial()) {
    on<SyncLikedVideos>(_onSyncLikedVideos);
    on<LoadInitialVideos>(_onLoadInitialVideos);
    on<LoadMoreAllVideos>(_onLoadMoreAllVideos, transformer: droppable());
    on<_YoutubeSyncProgressUpdated>(_onYoutubeSyncProgressUpdated);
    on<_AuthStatusChanged>(_onAuthStatusChanged, transformer: restartable());
    on<_LikedVideosUpdated>(_onLikedVideosUpdated);
    on<_LikedVideosError>(_onLikedVideosError);
    on<SearchQueryChanged>(
      _onSearchQueryChanged,
      transformer: _debounceRestartable(const Duration(milliseconds: 250)),
    );
    on<ShelfExpansionChanged>(_onShelfExpansionChanged);
    on<LoadAllVideosForSearch>(_onLoadAllVideosForSearch, transformer: droppable());
    on<TopicFilterChanged>(_onTopicFilterChanged,
        transformer: _debounceRestartable(const Duration(milliseconds: 150)));

    // Listen to AuthBloc's stable authentication state (hierarchical flow)
    // Repository -> AuthBloc -> YouTubeBloc
    _authStateSubscription = _authBloc.stream.listen((authState) {
      add(_AuthStatusChanged(authState));
    });

    // Check current auth state immediately when BLoC starts
    add(_AuthStatusChanged(_authBloc.state));
  }

  void _onAuthStatusChanged(
    _AuthStatusChanged event,
    Emitter<YoutubeState> emit,
  ) async {
    final authState = event.authState;
    print('=== YouTubeBloc._onAuthStatusChanged ===');
    print('Auth state: ${authState.runtimeType}');
    print('Initial load dispatched: $_isInitialLoadDispatched');

    if (authState is Authenticated &&
        authState.accessToken != null &&
        !_isInitialLoadDispatched) {
      print(
        'User authenticated with access token - setting up streams and triggering initial load',
      );
      _isInitialLoadDispatched = true;
      _shouldCheckForAutoSync =
          true; // Flag to check for auto-sync on first stream emission

      emit(YoutubeLoading());

      // Cancel existing subscriptions
      _syncProgressSubscription?.cancel();
      _likedVideosSubscription?.cancel();

      // Set up sync progress monitoring
      _syncProgressSubscription = _youtubeRepository
          .getSyncProgressStream()
          .listen(
            (progress) => add(_YoutubeSyncProgressUpdated(progress)),
            onError: (error) {
              print('Sync progress stream error: $error');
              emit(YoutubeFailure(error.toString()));
            },
          );

      // Set up reactive liked videos stream
      // The _onLikedVideosUpdated handler will check _shouldCheckForAutoSync flag
      // and trigger sync if videos are empty on first emission
      _likedVideosSubscription = _youtubeRepository.watchLikedVideos().listen(
        (videos) {
          print('watchLikedVideos stream emitted ${videos.length} videos');
          add(_LikedVideosUpdated(videos));
        },
        onError: (error) {
          print('Liked videos stream error: $error');
          add(_LikedVideosError(error.toString()));
        },
      );
    } else if (authState is AuthUnauthenticated) {
      print('User unauthenticated - clearing state and resetting latch');
      // Reset the latches when user becomes unauthenticated
      _isInitialLoadDispatched = false;
      _shouldCheckForAutoSync = false;
      _hasVerifiedRemoteTotal = false;

      // Clear state and cancel subscriptions
      _syncProgressSubscription?.cancel();
      _likedVideosSubscription?.cancel();
      _syncProgressSubscription = null;
      _likedVideosSubscription = null;
      emit(YoutubeInitial());
    }
    // Ignore AuthLoading, AuthInitial, and AuthError states
  }

  Future<void> _onSyncLikedVideos(
    SyncLikedVideos event,
    Emitter<YoutubeState> emit,
  ) async {
    try {
      print('=== YouTubeBloc._onSyncLikedVideos() called ===');
      print('Calling repository syncLikedVideos()...');
      await _youtubeRepository.syncLikedVideos();
      print('Repository syncLikedVideos() completed');
      emit(YoutubeSyncSuccess());
    } catch (e) {
      print('Error calling sync function: $e');
      print('Stack trace: ${StackTrace.current}');
      // Non-destructive: surface failure then restore last loaded shelves
      final lastLoaded = state is YoutubeLoaded ? state as YoutubeLoaded : null;
      emit(YoutubeFailure('Video sync failed: $e'));
      if (lastLoaded != null) {
        emit(lastLoaded);
      }
    }
  }

  Future<void> _onLoadInitialVideos(
    LoadInitialVideos event,
    Emitter<YoutubeState> emit,
  ) async {
    print('=== YouTubeBloc._onLoadInitialVideos() called ===');
    // Trigger auth state check which will set up streams and sync if needed
    add(_AuthStatusChanged(_authBloc.state));
  }

  void _onYoutubeSyncProgressUpdated(
    _YoutubeSyncProgressUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    final progress = event.progress;
    print('=== YouTubeBloc._onYoutubeSyncProgressUpdated ===');
    print('Progress status: ${progress.status}');
    print('Synced: ${progress.syncedCount}, Total: ${progress.totalCount}');

    if (progress.status == SyncStatus.in_progress) {
      emit(YoutubeSyncProgress(progress.syncedCount, progress.totalCount));
    } else if (progress.status == SyncStatus.completed) {
      print('Sync completed! Emitting YoutubeSyncSuccess');
      emit(YoutubeSyncSuccess());
    } else if (progress.status == SyncStatus.failed) {
      print('Sync failed! Emitting YoutubeFailure but preserving UI');
      final lastLoaded = state is YoutubeLoaded ? state as YoutubeLoaded : null;
      emit(const YoutubeFailure('Video sync failed.'));
      if (lastLoaded != null) {
        emit(lastLoaded);
      }
    }
  }

  List<VideoShelf> _buildBaseShelves(List<LikedVideo> allVideos) {
    final shelves = <VideoShelf>[];
    if (allVideos.isNotEmpty) {
      shelves.add(VideoShelf(title: 'All Videos', videos: allVideos));
    }

    // Group by categoryTitle
    final Map<String, List<LikedVideo>> byCategory = {};
    for (final v in allVideos) {
      final title = (v.categoryTitle ?? '').trim();
      if (title.isEmpty) continue;
      byCategory.putIfAbsent(title, () => <LikedVideo>[]).add(v);
    }
    for (final entry in byCategory.entries) {
      if (entry.value.isNotEmpty) {
        shelves.add(VideoShelf(title: entry.key, videos: entry.value));
      }
    }

    // Special shelves remain
    final unavailableVideos = allVideos
        .where((v) => v.title == 'Private video' || v.title == 'Deleted video')
        .toList();
    if (unavailableVideos.isNotEmpty) {
      shelves.add(
        VideoShelf(title: 'Unavailable Videos', videos: unavailableVideos),
      );
    }
    final legacyMusic = allVideos
        .where((v) => v.channelName == 'Music Library Uploads')
        .toList();
    if (legacyMusic.isNotEmpty) {
      shelves.add(
        VideoShelf(title: 'Legacy Music Uploads', videos: legacyMusic),
      );
    }
    return shelves;
  }

  List<String> _deriveAvailableTopics(List<LikedVideo> videos) {
    final set = <String>{};
    for (final v in videos) {
      for (final tag in v.topicTags) {
        final t = tag.trim();
        if (t.isNotEmpty) set.add(t);
      }
    }
    final list = set.toList()..sort();
    return list;
  }

  List<LikedVideo> _filterVideos(List<LikedVideo> allVideos, String query) {
    if (query.trim().isEmpty) return allVideos;
    final q = query.toLowerCase();
    return allVideos
        .where(
          (v) =>
              v.title.toLowerCase().contains(q) ||
              v.channelName.toLowerCase().contains(q) ||
              v.topicTags.any((t) => t.toLowerCase().contains(q)),
        )
        .toList();
  }

  void _verifyTotalsOnceAsync(int initialPageCount) {
    if (_hasVerifiedRemoteTotal) return;
    _hasVerifiedRemoteTotal = true;
    // Fire and forget check
    Future(() async {
      try {
        // Use aggregate local count, not the limited page size
        final remoteTotal = await _youtubeRepository
            .fetchRemoteLikedVideosTotal();
        final localTotal = await _youtubeRepository
            .fetchLocalLikedVideosCount();
        print(
          'Remote liked total: $remoteTotal, local total: $localTotal, initial page: $initialPageCount',
        );
        // Only trigger when local is zero or the gap is meaningful (>= 5)
        if (localTotal == 0 || (remoteTotal - localTotal) >= 5) {
          print('Meaningful mismatch detected; triggering auto-sync');
          add(SyncLikedVideos());
        }
      } catch (e) {
        print('Error verifying remote total: $e');
      }
    });
  }

  void _onLikedVideosUpdated(
    _LikedVideosUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    print('=== YouTubeBloc._onLikedVideosUpdated ===');
    print('Received ${event.videos.length} videos from stream');
    print('Should check for auto-sync: $_shouldCheckForAutoSync');

    if (event.videos.isNotEmpty) {
      print('First video: ${event.videos.first.title}');
    }

    // Check if this is the first stream emission and we need to auto-sync
    if (_shouldCheckForAutoSync) {
      _shouldCheckForAutoSync = false; // Reset flag after first check

      if (event.videos.isEmpty) {
        print(
          'No existing videos found on first stream emission, triggering automatic sync...',
        );
        add(SyncLikedVideos());
        // Don't emit a loaded state here, wait for sync to provide videos
        return;
      }
    }

    // Verify totals once even if we have local data
    _verifyTotalsOnceAsync(event.videos.length);

    final currentQuery = state is YoutubeLoaded
        ? (state as YoutubeLoaded).searchQuery
        : '';
    final allVideos = event.videos;

    if (currentQuery.isEmpty) {
      final shelves = _buildBaseShelves(allVideos);
      emit(
        YoutubeLoaded(
          shelves: shelves,
          allVideos: allVideos,
          searchQuery: '',
          // We don't know hasMore until we fetch a page cursor; start optimistic
          hasMore: true,
          loadingMore: false,
          availableTopics: _deriveAvailableTopics(allVideos),
        ),
      );
    } else {
      final filtered = _filterVideos(allVideos, currentQuery);
      final shelves = <VideoShelf>[
        VideoShelf(title: 'Search Results', videos: filtered),
      ];
      emit(
        YoutubeLoaded(
          shelves: shelves,
          allVideos: allVideos,
          searchQuery: currentQuery,
          hasMore: true,
          loadingMore: false,
          availableTopics: _deriveAvailableTopics(allVideos),
        ),
      );
    }
  }

  Future<void> _onLoadMoreAllVideos(
    LoadMoreAllVideos event,
    Emitter<YoutubeState> emit,
  ) async {
    final current = state is YoutubeLoaded ? state as YoutubeLoaded : null;
    if (current == null) return;
    if (current.loadingMore || !current.hasMore) return;

    emit(current.copyWith(loadingMore: true));
    try {
      final fallbackCursor =
          current.nextCursor ??
          (current.allVideos.isNotEmpty ? current.allVideos.last.id : null);
      final page = await _youtubeRepository.fetchLikedVideosPage(
        startAfterId: fallbackCursor,
        limit: 100,
      );

      final merged = List<LikedVideo>.from(current.allVideos)
        ..addAll(page.videos);
      final shelves = _buildBaseShelves(merged);
      emit(
        current.copyWith(
          allVideos: merged,
          shelves: shelves,
          hasMore: page.hasMore,
          nextCursor: page.nextCursor,
          loadingMore: false,
        ),
      );
    } catch (e) {
      print('LoadMoreAllVideos failed: $e');
      // Non-destructive; stop loading but keep state
      emit(current.copyWith(loadingMore: false));
    }
  }

  void _onSearchQueryChanged(
    SearchQueryChanged event,
    Emitter<YoutubeState> emit,
  ) {
    final query = event.query;
    final currentLoaded = state is YoutubeLoaded
        ? state as YoutubeLoaded
        : YoutubeLoaded.initial();
    final allVideos = currentLoaded.allVideos;

    if (query.isEmpty) {
      final shelves = _buildBaseShelves(allVideos);
      emit(currentLoaded.copyWith(shelves: shelves, searchQuery: ''));
    } else {
      final filtered = _filterVideos(allVideos, query);
      final shelves = <VideoShelf>[
        VideoShelf(title: 'Search Results', videos: filtered),
      ];
      emit(currentLoaded.copyWith(shelves: shelves, searchQuery: query));
      // Trigger full load if not fully loaded
      if (!currentLoaded.isFullyLoaded) {
        add(LoadAllVideosForSearch());
      }
    }
  }

  Future<void> _onLoadAllVideosForSearch(
    LoadAllVideosForSearch event,
    Emitter<YoutubeState> emit,
  ) async {
    final current = state is YoutubeLoaded ? state as YoutubeLoaded : null;
    if (current == null) return;
    await emit.forEach<List<LikedVideo>>(
      _youtubeRepository.fetchAllLikedVideosBatched(pageSize: 200),
      onData: (videos) {
        final query = current.searchQuery;
        final filtered = query.isEmpty ? videos : _filterVideos(videos, query);
        final shelves = <VideoShelf>[
          if (query.isNotEmpty)
            VideoShelf(title: 'Search Results', videos: filtered)
          else
            ..._buildBaseShelves(videos),
        ];
        return current.copyWith(
          allVideos: videos,
          shelves: shelves,
          isFullyLoaded: true,
          availableTopics: _deriveAvailableTopics(videos),
        );
      },
      onError: (_, __) => current,
    );
  }

  void _onShelfExpansionChanged(
    ShelfExpansionChanged event,
    Emitter<YoutubeState> emit,
  ) {
    final current = state is YoutubeLoaded ? state as YoutubeLoaded : YoutubeLoaded.initial();
    emit(current.copyWith(expandedShelfKey: event.shelfKey));
  }

  void _onTopicFilterChanged(
    TopicFilterChanged event,
    Emitter<YoutubeState> emit,
  ) {
    final current = state is YoutubeLoaded ? state as YoutubeLoaded : YoutubeLoaded.initial();
    final topic = event.topic;
    final all = current.allVideos;
    if (topic == null || topic.isEmpty) {
      final shelves = _buildBaseShelves(all);
      emit(current.copyWith(shelves: shelves, selectedTopic: null));
      return;
    }
    // Filter by topicTags
    final lowered = topic.toLowerCase();
    final filtered = all.where((v) => v.topicTags.any((t) => t.toLowerCase() == lowered)).toList();
    final shelves = <VideoShelf>[
      VideoShelf(title: 'Filtered by $topic', videos: filtered),
    ];
    emit(current.copyWith(shelves: shelves, selectedTopic: topic));
  }

  /// Handles stream errors from repository
  /// SAFE: emit() called within event handler context
  void _onLikedVideosError(
    _LikedVideosError event,
    Emitter<YoutubeState> emit,
  ) {
    print('=== YouTubeBloc._onLikedVideosError ===');
    print('Error: ${event.message}');
    emit(YoutubeFailure(event.message));
  }

  @override
  Future<void> close() {
    _syncProgressSubscription?.cancel();
    _authStateSubscription?.cancel();
    _likedVideosSubscription?.cancel();
    return super.close();
  }

  // HydratedBloc serialization methods
  @override
  YoutubeState? fromJson(Map<String, dynamic> json) {
    try {
      final stateType = json['stateType'] as String?;
      if (stateType == 'YoutubeLoaded') {
        return YoutubeLoaded.fromJson(json);
      }
      // For other states, return null to use default initial state
      return null;
    } catch (_) {
      // If deserialization fails, return null to use default initial state
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(YoutubeState state) {
    if (state is YoutubeLoaded) {
      return {'stateType': 'YoutubeLoaded', ...state.toJson()};
    }
    // Only persist YoutubeLoaded states, ignore others
    return null;
  }
}
