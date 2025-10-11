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
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';

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
    on<LoadAllVideosForSearch>(
      _onLoadAllVideosForSearch,
      transformer: droppable(),
    );
    on<LoadUnlikedVideos>(_onLoadUnlikedVideos, transformer: droppable());
    on<LoadAllVideosEager>(_onLoadAllVideosEager, transformer: droppable());
    on<CalculateEmbeddingProgress>(_onCalculateEmbeddingProgress);
    on<RetryFailedEmbeddings>(_onRetryFailedEmbeddings);

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
    if (authState is Authenticated &&
        authState.accessToken != null &&
        !_isInitialLoadDispatched) {
      _isInitialLoadDispatched = true;

      // Immediately transition to a syncing or loading state to give user feedback.
      emit(const YoutubeSyncing('Checking for new videos...'));

      // Cancel any existing subscriptions to prevent artifacts.
      _syncProgressSubscription?.cancel();
      _likedVideosSubscription?.cancel();

      // Set up sync progress monitoring first.
      _syncProgressSubscription = _youtubeRepository
          .getSyncProgressStream()
          .listen(
            (progress) => add(_YoutubeSyncProgressUpdated(progress)),
            onError: (error) {
              emit(YoutubeFailure(error.toString()));
            },
          );

      // *** New Synchronous Sync-then-Load Logic ***
      try {
        final remote = await _youtubeRepository.fetchRemoteLikedVideosTotal();
        final local = await _youtubeRepository.fetchLocalLikedVideosCount();

        if (remote > local) {
          // The UI is already showing YoutubeSyncing or YoutubeSyncProgress.
          // We now await the completion of the sync.
          emit(const YoutubeSyncing('Syncing new videos...'));
          await _youtubeRepository.syncLikedVideos();
          // After a successful sync, we will proceed to load all videos eagerly.
          add(LoadAllVideosEager());
        } else {
          // If no sync is needed, we can move directly to loading all videos.
          add(LoadAllVideosEager());
        }
      } catch (e) {
        // If the sync check or the sync itself fails, emit a failure state.
        // The user can then manually retry.
        emit(YoutubeFailure('Failed to synchronize videos: ${e.toString()}'));
        // Fallback to loading whatever is available locally.
        add(LoadAllVideosEager());
      }

      // Set up the reactive liked videos stream AFTER the sync decision.
      // This stream will now primarily handle real-time UI updates post-initial-load.
      _likedVideosSubscription = _youtubeRepository.watchLikedVideos().listen(
        (videos) {
          add(_LikedVideosUpdated(videos));
          if (!_hasVerifiedRemoteTotal) {
            add(LoadUnlikedVideos());
            _hasVerifiedRemoteTotal = true; // Mark as verified
          }
        },
        onError: (error) {
          add(_LikedVideosError(error.toString()));
        },
      );
    } else if (authState is AuthUnauthenticated) {
      // Reset the latches when user becomes unauthenticated
      _isInitialLoadDispatched = false;
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
      await _youtubeRepository.syncLikedVideos();
      emit(YoutubeSyncSuccess());
    } catch (e) {
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
    // Trigger auth state check which will set up streams and sync if needed
    add(_AuthStatusChanged(_authBloc.state));
  }

  void _onYoutubeSyncProgressUpdated(
    _YoutubeSyncProgressUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    final progress = event.progress;

    if (progress.status == SyncStatus.inProgress) {
      emit(
        YoutubeSyncProgress(
          progress.syncedCount,
          progress.totalCount,
          'Syncing video ${progress.syncedCount} of ${progress.totalCount}...',
        ),
      );
    } else if (progress.status == SyncStatus.completed) {
      emit(YoutubeSyncSuccess());
      // After sync, reload everything eagerly so shelves/search are complete
      add(LoadAllVideosEager());
    } else if (progress.status == SyncStatus.failed) {
      final lastLoaded = state is YoutubeLoaded ? state as YoutubeLoaded : null;
      emit(const YoutubeFailure('Video sync failed.'));
      if (lastLoaded != null) {
        emit(lastLoaded);
      }
    }
  }

  Future<void> _onCalculateEmbeddingProgress(
    CalculateEmbeddingProgress event,
    Emitter<YoutubeState> emit,
  ) async {
    emit(EmbeddingCalculationInProgress());
    try {
      final progress = await _youtubeRepository.calculateEmbeddingProgress();
      emit(EmbeddingCalculationSuccess(progress));
    } catch (e) {
      emit(EmbeddingCalculationFailure(e.toString()));
    }
  }

  Future<void> _onRetryFailedEmbeddings(
    RetryFailedEmbeddings event,
    Emitter<YoutubeState> emit,
  ) async {
    // Possibly emit a state to show retrying is in progress
    try {
      await _youtubeRepository.retryFailedEmbeddings();
      // Re-trigger progress calculation to show updated numbers
      add(CalculateEmbeddingProgress());
    } catch (e) {
      emit(EmbeddingCalculationFailure(e.toString()));
    }
  }

  List<VideoShelf> _buildBaseShelves(List<LikedVideo> allVideos) {
    final shelves = <VideoShelf>[];

    // 1. All Videos shelf (always first)
    if (allVideos.isNotEmpty) {
      shelves.add(VideoShelf(title: 'All Videos', videos: allVideos));
    }

    // 2. Group by categoryTitle
    final Map<String, List<LikedVideo>> byCategory = {};
    for (final v in allVideos) {
      final title = (v.categoryTitle ?? '').trim();
      if (title.isEmpty) continue;
      byCategory.putIfAbsent(title, () => <LikedVideo>[]).add(v);
    }

    // 3. Priority categories in order: Music, Movies, Shows
    final priorityCategories = ['Music', 'Movies', 'Shows'];
    for (final category in priorityCategories) {
      if (byCategory.containsKey(category)) {
        shelves.add(VideoShelf(title: category, videos: byCategory[category]!));
        byCategory.remove(category);
      }
    }

    // 4. Other categories alphabetically
    final otherCategories = byCategory.keys.toList()..sort();
    for (final category in otherCategories) {
      shelves.add(VideoShelf(title: category, videos: byCategory[category]!));
    }

    // 5. Group by topic tags (prefixed with "Topic - ")
    final Map<String, List<LikedVideo>> byTopic = {};
    for (final v in allVideos) {
      for (final tag in v.topicTags) {
        final trimmedTag = tag.trim();
        if (trimmedTag.isNotEmpty) {
          byTopic.putIfAbsent(trimmedTag, () => <LikedVideo>[]).add(v);
        }
      }
    }

    // Add topic shelves alphabetically
    final topicNames = byTopic.keys.toList()..sort();
    for (final topicName in topicNames) {
      shelves.add(
        VideoShelf(title: 'Topic - $topicName', videos: byTopic[topicName]!),
      );
    }

    // 6. Special shelves at the bottom
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
        // Only trigger when local is zero or the gap is meaningful (>= 5)
        if (localTotal == 0 || (remoteTotal - localTotal) >= 5) {
          add(SyncLikedVideos());
        }
      } catch (e) {
        // Silent failure, do not show to user
      }
    });
  }

  void _onLikedVideosUpdated(
    _LikedVideosUpdated event,
    Emitter<YoutubeState> emit,
  ) {
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
        );
      },
      onError: (_, _) => current,
    );
  }

  Future<void> _onLoadAllVideosEager(
    LoadAllVideosEager event,
    Emitter<YoutubeState> emit,
  ) async {
    int loaded = 0;
    int? total;
    List<LikedVideo> latestVideos = const [];
    try {
      // Try to fetch total; ignore failures and use indeterminate mode
      try {
        total = await _youtubeRepository.fetchRemoteLikedVideosTotal();
      } catch (_) {
        total = null;
      }

      await emit.forEach<List<LikedVideo>>(
        _youtubeRepository.fetchAllLikedVideosBatched(pageSize: 200),
        onData: (videos) {
          loaded = videos.length;
          latestVideos = videos;
          // Emit progress state
          return YoutubeAllLoading(loadedCount: loaded, totalCount: total);
        },
        onError: (_, _) =>
            YoutubeAllLoading(loadedCount: loaded, totalCount: total),
      );

      // After stream completes, set fully loaded state while preserving query/filters
      final current = state is YoutubeLoaded
          ? state as YoutubeLoaded
          : YoutubeLoaded.initial();
      final allVideos = latestVideos;
      final query = current.searchQuery;
      final filtered = query.isEmpty
          ? allVideos
          : _filterVideos(allVideos, query);
      final shelves = <VideoShelf>[
        if (query.isNotEmpty)
          VideoShelf(title: 'Search Results', videos: filtered)
        else
          ..._buildBaseShelves(allVideos),
      ];
      emit(
        current.copyWith(
          allVideos: allVideos,
          shelves: shelves,
          isFullyLoaded: true,
        ),
      );
    } catch (e) {
      // On error, fall back to current state
      final current = state is YoutubeLoaded ? state as YoutubeLoaded : null;
      if (current != null) emit(current);
    }
  }

  void _onShelfExpansionChanged(
    ShelfExpansionChanged event,
    Emitter<YoutubeState> emit,
  ) {
    final current = state is YoutubeLoaded
        ? state as YoutubeLoaded
        : YoutubeLoaded.initial();
    final key = event.shelfKey;
    emit(
      current.copyWith(
        expandedShelfKey: key,
        activeShelfKey: key,
        activeShelfBusy: key != null,
      ),
    );
    if (key != null) {
      // Clear the busy flag after the next microtask/frame to allow UI to show a quick indicator
      Future.microtask(() {
        final now = state is YoutubeLoaded ? state as YoutubeLoaded : null;
        if (now != null && now.activeShelfKey == key) {
          emit(now.copyWith(activeShelfBusy: false));
        }
      });
    }
  }

  Future<void> _onLoadUnlikedVideos(
    LoadUnlikedVideos event,
    Emitter<YoutubeState> emit,
  ) async {
    final current = state is YoutubeLoaded
        ? state as YoutubeLoaded
        : YoutubeLoaded.initial();
    try {
      final items = await _youtubeRepository.fetchUnlikedVideos();
      final newShelves = <VideoShelf>[..._buildBaseShelves(current.allVideos)];
      if (items.isNotEmpty) {
        newShelves.add(VideoShelf(title: 'Unliked Videos', videos: items));
      }
      emit(current.copyWith(unlikedVideos: items, shelves: newShelves));
    } catch (_) {
      // ignore
    }
  }

  /// Handles stream errors from repository
  /// SAFE: emit() called within event handler context
  void _onLikedVideosError(
    _LikedVideosError event,
    Emitter<YoutubeState> emit,
  ) {
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
        final result = YoutubeLoaded.fromJson(json);
        return result;
      }
      // For other states, return null to use default initial state
      return null;
    } catch (e) {
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
