import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/liked_videos_page.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

class YoutubeRepositoryImpl implements YoutubeRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final AuthRepository _authRepository;

  YoutubeRepositoryImpl(this._firestore, this._auth, this._authRepository);

  @override
  Future<void> syncLikedVideos() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception("User is not authenticated.");
      }

      // Get the YouTube access token from the auth repository
      final accessToken = await _authRepository.getAccessToken();

      if (accessToken == null) {
        throw Exception(
          "YouTube access token not available. Please sign in again.",
        );
      }

      await _syncWithToken(accessToken);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _syncWithToken(String accessToken) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("User is not authenticated.");
    }

    // First get total count
    final getTotalVideosCallable = FirebaseFunctions.instance.httpsCallable(
      'get_liked_videos_total',
    );
    await getTotalVideosCallable.call({'access_token': accessToken});

    // Then sync the videos
    final syncCallable = FirebaseFunctions.instance.httpsCallable(
      'sync_youtube_liked_videos',
      options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
    );
    await syncCallable.call({'access_token': accessToken, 'user_id': user.uid});
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
            final chunk = ids.sublist(
              i,
              i + 30 > ids.length ? ids.length : i + 30,
            );
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
                  categoryTitle:
                      (data['categoryTitleUS'] as String?) ??
                      (data['categoryTitle'] as String?),
                  topicTags:
                      (data['topicTags'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      const [],
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
            categoryTitle:
                (vdata['categoryTitleUS'] as String?) ??
                (vdata['categoryTitle'] as String?),
            topicTags:
                (vdata['topicTags'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
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
  Stream<List<LikedVideo>> fetchAllLikedVideosBatched({
    int pageSize = 200,
  }) async* {
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
      Query<Map<String, dynamic>> q = likedRef
          .orderBy('likedAt', descending: true)
          .limit(pageSize);
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
              categoryTitle:
                  (vdata['categoryTitleUS'] as String?) ??
                  (vdata['categoryTitle'] as String?),
              topicTags:
                  (vdata['topicTags'] as List<dynamic>?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  const [],
            ),
          );
        }
      }
      // Preserve order
      final byId = {for (final v in pageVideos) v.id: v};
      final ordered = ids
          .map((id) => byId[id])
          .whereType<LikedVideo>()
          .toList();
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
            categoryTitle:
                (vdata['categoryTitleUS'] as String?) ??
                (vdata['categoryTitle'] as String?),
            topicTags:
                (vdata['topicTags'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                const [],
          ),
        );
      }
    }
    return result;
  }

  @override
  Stream<EmbeddingProgress> watchEmbeddingProgress() async* {
    // Yield the first result immediately to avoid a loading lag for the user.
    yield await getEmbeddingProgress();

    // Then, periodically yield subsequent updates. The `async*` stream will
    // naturally pause between yields and will stop producing values if the
    // listener cancels their subscription.
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      yield await getEmbeddingProgress();
    }
  }

  Future<EmbeddingProgress> getEmbeddingProgress() async {
    final user = _auth.currentUser;
    if (user == null) {
      // Return a default progress when user is not authenticated
      return const EmbeddingProgress();
    }

    // 1. Get all liked video IDs for the user
    final likedVideosQuery = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('likedVideos')
        .get();
    final likedVideoIds = likedVideosQuery.docs.map((doc) => doc.id).toSet();

    if (likedVideoIds.isEmpty) {
      return const EmbeddingProgress(
        total: 0,
        completed: 0,
        pending: 0,
        failed: 0,
      );
    }

    // 2. Query the /videos collection in batches for each status
    final total = likedVideoIds.length;
    int completed = 0;
    int pending = 0;
    int failed = 0;
    DateTime? latestUpdate;
    final likedVideoIdsList = likedVideoIds
        .toList(); // Convert once for efficiency

    for (var i = 0; i < likedVideoIdsList.length; i += 30) {
      final chunk = likedVideoIdsList.sublist(
        i,
        i + 30 > likedVideoIdsList.length ? likedVideoIdsList.length : i + 30,
      );

      // Firestore 'in' query is limited to 30 items
      final videosQuery = _firestore
          .collection('videos')
          .where(FieldPath.documentId, whereIn: chunk);

      final videosSnapshot = await videosQuery.get();
      final foundIds = <String>{};

      for (final doc in videosSnapshot.docs) {
        foundIds.add(doc.id);
        final data = doc.data();
        final status = data['embedding_status'] as String?;

        switch (status) {
          case 'complete':
          case 'not_applicable':
            completed++;
            break;
          case 'pending':
            pending++;
            break;
          case 'failed':
            failed++;
            break;
          default:
            // Videos might not have a status yet if sync just happened
            // We can treat them as pending.
            pending++;
            break;
        }

        // Track the latest update timestamp
        final updatedAtTimestamp = data['embedding_updated_at'] as Timestamp?;
        if (updatedAtTimestamp != null) {
          final updatedAt = updatedAtTimestamp.toDate();
          if (latestUpdate == null || updatedAt.isAfter(latestUpdate)) {
            latestUpdate = updatedAt;
          }
        }
      }

      // Account for liked videos not yet present in the /videos collection
      final notFoundCount = chunk.where((id) => !foundIds.contains(id)).length;
      pending += notFoundCount;
    }

    return EmbeddingProgress(
      total: total,
      completed: completed,
      pending: pending,
      failed: failed,
      lastUpdated: latestUpdate,
    );
  }

  @override
  Future<void> retryFailedEmbeddings() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final callable = FirebaseFunctions.instance.httpsCallable(
      'retry_failed_embeddings',
    );
    await callable.call({'user_id': user.uid});
  }
}
