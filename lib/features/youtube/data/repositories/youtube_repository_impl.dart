import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/liked_videos_page.dart';
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
      options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
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

  @override
  Stream<List<LikedVideo>> watchLikedVideos() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Stream the first 100 IDs, then join to /videos for display fields
    final likedRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedVideos');

    return likedRef
        .orderBy('likedAt', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs.map((d) => d.id).toList();
          if (ids.isEmpty) return <LikedVideo>[];
          // Chunked 'in' queries (<=30 per chunk)
          final List<LikedVideo> results = [];
          for (var i = 0; i < ids.length; i += 30) {
            final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
            final videosSnap = await _firestore
                .collection('videos')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
            for (final doc in videosSnap.docs) {
              final data = doc.data();
              results.add(
                LikedVideo(
                  id: doc.id,
                  title: (data['title'] as String?) ?? '',
                  channelName: (data['channelTitle'] as String?) ?? '',
                  thumbnailUrl: (data['thumbnailUrl'] as String?) ?? '',
                  categoryId: data['categoryId'] as String?,
                  categoryTitle: (data['categoryTitleUS'] as String?) ?? (data['categoryTitle'] as String?),
                ),
              );
            }
          }
          // Preserve original ordering based on liked order
          final byId = {for (final v in results) v.id: v};
          return ids.map((id) => byId[id]).whereType<LikedVideo>().toList();
        });
  }

  @override
  Future<int> fetchRemoteLikedVideosTotal() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    final accessToken = await _authRepository.getAccessToken();
    if (accessToken == null) throw Exception('Missing access token');

    final callable = FirebaseFunctions.instance.httpsCallable(
      'get_liked_videos_total',
    );
    final result = await callable.call({'access_token': accessToken});
    final total = (result.data['total'] as num?)?.toInt() ?? 0;
    return total;
  }

  @override
  Future<int> fetchLocalLikedVideosCount() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      final agg = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .count()
          .get();
      return agg.count ?? 0;
    } catch (_) {
      // Fallback when count() not available
      final snap = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('likedVideos')
          .get();
      return snap.docs.length;
    }
  }

  @override
  Future<LikedVideosPage> fetchLikedVideosPage({
    String? startAfterId,
    int limit = 100,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final likedRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedVideos');

    Query<Map<String, dynamic>> query = likedRef
        .orderBy('likedAt', descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final startDoc = await likedRef.doc(startAfterId).get();
      if (startDoc.exists) {
        query = query.startAfterDocument(startDoc);
      }
    }

    final snapshot = await query.get();
    final docs = snapshot.docs;
    final ids = docs.map((d) => d.id).toList();
    final List<LikedVideo> videos = [];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final videosSnap = await _firestore
          .collection('videos')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final vdoc in videosSnap.docs) {
        final vdata = vdoc.data();
        videos.add(
          LikedVideo(
            id: vdoc.id,
            title: (vdata['title'] as String?) ?? '',
            channelName: (vdata['channelTitle'] as String?) ?? '',
            thumbnailUrl: (vdata['thumbnailUrl'] as String?) ?? '',
            categoryId: vdata['categoryId'] as String?,
            categoryTitle: (vdata['categoryTitleUS'] as String?) ?? (vdata['categoryTitle'] as String?),
          ),
        );
      }
    }
    // Reorder to liked order
    final byId = {for (final v in videos) v.id: v};
    final ordered = ids.map((id) => byId[id]).whereType<LikedVideo>().toList();

    final nextCursor = docs.isNotEmpty ? docs.last.id : null;
    final hasMore = docs.length == limit;

    return LikedVideosPage(
      videos: ordered,
      hasMore: hasMore,
      nextCursor: nextCursor,
    );
  }

  @override
  Stream<List<LikedVideo>> fetchAllLikedVideosBatched({int pageSize = 200}) async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield <LikedVideo>[];
      return;
    }

    final likedRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedVideos');

    String? cursor;
    bool hasMore = true;
    final List<LikedVideo> aggregate = [];

    while (hasMore) {
      Query<Map<String, dynamic>> q = likedRef.orderBy('likedAt', descending: true).limit(pageSize);
      if (cursor != null) {
        final startDoc = await likedRef.doc(cursor).get();
        if (startDoc.exists) {
          q = q.startAfterDocument(startDoc);
        }
      }
      final snap = await q.get();
      final ids = snap.docs.map((d) => d.id).toList();
      if (ids.isEmpty) {
        hasMore = false;
        break;
      }
      // Join to videos in chunks
      final List<LikedVideo> pageVideos = [];
      for (var i = 0; i < ids.length; i += 30) {
        final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
        final vSnap = await _firestore
            .collection('videos')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final vdoc in vSnap.docs) {
          final vdata = vdoc.data();
          pageVideos.add(
            LikedVideo(
              id: vdoc.id,
              title: (vdata['title'] as String?) ?? '',
              channelName: (vdata['channelTitle'] as String?) ?? '',
              thumbnailUrl: (vdata['thumbnailUrl'] as String?) ?? '',
              categoryId: vdata['categoryId'] as String?,
              categoryTitle: (vdata['categoryTitleUS'] as String?) ?? (vdata['categoryTitle'] as String?),
            ),
          );
        }
      }
      // Preserve order
      final byId = {for (final v in pageVideos) v.id: v};
      final ordered = ids.map((id) => byId[id]).whereType<LikedVideo>().toList();
      aggregate.addAll(ordered);
      yield List<LikedVideo>.from(aggregate);

      cursor = snap.docs.isNotEmpty ? snap.docs.last.id : null;
      hasMore = snap.docs.length == pageSize;
    }
  }

  @override
  Future<List<LikedVideo>> fetchUnlikedVideos() async {
    final user = _auth.currentUser;
    if (user == null) return <LikedVideo>[];

    final ref = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('unlikedVideos')
        .orderBy('unlikedAt', descending: true);
    final snap = await ref.get();
    final ids = snap.docs.map((d) => d.id).toList();
    if (ids.isEmpty) return <LikedVideo>[];
    final List<LikedVideo> result = [];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final vSnap = await _firestore
          .collection('videos')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final vdoc in vSnap.docs) {
        final vdata = vdoc.data();
        result.add(
          LikedVideo(
            id: vdoc.id,
            title: (vdata['title'] as String?) ?? '',
            channelName: (vdata['channelTitle'] as String?) ?? '',
            thumbnailUrl: (vdata['thumbnailUrl'] as String?) ?? '',
            categoryId: vdata['categoryId'] as String?,
            categoryTitle: (vdata['categoryTitleUS'] as String?) ?? (vdata['categoryTitle'] as String?),
          ),
        );
      }
    }
    return result;
  }
}
