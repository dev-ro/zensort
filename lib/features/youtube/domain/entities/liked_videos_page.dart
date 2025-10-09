import 'package:equatable/equatable.dart';

import 'package:zensort/features/youtube/domain/entities/liked_video.dart';

class LikedVideosPage extends Equatable {
  final List<LikedVideo> videos;
  final String? nextCursor;
  final bool hasMore;

  const LikedVideosPage({
    required this.videos,
    required this.hasMore,
    this.nextCursor,
  });

  @override
  List<Object?> get props => [videos, nextCursor, hasMore];
}


