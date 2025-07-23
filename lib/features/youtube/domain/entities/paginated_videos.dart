import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';

class PaginatedVideos extends Equatable {
  final List<LikedVideo> videos;
  final DocumentSnapshot? lastDocument;
  final bool hasMore;

  const PaginatedVideos({
    required this.videos,
    this.lastDocument,
    required this.hasMore,
  });

  @override
  List<Object?> get props => [videos, lastDocument, hasMore];
}
