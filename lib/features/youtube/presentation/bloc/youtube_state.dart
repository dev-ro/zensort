part of 'youtube_bloc.dart';

abstract class YouTubeState extends Equatable {
  const YouTubeState();

  @override
  List<Object> get props => [];
}

class YouTubeInitial extends YouTubeState {}

class YouTubeLoading extends YouTubeState {}

class YouTubeSyncInProgress extends YouTubeState {}

class YouTubeSyncSuccess extends YouTubeState {}

class YouTubeSuccess extends YouTubeState {
  final List<LikedVideo> videos;

  const YouTubeSuccess(this.videos);

  @override
  List<Object> get props => [videos];
}

class YouTubeFailure extends YouTubeState {
  final String error;

  const YouTubeFailure(this.error);

  @override
  List<Object> get props => [error];
}
