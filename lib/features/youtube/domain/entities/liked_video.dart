import 'package:equatable/equatable.dart';

class LikedVideo extends Equatable {
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;
  final String? categoryId;
  final String? categoryTitle;
  final List<String> topicTags;

  const LikedVideo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
    this.categoryId,
    this.categoryTitle,
    this.topicTags = const [],
  });

  // Serialization methods for hydrated_bloc
  factory LikedVideo.fromJson(Map<String, dynamic> json) {
    return LikedVideo(
      id: json['id'] as String,
      title: json['title'] as String,
      channelName: json['channelName'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      categoryId: json['categoryId'] as String?,
      categoryTitle: json['categoryTitle'] as String?,
      topicTags:
          (json['topicTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'channelName': channelName,
      'thumbnailUrl': thumbnailUrl,
      if (categoryId != null) 'categoryId': categoryId,
      if (categoryTitle != null) 'categoryTitle': categoryTitle,
      if (topicTags.isNotEmpty) 'topicTags': topicTags,
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
  List<Object?> get props => [
    id,
    title,
    channelName,
    thumbnailUrl,
    categoryId,
    categoryTitle,
    topicTags,
  ];
}
