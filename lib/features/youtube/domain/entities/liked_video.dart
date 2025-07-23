import 'package:equatable/equatable.dart';

class LikedVideo extends Equatable {
  final String id;
  final String title;
  final String channelName;
  final String thumbnailUrl;

  const LikedVideo({
    required this.id,
    required this.title,
    required this.channelName,
    required this.thumbnailUrl,
  });

  // Serialization methods for hydrated_bloc
  factory LikedVideo.fromJson(Map<String, dynamic> json) {
    return LikedVideo(
      id: json['id'] as String,
      title: json['title'] as String,
      channelName: json['channelName'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'channelName': channelName,
      'thumbnailUrl': thumbnailUrl,
    };
  }

  @override
  List<Object?> get props => [id, title, channelName, thumbnailUrl];
}
