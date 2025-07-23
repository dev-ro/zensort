part of 'youtube_bloc.dart';

abstract class YoutubeEvent extends Equatable {
  const YoutubeEvent();

  @override
  List<Object> get props => [];
}

class SyncLikedVideos extends YoutubeEvent {}

class _YoutubeSyncProgressUpdated extends YoutubeEvent {
  final SyncProgress progress;

  const _YoutubeSyncProgressUpdated(this.progress);

  @override
  List<Object> get props => [progress];
}

/// Internal event carrying AuthState from AuthBloc to YouTubeBloc
/// Establishes hierarchical flow: Repository -> AuthBloc -> YouTubeBloc
class _AuthStatusChanged extends YoutubeEvent {
  final AuthState authState;

  const _AuthStatusChanged(this.authState);

  @override
  List<Object> get props => [authState];
}
