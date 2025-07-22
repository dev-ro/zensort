import 'dart:async';

import 'package:bloc/bloc.dart';
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

  YouTubeBloc(this._youtubeRepository) : super(YoutubeInitial()) {
    on<LoadLikedVideos>(_onLoadLikedVideos);
    on<SyncLikedVideos>(_onSyncLikedVideos);
    on<_YoutubeSyncProgressUpdated>(_onYoutubeSyncProgressUpdated);
    on<_LikedVideosUpdated>(_onLikedVideosUpdated);
  }

  void _onLoadLikedVideos(LoadLikedVideos event, Emitter<YoutubeState> emit) {
    _likedVideosSubscription?.cancel();
    _likedVideosSubscription = _youtubeRepository.getLikedVideosStream().listen(
      (videos) => add(_LikedVideosUpdated(videos)),
      onError: (error) => emit(YoutubeFailure(error.toString())),
    );

    _syncProgressSubscription?.cancel();
    _syncProgressSubscription = _youtubeRepository
        .getSyncProgressStream()
        .listen(
          (progress) => add(_YoutubeSyncProgressUpdated(progress)),
          onError: (error) => emit(YoutubeFailure(error.toString())),
        );
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

  void _onLikedVideosUpdated(
    _LikedVideosUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    emit(YoutubeLoaded(event.videos));
  }

  @override
  Future<void> close() {
    _syncProgressSubscription?.cancel();
    _likedVideosSubscription?.cancel();
    return super.close();
  }
}
