part of 'youtube_bloc.dart';

abstract class YouTubeEvent extends Equatable {
  const YouTubeEvent();

  @override
  List<Object> get props => [];
}

class GetMyLikedVideos extends YouTubeEvent {}

class SyncMyLikedVideos extends YouTubeEvent {
  final String accessToken;

  const SyncMyLikedVideos(this.accessToken);

  @override
  List<Object> get props => [accessToken];
}
