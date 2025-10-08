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

  const YoutubeLoaded({required this.shelves});

  // Serialization methods for hydrated_bloc
  factory YoutubeLoaded.fromJson(Map<String, dynamic> json) {
    // This will need to be adjusted if you intend to persist shelves.
    // For now, we'll deserialize to an empty list of shelves as a placeholder,
    // because the primary goal is UI structure, not state persistence of shelves.
    return const YoutubeLoaded(shelves: []);
  }

  Map<String, dynamic> toJson() {
    // This will need to be adjusted if you intend to persist shelves.
    // For now, returning an empty map as we are not persisting shelves yet.
    return {'shelves': []};
  }

  @override
  List<Object?> get props => [shelves];
}

class YoutubeFailure extends YoutubeState {
  final String error;

  const YoutubeFailure(this.error);

  @override
  List<Object> get props => [error];
}
