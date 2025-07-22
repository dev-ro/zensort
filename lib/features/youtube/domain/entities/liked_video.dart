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

  @override
  List<Object?> get props => [id, title, channelName, thumbnailUrl];
}
