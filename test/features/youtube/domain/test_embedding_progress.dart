import 'package:flutter_test/flutter_test.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';

void main() {
  group('EmbeddingProgress', () {
    test('should create with default values', () {
      const progress = EmbeddingProgress();

      expect(progress.total, 0);
      expect(progress.completed, 0);
      expect(progress.failed, 0);
      expect(progress.pending, 0);
      expect(progress.lastUpdated, null);
    });

    test('should create with custom values', () {
      const progress = EmbeddingProgress(
        total: 100,
        completed: 50,
        failed: 5,
        pending: 45,
        lastUpdated: null,
      );

      expect(progress.total, 100);
      expect(progress.completed, 50);
      expect(progress.failed, 5);
      expect(progress.pending, 45);
      expect(progress.lastUpdated, null);
    });

    group('isComplete', () {
      test('should return true when total is 0', () {
        const progress = EmbeddingProgress(total: 0);
        expect(progress.isComplete, true);
      });

      test(
        'should return true when pending is 0 and completed + failed >= total',
        () {
          const progress = EmbeddingProgress(
            total: 100,
            completed: 80,
            failed: 20,
            pending: 0,
          );
          expect(progress.isComplete, true);
        },
      );

      test('should return false when pending > 0', () {
        const progress = EmbeddingProgress(
          total: 100,
          completed: 50,
          failed: 10,
          pending: 40,
        );
        expect(progress.isComplete, false);
      });

      test('should return false when completed + failed < total', () {
        const progress = EmbeddingProgress(
          total: 100,
          completed: 30,
          failed: 10,
          pending: 0,
        );
        expect(progress.isComplete, false);
      });
    });

    group('percentComplete', () {
      test('should return 1.0 when total is 0', () {
        const progress = EmbeddingProgress(total: 0);
        expect(progress.percentComplete, 1.0);
      });

      test('should return 0.0 when completed is 0', () {
        const progress = EmbeddingProgress(total: 100, completed: 0);
        expect(progress.percentComplete, 0.0);
      });

      test('should return 0.5 when completed is half of total', () {
        const progress = EmbeddingProgress(total: 100, completed: 50);
        expect(progress.percentComplete, 0.5);
      });

      test('should return 1.0 when completed equals total', () {
        const progress = EmbeddingProgress(total: 100, completed: 100);
        expect(progress.percentComplete, 1.0);
      });

      test('should clamp to 0.0 when completed is negative', () {
        const progress = EmbeddingProgress(total: 100, completed: -10);
        expect(progress.percentComplete, 0.0);
      });

      test('should clamp to 1.0 when completed exceeds total', () {
        const progress = EmbeddingProgress(total: 100, completed: 150);
        expect(progress.percentComplete, 1.0);
      });
    });

    group('copyWith', () {
      test('should return new instance with updated values', () {
        const original = EmbeddingProgress(
          total: 100,
          completed: 50,
          failed: 5,
          pending: 45,
        );

        final updated = original.copyWith(completed: 60, failed: 10);

        expect(updated.total, 100);
        expect(updated.completed, 60);
        expect(updated.failed, 10);
        expect(updated.pending, 45);
      });

      test('should return same instance when no changes', () {
        const original = EmbeddingProgress(
          total: 100,
          completed: 50,
          failed: 5,
          pending: 45,
        );

        final updated = original.copyWith();

        expect(updated, original);
      });
    });

    group('fromMap', () {
      test('should parse basic map data', () {
        final map = {'total': 100, 'completed': 50, 'failed': 5, 'pending': 45};

        final progress = EmbeddingProgress.fromMap(map);

        expect(progress.total, 100);
        expect(progress.completed, 50);
        expect(progress.failed, 5);
        expect(progress.pending, 45);
      });

      test('should handle null values with defaults', () {
        final map = <String, dynamic>{};

        final progress = EmbeddingProgress.fromMap(map);

        expect(progress.total, 0);
        expect(progress.completed, 0);
        expect(progress.failed, 0);
        expect(progress.pending, 0);
        expect(progress.lastUpdated, null);
      });

      test('should parse DateTime string', () {
        final now = DateTime.now();
        final map = {'total': 100, 'last_updated': now.toIso8601String()};

        final progress = EmbeddingProgress.fromMap(map);

        expect(progress.lastUpdated, now.toUtc());
      });

      test('should parse Firestore Timestamp format', () {
        final now = DateTime.now();
        final map = {
          'total': 100,
          'last_updated': {
            'seconds': now.millisecondsSinceEpoch ~/ 1000,
            'nanoseconds': (now.microsecondsSinceEpoch % 1000000) * 1000,
          },
        };

        final progress = EmbeddingProgress.fromMap(map);

        expect(progress.lastUpdated, isNotNull);
        expect(
          progress.lastUpdated!.millisecondsSinceEpoch,
          closeTo(now.millisecondsSinceEpoch, 1000),
        );
      });

      test('should calculate pending when not provided', () {
        final map = {'total': 100, 'completed': 30, 'failed': 10};

        final progress = EmbeddingProgress.fromMap(map);

        expect(progress.pending, 60);
      });

      test('should clamp pending to valid range', () {
        final map = {
          'total': 100,
          'completed': 80,
          'failed': 30, // This would make pending negative
        };

        final progress = EmbeddingProgress.fromMap(map);

        expect(progress.pending, 0);
      });
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        const progress1 = EmbeddingProgress(
          total: 100,
          completed: 50,
          failed: 5,
          pending: 45,
        );
        const progress2 = EmbeddingProgress(
          total: 100,
          completed: 50,
          failed: 5,
          pending: 45,
        );

        expect(progress1, progress2);
      });

      test('should not be equal when fields differ', () {
        const progress1 = EmbeddingProgress(total: 100, completed: 50);
        const progress2 = EmbeddingProgress(total: 100, completed: 60);

        expect(progress1, isNot(progress2));
      });
    });
  });
}
