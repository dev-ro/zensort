import 'package:equatable/equatable.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';

class VideoShelf extends Equatable {
  final String title;
  final List<LikedVideo> videos;

  const VideoShelf({required this.title, required this.videos});

  @override
  List<Object?> get props => [title, videos];
}
