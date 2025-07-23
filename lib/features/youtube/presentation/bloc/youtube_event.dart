part of 'youtube_bloc.dart';

abstract class YoutubeEvent extends Equatable {
  const YoutubeEvent();

  @override
  List<Object> get props => [];
}

class InitialVideosLoaded extends YoutubeEvent {}

class MoreVideosLoaded extends YoutubeEvent {}

class SyncLikedVideos extends YoutubeEvent {}

class _YoutubeSyncProgressUpdated extends YoutubeEvent {
  final SyncProgress progress;

  const _YoutubeSyncProgressUpdated(this.progress);

  @override
  List<Object> get props => [progress];
}

class _AuthStatusChanged extends YoutubeEvent {
  final User? user;

  const _AuthStatusChanged(this.user);

  @override
  List<Object> get props => [user ?? 'null'];
}
