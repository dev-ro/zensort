import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/paginated_videos.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';

abstract class YoutubeRepository {
  Future<void> syncLikedVideos();
  Stream<SyncProgress> getSyncProgressStream();
  Future<PaginatedVideos> getLikedVideos({DocumentSnapshot? lastVisible});
}
