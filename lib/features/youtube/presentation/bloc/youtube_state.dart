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
  final List<LikedVideo> unlikedVideos;
  final String searchQuery;
  final bool hasMore;
  final bool loadingMore;
  final String? nextCursor;
  final String? expandedShelfKey; // title as key for now
  final bool isFullyLoaded;
  final String? activeShelfKey;
  final bool activeShelfBusy;

  const YoutubeLoaded({
    required this.shelves,
    required this.allVideos,
    this.unlikedVideos = const [],
    required this.searchQuery,
    this.hasMore = false,
    this.loadingMore = false,
    this.nextCursor,
    this.expandedShelfKey,
    this.isFullyLoaded = false,
    this.activeShelfKey,
    this.activeShelfBusy = false,
  });

  factory YoutubeLoaded.initial() => const YoutubeLoaded(
    shelves: [],
    allVideos: [],
    unlikedVideos: [],
    searchQuery: '',
    hasMore: false,
    loadingMore: false,
    expandedShelfKey: null,
    isFullyLoaded: false,
    activeShelfKey: null,
    activeShelfBusy: false,
  );

  // Serialization methods for hydrated_bloc
  factory YoutubeLoaded.fromJson(Map<String, dynamic> json) {
    final query = (json['searchQuery'] as String?) ?? '';
    final expandedShelfKey = json['expandedShelfKey'] as String?;
    final isFullyLoaded = json['isFullyLoaded'] as bool? ?? false;
    
    // Deserialize cached videos if available
    final allVideosJson = json['allVideos'] as List<dynamic>?;
    final allVideos = allVideosJson != null
        ? allVideosJson
            .map((videoJson) => LikedVideo.fromJson(videoJson as Map<String, dynamic>))
            .toList()
        : <LikedVideo>[];
    
    // Build shelves from cached videos if available
    final shelves = allVideos.isNotEmpty
        ? _buildBaseShelvesFromVideos(allVideos)
        : <VideoShelf>[];
    
    return YoutubeLoaded(
      shelves: shelves,
      allVideos: allVideos,
      unlikedVideos: const [],
      searchQuery: query,
      hasMore: false,
      loadingMore: false,
      expandedShelfKey: expandedShelfKey,
      isFullyLoaded: isFullyLoaded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'searchQuery': searchQuery,
      if (expandedShelfKey != null) 'expandedShelfKey': expandedShelfKey,
      'isFullyLoaded': isFullyLoaded,
      if (allVideos.isNotEmpty) 'allVideos': allVideos.map((video) => video.toJson()).toList(),
    };
  }

  YoutubeLoaded copyWith({
    List<VideoShelf>? shelves,
    List<LikedVideo>? allVideos,
    List<LikedVideo>? unlikedVideos,
    String? searchQuery,
    bool? hasMore,
    bool? loadingMore,
    String? nextCursor,
    String? expandedShelfKey,
    bool? isFullyLoaded,
    String? activeShelfKey,
    bool? activeShelfBusy,
  }) {
    return YoutubeLoaded(
      shelves: shelves ?? this.shelves,
      allVideos: allVideos ?? this.allVideos,
      unlikedVideos: unlikedVideos ?? this.unlikedVideos,
      searchQuery: searchQuery ?? this.searchQuery,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      nextCursor: nextCursor ?? this.nextCursor,
      expandedShelfKey: expandedShelfKey ?? this.expandedShelfKey,
      isFullyLoaded: isFullyLoaded ?? this.isFullyLoaded,
      activeShelfKey: activeShelfKey ?? this.activeShelfKey,
      activeShelfBusy: activeShelfBusy ?? this.activeShelfBusy,
    );
  }

  @override
  List<Object?> get props => [
    shelves,
    allVideos,
    searchQuery,
    hasMore,
    loadingMore,
    nextCursor,
    expandedShelfKey,
    activeShelfKey,
    activeShelfBusy,
  ];
}

class YoutubeAllLoading extends YoutubeState {
  final int loadedCount;
  final int? totalCount;

  const YoutubeAllLoading({required this.loadedCount, this.totalCount});

  double get progress => (totalCount == null || totalCount == 0)
      ? 0
      : (loadedCount / totalCount!).clamp(0, 1);

  @override
  List<Object?> get props => [loadedCount, totalCount];
}

class YoutubeFailure extends YoutubeState {
  final String error;

  const YoutubeFailure(this.error);

  @override
  List<Object> get props => [error];
}

// Helper function to build shelves from video list (used in fromJson)
List<VideoShelf> _buildBaseShelvesFromVideos(List<LikedVideo> videos) {
  // This is a simplified version - the full implementation is in youtube_bloc.dart
  // For now, create a single "All Videos" shelf
  return [
    VideoShelf(title: 'All Videos', videos: videos),
  ];
}
