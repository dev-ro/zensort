part of 'youtube_bloc.dart';

abstract class YoutubeState extends Equatable {
  const YoutubeState();

  @override
  List<Object?> get props => [];
}

class YoutubeInitial extends YoutubeState {}

class YoutubeLoading extends YoutubeState {}

class YoutubeSyncProgress extends YoutubeState {
  final int syncedCount;
  final int totalCount;

  const YoutubeSyncProgress(this.syncedCount, this.totalCount);

  @override
  List<Object> get props => [syncedCount, totalCount];
}

class YoutubeSyncSuccess extends YoutubeState {}

class YoutubeLoaded extends YoutubeState {
  final List<LikedVideo> videos;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final DocumentSnapshot? lastDocument;

  const YoutubeLoaded({
    required this.videos,
    this.hasReachedMax = false,
    this.isLoadingMore = false,
    this.lastDocument,
  });

  YoutubeLoaded copyWith({
    List<LikedVideo>? videos,
    bool? hasReachedMax,
    bool? isLoadingMore,
    DocumentSnapshot? lastDocument,
  }) {
    return YoutubeLoaded(
      videos: videos ?? this.videos,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }

  @override
  List<Object?> get props => [
    videos,
    hasReachedMax,
    isLoadingMore,
    lastDocument,
  ];
}

class YoutubeFailure extends YoutubeState {
  final String error;

  const YoutubeFailure(this.error);

  @override
  List<Object> get props => [error];
}
