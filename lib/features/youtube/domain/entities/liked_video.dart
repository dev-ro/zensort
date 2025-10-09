import 'package:equatable/equatable.dart';

class LikedVideo extends Equatable {
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final bool isMusic;

  const LikedVideo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    this.isMusic = false,
  });

  // Serialization methods for hydrated_bloc
  factory LikedVideo.fromJson(Map<String, dynamic> json) {
    return LikedVideo(
      id: json['id'] as String,
      title: json['title'] as String,
      channelName: json['channelName'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      isMusic: (json['isMusic'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'channelName': channelName,
      'thumbnailUrl': thumbnailUrl,
      'isMusic': isMusic,
    };
  }

  /// Determines if thumbnail loading should be skipped for this video.
  /// Returns true for private, deleted, and music library uploads that
  /// are known to have broken thumbnail URLs.
  bool shouldSkipThumbnailLoad() {
    return title == 'Private video' ||
           title == 'Deleted video' ||
           title == 'Music Library Uploads' ||
           channelName == 'Music Library Uploads';
  }

  @override
  List<Object?> get props => [id, title, channelName, thumbnailUrl, isMusic];
}
