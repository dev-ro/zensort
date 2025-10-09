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
  final String? selectedTopic;
  final List<String> availableTopics;
  final bool isFullyLoaded;

  const YoutubeLoaded({
    required this.shelves,
    required this.allVideos,
    this.unlikedVideos = const [],
    required this.searchQuery,
    this.hasMore = false,
    this.loadingMore = false,
    this.nextCursor,
    this.expandedShelfKey,
    this.selectedTopic,
    this.availableTopics = const [],
    this.isFullyLoaded = false,
  });

  factory YoutubeLoaded.initial() => const YoutubeLoaded(
    shelves: [],
    allVideos: [],
    unlikedVideos: [],
    searchQuery: '',
    hasMore: false,
    loadingMore: false,
    expandedShelfKey: null,
    selectedTopic: null,
    availableTopics: [],
    isFullyLoaded: false,
  );

  // Serialization methods for hydrated_bloc
  factory YoutubeLoaded.fromJson(Map<String, dynamic> json) {
    // Persist only searchQuery to restore UI intent; videos come from repository stream.
    final query = (json['searchQuery'] as String?) ?? '';
    return YoutubeLoaded(
      shelves: const [],
      allVideos: const [],
      unlikedVideos: const [],
      searchQuery: query,
      hasMore: false,
      loadingMore: false,
      expandedShelfKey: json['expandedShelfKey'] as String?,
      selectedTopic: json['selectedTopic'] as String?,
      availableTopics: const [],
      isFullyLoaded: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'searchQuery': searchQuery,
      if (expandedShelfKey != null) 'expandedShelfKey': expandedShelfKey,
      if (selectedTopic != null) 'selectedTopic': selectedTopic,
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
    String? selectedTopic,
    List<String>? availableTopics,
    bool? isFullyLoaded,
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
      selectedTopic: selectedTopic ?? this.selectedTopic,
      availableTopics: availableTopics ?? this.availableTopics,
      isFullyLoaded: isFullyLoaded ?? this.isFullyLoaded,
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
  ];
}

class YoutubeAllLoading extends YoutubeState {
  final int loadedCount;
  final int? totalCount;

  const YoutubeAllLoading({required this.loadedCount, this.totalCount});

  double get progress =>
      (totalCount == null || totalCount == 0) ? 0 : (loadedCount / totalCount!).clamp(0, 1);

  @override
  List<Object?> get props => [loadedCount, totalCount];
}

class YoutubeFailure extends YoutubeState {
  final String error;

  const YoutubeFailure(this.error);

  @override
  List<Object> get props => [error];
}
