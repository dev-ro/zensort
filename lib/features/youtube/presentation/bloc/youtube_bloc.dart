import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

part 'youtube_event.dart';
part 'youtube_state.dart';

class YouTubeBloc extends Bloc<YoutubeEvent, YoutubeState> {
  final YoutubeRepository _youtubeRepository;
  final AuthBloc _authBloc;
  StreamSubscription<SyncProgress>? _syncProgressSubscription;
  StreamSubscription<AuthState>? _authStateSubscription;

  YouTubeBloc(this._youtubeRepository, this._authBloc)
    : super(YoutubeInitial()) {
    on<InitialVideosLoaded>(_onInitialVideosLoaded);
    on<MoreVideosLoaded>(_onMoreVideosLoaded);
    on<SyncLikedVideos>(_onSyncLikedVideos);
    on<_YoutubeSyncProgressUpdated>(_onYoutubeSyncProgressUpdated);

    // Listen to AuthBloc state changes for automatic data loading
    _authStateSubscription = _authBloc.stream.listen((authState) {
      print('YouTubeBloc received AuthState: ${authState.runtimeType}');
      print('Current YouTubeBloc state: ${state.runtimeType}');
      if (authState is Authenticated && authState.accessToken != null && state is YoutubeInitial) {
        print(
          'User authenticated with access token and YouTubeBloc is initial, loading initial videos...',
        );
        add(InitialVideosLoaded());
      } else if (authState is Authenticated && authState.accessToken != null) {
        print(
          'User authenticated but YouTubeBloc is not initial (${state.runtimeType}), skipping reload...',
        );
      }
    });

    // Also check current auth state in case we're already authenticated
    final currentAuthState = _authBloc.state;
    if (currentAuthState is Authenticated &&
        currentAuthState.accessToken != null &&
        state is YoutubeInitial) {
      print(
        'Already authenticated on YouTubeBloc creation and state is initial, loading initial videos...',
      );
      add(InitialVideosLoaded());
    } else if (currentAuthState is Authenticated && currentAuthState.accessToken != null) {
      print(
        'Already authenticated on YouTubeBloc creation but state is not initial (${state.runtimeType}), skipping load...',
      );
    }
  }

  void _onInitialVideosLoaded(
    InitialVideosLoaded event,
    Emitter<YoutubeState> emit,
  ) async {
    try {
      print('=== YouTubeBloc._onInitialVideosLoaded() called ===');
      emit(YoutubeLoading());

      // Set up sync progress monitoring
      _syncProgressSubscription?.cancel();
      _syncProgressSubscription = _youtubeRepository
          .getSyncProgressStream()
          .listen(
            (progress) => add(_YoutubeSyncProgressUpdated(progress)),
            onError: (error) => emit(YoutubeFailure(error.toString())),
          );

      // Load initial page of videos
      final result = await _youtubeRepository.getLikedVideos();
      print(
        'Initial load completed: ${result.videos.length} videos, hasMore: ${result.hasMore}',
      );

      emit(
        YoutubeLoaded(
          videos: result.videos,
          hasReachedMax: !result.hasMore,
          lastDocument: result.lastDocument,
        ),
      );
    } catch (error) {
      print('Error in _onInitialVideosLoaded: $error');
      emit(YoutubeFailure(error.toString()));
    }
  }

  Future<void> _onMoreVideosLoaded(
    MoreVideosLoaded event,
    Emitter<YoutubeState> emit,
  ) async {
    final currentState = state;
    if (currentState is! YoutubeLoaded ||
        currentState.hasReachedMax ||
        currentState.isLoadingMore) {
      print('Skipping more videos load - invalid state or already loading');
      return;
    }

    try {
      print('=== YouTubeBloc._onMoreVideosLoaded() called ===');
      print(
        'Loading more videos after document: ${currentState.lastDocument?.id}',
      );

      emit(currentState.copyWith(isLoadingMore: true));

      final result = await _youtubeRepository.getLikedVideos(
        lastVisible: currentState.lastDocument,
      );

      print(
        'More videos loaded: ${result.videos.length} videos, hasMore: ${result.hasMore}',
      );

      final allVideos = [...currentState.videos, ...result.videos];

      emit(
        YoutubeLoaded(
          videos: allVideos,
          hasReachedMax: !result.hasMore,
          isLoadingMore: false,
          lastDocument: result.lastDocument,
        ),
      );
    } catch (error) {
      print('Error in _onMoreVideosLoaded: $error');
      emit(currentState.copyWith(isLoadingMore: false));
      emit(YoutubeFailure(error.toString()));
    }
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
      emit(YoutubeFailure('Video sync failed: $e'));
    }
  }

  void _onYoutubeSyncProgressUpdated(
    _YoutubeSyncProgressUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    final progress = event.progress;
    if (progress.status == SyncStatus.in_progress) {
      emit(YoutubeSyncProgress(progress.syncedCount, progress.totalCount));
    } else if (progress.status == SyncStatus.completed) {
      emit(YoutubeSyncSuccess());
    } else if (progress.status == SyncStatus.failed) {
      emit(const YoutubeFailure('Video sync failed.'));
    }
  }

  @override
  Future<void> close() {
    _syncProgressSubscription?.cancel();
    _authStateSubscription?.cancel();
    return super.close();
  }
}
