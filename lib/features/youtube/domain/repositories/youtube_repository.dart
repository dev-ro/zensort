import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';

abstract class YoutubeRepository {
  Future<void> syncLikedVideos();
  Stream<SyncProgress> getSyncProgressStream();
  Stream<List<LikedVideo>> watchLikedVideos();
}
