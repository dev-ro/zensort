import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

class YoutubeRepositoryImpl implements YoutubeRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  YoutubeRepositoryImpl(this._firestore, this._auth);

  @override
  Future<void> syncLikedVideos() async {
    // This will be triggered by a cloud function,
    // so the client doesn't need to do anything here.
    return;
  }

  @override
  Stream<List<LikedVideo>> getLikedVideosStream() {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedVideoLinks')
        .snapshots()
        .asyncMap((snapshot) async {
          final List<Future<LikedVideo>> futureLikedVideos = [];
          for (var doc in snapshot.docs) {
            final videoId = doc.id;
            futureLikedVideos.add(_getVideoFromId(videoId));
          }
          return await Future.wait(futureLikedVideos);
        });
  }

  @override
  Stream<SyncProgress> getSyncProgressStream() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(const SyncProgress(status: SyncStatus.failed));
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('syncJobs')
        .doc('youtube_liked_videos')
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data() != null) {
            return SyncProgress.fromMap(snapshot.data()!);
          } else {
            return const SyncProgress(status: SyncStatus.none);
          }
        });
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
