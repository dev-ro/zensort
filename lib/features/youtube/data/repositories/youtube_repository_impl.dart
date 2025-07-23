import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
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

    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User is not authenticated.");
    }

    print(
      'Payload being sent: {access_token: ${accessToken.substring(0, 20)}..., user_id: ${user.uid}}',
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
    final syncResult = await syncCallable.call({
      'access_token': accessToken,
      'user_id': user.uid,
    });
    final syncedVideos = syncResult.data['synced'];
    print('Videos synced: $syncedVideos');
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

  /// A utility function that splits a list into chunks of a specified size.
  List<List<T>> _partition<T>(List<T> list, int size) {
    if (size <= 0) {
      throw ArgumentError('Size must be positive');
    }
    final parts = <List<T>>[];
    final listLength = list.length;
    for (var i = 0; i < listLength; i += size) {
      final end = (i + size < listLength) ? i + size : listLength;
      parts.add(list.sublist(i, end));
    }
    return parts;
  }

  @override
  Stream<List<LikedVideo>> watchLikedVideos() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Create stream of liked video IDs from user's likedVideos subcollection
    final likedVideoIdsStream = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedVideos')
        .orderBy('likedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList());

    // Use switchMap to handle the incoming stream of ID lists
    return likedVideoIdsStream.switchMap((videoIds) {
      // At the start of switchMap callback
      print(
        '=== REPO: switchMap received ${videoIds.length} video IDs: $videoIds',
      );

      // Handle the edge case of an empty list of IDs
      if (videoIds.isEmpty) {
        return Stream.value(<LikedVideo>[]);
      }

      // Partition the incoming list of IDs into chunks of 10
      final idChunks = _partition(videoIds, 10);
      // After partitioning
      print('=== REPO: Partitioned into ${idChunks.length} chunks: $idChunks');

      // For each chunk, create a Future that fetches the corresponding documents
      final futures = idChunks.map((chunk) {
        return _firestore
            .collection('videos')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()
            .then((snapshot) => snapshot.docs);
      }).toList();

      // Before Future.wait
      print('=== REPO: Executing ${futures.length} parallel queries');

      // Use Future.wait to execute all fetch operations in parallel
      return Stream.fromFuture(Future.wait(futures)).map((listOfListOfDocs) {
        // Flatten the nested list
        final flatList = listOfListOfDocs.expand((docList) => docList).toList();

        // In the final map transformation
        print('=== REPO: Firestore returned ${flatList.length} raw documents');

        // Map the raw DocumentSnapshots to our strongly-typed LikedVideo model objects
        final videos = flatList.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return LikedVideo(
            id: doc.id,
            title: data['title'] ?? '',
            channelName: data['channelTitle'] ?? '',
            thumbnailUrl: data['thumbnailUrl'] ?? '',
          );
        }).toList();

        print('=== REPO: Mapped to ${videos.length} LikedVideo objects');

        // Re-order the results to match the original order
        final videosById = {for (var video in videos) video.id: video};
        final orderedVideos = videoIds
            .map((id) => videosById[id])
            .whereType<
              LikedVideo
            >() // Filter out nulls in case a video was deleted
            .toList();

        print('=== REPO: Final ordered result: ${orderedVideos.length} videos');
        print(
          '=== REPO: Video titles: ${orderedVideos.map((v) => v.title).take(3).toList()}...',
        );

        return orderedVideos;
      });
    });
  }
}
