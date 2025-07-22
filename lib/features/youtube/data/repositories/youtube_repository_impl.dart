import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

class YoutubeRepositoryImpl implements YoutubeRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuthRepository _authRepository;

  YoutubeRepositoryImpl(this._firestore, this._auth, this._authRepository);

  @override
  Future<void> syncLikedVideos() async {
    try {
      print('=== YouTubeRepositoryImpl.syncLikedVideos() called ===');
      print('Current user: ${_auth.currentUser?.uid}');

      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User is not authenticated.");
      }

      // Get the YouTube access token from the auth repository
      print('Getting access token from auth repository...');
      final accessToken = await _authRepository.getAccessToken();

      if (accessToken == null) {
        throw Exception(
          "YouTube access token not available. Please sign in again.",
        );
      }

      print('Access token obtained, calling Cloud Functions...');
      print('Access token first 20 chars: ${accessToken.substring(0, 20)}...');
      await _syncWithToken(accessToken);
      print('Cloud Function sync completed successfully');
    } catch (e) {
      print('Error in YouTubeRepositoryImpl.syncLikedVideos(): $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  Future<void> _syncWithToken(String accessToken) async {
    print('=== _syncWithToken() called ===');
    print(
      'Payload being sent: {access_token: ${accessToken.substring(0, 20)}...}',
    );

    // First get total count
    print('Calling get_liked_videos_total...');
    final getTotalVideosCallable = FirebaseFunctions.instance.httpsCallable(
      'get_liked_videos_total',
    );
    final totalResult = await getTotalVideosCallable.call({
      'access_token': accessToken,
    });
    final totalVideos = totalResult.data['total'];
    print('Total videos to sync: $totalVideos');

    // Then sync the videos
    print('Calling sync_youtube_liked_videos...');
    final syncCallable = FirebaseFunctions.instance.httpsCallable(
      'sync_youtube_liked_videos',
    );
    final syncResult = await syncCallable.call({'access_token': accessToken});
    final syncedVideos = syncResult.data['synced'];
    print('Videos synced: $syncedVideos');
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
