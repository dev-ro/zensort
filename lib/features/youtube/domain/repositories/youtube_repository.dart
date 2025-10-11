import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/liked_videos_page.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';

abstract class YoutubeRepository {
  Future<void> syncLikedVideos();
  Stream<SyncProgress> getSyncProgressStream();
  Stream<List<LikedVideo>> watchLikedVideos();

  Future<int> fetchRemoteLikedVideosTotal();
  Future<int> fetchLocalLikedVideosCount();

  Future<LikedVideosPage> fetchLikedVideosPage({
    String? startAfterId,
    int limit = 100,
  });

  // Fetch all liked video IDs in pages and join with /videos metadata in chunks
  Stream<List<LikedVideo>> fetchAllLikedVideosBatched({int pageSize = 200});

  // Fetch unliked video IDs and join with /videos metadata
  Future<List<LikedVideo>> fetchUnlikedVideos();

  // Watch embedding progress in real-time
  Stream<EmbeddingProgress> getEmbeddingProgressStream();

  // On-demand embedding calculation
  Future<void> retryFailedEmbeddings();
}
