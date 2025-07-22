import 'package:zensort/features/youtube/domain/entities/liked_video.dart';

abstract class YouTubeRepository {
  Future<void> syncMyLikedVideos(String accessToken);

  Future<List<LikedVideo>> getMyLikedVideos();
}
