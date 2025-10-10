import 'package:flutter_test/flutter_test.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/liked_videos_page.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';
import 'package:zensort/features/youtube/presentation/bloc/embedding_progress_cubit.dart';

// Simple mock implementation for testing
class TestYoutubeRepository implements YoutubeRepository {
  @override
  Stream<EmbeddingProgress> watchEmbeddingProgress() {
    return Stream.value(const EmbeddingProgress(total: 100, completed: 50));
  }

  // Stub implementations for other required methods
  @override
  Future<void> syncLikedVideos() async {}

  @override
  Stream<SyncProgress> getSyncProgressStream() => Stream.empty();

  @override
  Stream<List<LikedVideo>> watchLikedVideos() => Stream.empty();

  @override
  Future<int> fetchRemoteLikedVideosTotal() async => 0;

  @override
  Future<int> fetchLocalLikedVideosCount() async => 0;

  @override
  Future<LikedVideosPage> fetchLikedVideosPage({String? startAfterId, int limit = 100}) async {
    return const LikedVideosPage(videos: [], hasMore: false);
  }

  @override
  Stream<List<LikedVideo>> fetchAllLikedVideosBatched({int pageSize = 200}) => Stream.empty();

  @override
  Future<List<LikedVideo>> fetchUnlikedVideos() async => [];
}

void main() {
  group('EmbeddingProgressCubit', () {
    test('initial state should be default EmbeddingProgress', () async {
      final repository = TestYoutubeRepository();
      final cubit = EmbeddingProgressCubit(repository);
      
      // The cubit should start with default progress
      expect(cubit.state, const EmbeddingProgress());
      
      // Wait a bit for the stream to emit
      await Future.delayed(const Duration(milliseconds: 100));
      
      cubit.close();
    });

    test('should emit progress updates from repository stream', () async {
      final repository = TestYoutubeRepository();
      final cubit = EmbeddingProgressCubit(repository);
      
      // Wait a bit for the stream to emit
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should have received the progress from the test repository
      expect(cubit.state.total, 100);
      expect(cubit.state.completed, 50);
      
      cubit.close();
    });
  });
}