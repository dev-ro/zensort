import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/youtube/data/services/youtube_api_service.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

class YouTubeRepositoryImpl implements YouTubeRepository {
  final YouTubeApiService _apiService;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  YouTubeRepositoryImpl(this._apiService, this._firestore, this._auth);

  @override
  Future<void> syncMyLikedVideos(String accessToken) async {
    await _apiService.syncLikedVideos(accessToken);
  }

  @override
  Future<List<LikedVideo>> getMyLikedVideos() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final likedVideosSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedVideoLinks')
        .get();

    final List<Future<LikedVideo>> futureLikedVideos = [];
    for (var doc in likedVideosSnapshot.docs) {
      final videoId = doc.id;
      futureLikedVideos.add(_getVideoFromId(videoId));
    }
    return await Future.wait(futureLikedVideos);
  }

  Future<LikedVideo> _getVideoFromId(String videoId) async {
    final videoDoc = await _firestore.collection('videos').doc(videoId).get();
    final data = videoDoc.data();
    if (data == null) {
      throw Exception('Video not found in cache');
    }
    return LikedVideo(
      id: videoId,
      title: data['title'] ?? '',
      channelName: data['channelName'] ?? '',
      thumbnailUrl: data['maxResThumbnailUrl'] ?? '',
    );
  }
}
