import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

part 'youtube_event.dart';
part 'youtube_state.dart';

class YouTubeBloc extends Bloc<YoutubeEvent, YoutubeState> {
  final YoutubeRepository _youtubeRepository;
  StreamSubscription<SyncProgress>? _syncProgressSubscription;
  StreamSubscription<List<LikedVideo>>? _likedVideosSubscription;
  DocumentSnapshot? _lastDocument;

  YouTubeBloc(this._youtubeRepository) : super(YoutubeInitial()) {
    on<LoadLikedVideos>(_onLoadLikedVideos);
    on<SyncLikedVideos>(_onSyncLikedVideos);
    on<FetchNextPage>(_onFetchNextPage);
    on<_YoutubeSyncProgressUpdated>(_onYoutubeSyncProgressUpdated);
    on<_LikedVideosUpdated>(_onLikedVideosUpdated);
  }

  void _onLoadLikedVideos(
    LoadLikedVideos event,
    Emitter<YoutubeState> emit,
  ) async {
    try {
      emit(YoutubeLoading());
      _lastDocument = null; // Reset pagination

      _syncProgressSubscription?.cancel();
      _syncProgressSubscription = _youtubeRepository
          .getSyncProgressStream()
          .listen(
            (progress) => add(_YoutubeSyncProgressUpdated(progress)),
            onError: (error) => emit(YoutubeFailure(error.toString())),
          );

            final result = await _youtubeRepository.getLikedVideos();
      _lastDocument = result.lastDocument;
      
      emit(YoutubeLoaded(
        videos: result.videos,
        hasReachedMax: !result.hasMore,
      ));
    } catch (error) {
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

  Future<void> _onFetchNextPage(
    FetchNextPage event,
    Emitter<YoutubeState> emit,
  ) async {
    final currentState = state;
    if (currentState is! YoutubeLoaded ||
        currentState.hasReachedMax ||
        currentState.isLoadingMore) {
      return;
    }

    try {
      emit(currentState.copyWith(isLoadingMore: true));

      final result = await _youtubeRepository.getLikedVideos(
        lastVisible: _lastDocument,
      );
      _lastDocument = result.lastDocument;

      final allVideos = [...currentState.videos, ...result.videos];

      emit(
        YoutubeLoaded(
          videos: allVideos,
          hasReachedMax: !result.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (error) {
      emit(currentState.copyWith(isLoadingMore: false));
      emit(YoutubeFailure(error.toString()));
    }
  }

  void _onLikedVideosUpdated(
    _LikedVideosUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    emit(YoutubeLoaded(videos: event.videos));
  }

  @override
  Future<void> close() {
    _syncProgressSubscription?.cancel();
    _likedVideosSubscription?.cancel();
    return super.close();
  }
}
