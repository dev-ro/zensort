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
  final List<VideoShelf> shelves;
  final List<LikedVideo> allVideos;
  final String searchQuery;

  const YoutubeLoaded({
    required this.shelves,
    required this.allVideos,
    required this.searchQuery,
  });

  factory YoutubeLoaded.initial() =>
      const YoutubeLoaded(shelves: [], allVideos: [], searchQuery: '');

  // Serialization methods for hydrated_bloc
  factory YoutubeLoaded.fromJson(Map<String, dynamic> json) {
    // Persist only searchQuery to restore UI intent; videos come from repository stream.
    final query = (json['searchQuery'] as String?) ?? '';
    return YoutubeLoaded(
      shelves: const [],
      allVideos: const [],
      searchQuery: query,
    );
  }

  Map<String, dynamic> toJson() {
    return {'searchQuery': searchQuery};
  }

  YoutubeLoaded copyWith({
    List<VideoShelf>? shelves,
    List<LikedVideo>? allVideos,
    String? searchQuery,
  }) {
    return YoutubeLoaded(
      shelves: shelves ?? this.shelves,
      allVideos: allVideos ?? this.allVideos,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  List<Object?> get props => [shelves, allVideos, searchQuery];
}

class YoutubeFailure extends YoutubeState {
  final String error;

  const YoutubeFailure(this.error);

  @override
  List<Object> get props => [error];
}
