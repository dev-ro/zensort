import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

part 'youtube_event.dart';
part 'youtube_state.dart';

class YouTubeBloc extends Bloc<YouTubeEvent, YouTubeState> {
  final YouTubeRepository _youTubeRepository;

  YouTubeBloc(this._youTubeRepository) : super(YouTubeInitial()) {
    on<GetMyLikedVideos>(_onGetMyLikedVideos);
    on<SyncMyLikedVideos>(_onSyncMyLikedVideos);
  }

  Future<void> _onGetMyLikedVideos(
    GetMyLikedVideos event,
    Emitter<YouTubeState> emit,
  ) async {
    emit(YouTubeLoading());
    try {
      final videos = await _youTubeRepository.getMyLikedVideos();
      emit(YouTubeSuccess(videos));
    } catch (e) {
      emit(YouTubeFailure(e.toString()));
    }
  }

  Future<void> _onSyncMyLikedVideos(
    SyncMyLikedVideos event,
    Emitter<YouTubeState> emit,
  ) async {
    emit(YouTubeSyncInProgress());
    try {
      await _youTubeRepository.syncMyLikedVideos(event.accessToken);
      emit(YouTubeSyncSuccess());
      // After syncing, refresh the video list
      add(GetMyLikedVideos());
    } catch (e) {
      emit(YouTubeFailure(e.toString()));
    }
  }
}
