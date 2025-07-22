part of 'youtube_bloc.dart';

abstract class YoutubeEvent extends Equatable {
  const YoutubeEvent();

  @override
  List<Object> get props => [];
}

class LoadLikedVideos extends YoutubeEvent {}

class SyncLikedVideos extends YoutubeEvent {}

class _YoutubeSyncProgressUpdated extends YoutubeEvent {
  final SyncProgress progress;

  const _YoutubeSyncProgressUpdated(this.progress);

  @override
  List<Object> get props => [progress];
}

class _LikedVideosUpdated extends YoutubeEvent {
  final List<LikedVideo> videos;

  const _LikedVideosUpdated(this.videos);

  @override
  List<Object> get props => [videos];
}
