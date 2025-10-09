part of 'youtube_bloc.dart';

abstract class YoutubeEvent extends Equatable {
  const YoutubeEvent();

  @override
  List<Object> get props => [];
}

class SyncLikedVideos extends YoutubeEvent {}

class LoadInitialVideos extends YoutubeEvent {}

class LoadMoreAllVideos extends YoutubeEvent {}

class SearchQueryChanged extends YoutubeEvent {
  final String query;
  const SearchQueryChanged(this.query);

  @override
  List<Object> get props => [query];
}

class ShelfExpansionChanged extends YoutubeEvent {
  final String? shelfKey; // title-based key; null means collapse all
  const ShelfExpansionChanged(this.shelfKey);

  @override
  List<Object> get props => [shelfKey ?? ''];
}

class LoadAllVideosForSearch extends YoutubeEvent {}

class TopicFilterChanged extends YoutubeEvent {
  final String? topic; // null clears filter
  const TopicFilterChanged(this.topic);

  @override
  List<Object> get props => [topic ?? ''];
}

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

/// Internal event carrying liked videos from repository stream to YouTubeBloc
/// Follows reactive repository pattern - stream listener adds events instead of calling emit
class _LikedVideosUpdated extends YoutubeEvent {
  final List<LikedVideo> videos;

  const _LikedVideosUpdated(this.videos);

  @override
  List<Object> get props => [videos];
}

/// Internal event carrying stream errors from repository to YouTubeBloc
/// Enables safe error handling through the event system
class _LikedVideosError extends YoutubeEvent {
  final String message;

  const _LikedVideosError(this.message);

  @override
  List<Object> get props => [message];
}
