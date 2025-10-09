import 'package:flutter_test/flutter_test.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';

void main() {
  group('EmbeddingProgress', () {
    test('fromMap maps fields and computes helpers', () {
      final map = {
        'total': 100,
        'completed': 30,
        'failed': 5,
        'pending': 65,
        'last_updated': '2025-01-01T00:00:00.000Z',
      };

      final p = EmbeddingProgress.fromMap(map);

      expect(p.total, 100);
      expect(p.completed, 30);
      expect(p.failed, 5);
      expect(p.pending, 65);
      expect(p.isComplete, false);
      expect(p.percentComplete, closeTo(0.30, 0.0001));
    });

    test('handles missing fields with sensible defaults', () {
      final p = EmbeddingProgress.fromMap({});
      expect(p.total, 0);
      expect(p.completed, 0);
      expect(p.failed, 0);
      expect(p.pending, 0);
      expect(p.isComplete, true); // with total 0, consider complete
      expect(p.percentComplete, 1.0);
    });

    test('isComplete true when pending is zero', () {
      final p = EmbeddingProgress.fromMap({
        'total': 10,
        'completed': 8,
        'failed': 2,
        'pending': 0,
      });
      expect(p.isComplete, true);
      expect(p.percentComplete, 1.0);
    });
  });
}


