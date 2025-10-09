import 'package:equatable/equatable.dart';

class EmbeddingProgress extends Equatable {
  final int total;
  final int completed;
  final int failed;
  final int pending;
  final DateTime? lastUpdated;

  const EmbeddingProgress({
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    this.pending = 0,
    this.lastUpdated,
  });

  bool get isComplete {
    if (total == 0) return true;
    return pending <= 0 && (completed + failed) >= total;
  }

  double get percentComplete {
    if (total == 0) return 1.0;
    final ratio = completed / total;
    if (ratio < 0) return 0.0;
    if (ratio > 1) return 1.0;
    return ratio;
  }

  EmbeddingProgress copyWith({
    int? total,
    int? completed,
    int? failed,
    int? pending,
    DateTime? lastUpdated,
  }) {
    return EmbeddingProgress(
      total: total ?? this.total,
      completed: completed ?? this.completed,
      failed: failed ?? this.failed,
      pending: pending ?? this.pending,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory EmbeddingProgress.fromMap(Map<String, dynamic> map) {
    DateTime? parsed;
    final raw = map['last_updated'];
    if (raw != null) {
      if (raw is DateTime) {
        parsed = raw.toUtc();
      } else if (raw is String) {
        try {
          parsed = DateTime.parse(raw).toUtc();
        } catch (_) {
          parsed = null;
        }
      } else {
        // Support Firestore Timestamp without importing it in domain layer
        final tsSecs = (raw is Map && raw['seconds'] is int) ? raw['seconds'] as int : null;
        final tsNanos = (raw is Map && raw['nanoseconds'] is int) ? raw['nanoseconds'] as int : null;
        if (tsSecs != null) {
          parsed = DateTime.fromMillisecondsSinceEpoch(
            (tsSecs * 1000) + ((tsNanos ?? 0) ~/ 1000000),
            isUtc: true,
          );
        }
      }
    }

    final total = (map['total'] as num?)?.toInt() ?? 0;
    final completed = (map['completed'] as num?)?.toInt() ?? 0;
    final failed = (map['failed'] as num?)?.toInt() ?? 0;
    final pending = (map['pending'] as num?)?.toInt() ?? (total - completed - failed).clamp(0, total);

    return EmbeddingProgress(
      total: total,
      completed: completed,
      failed: failed,
      pending: pending,
      lastUpdated: parsed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'completed': completed,
      'failed': failed,
      'pending': pending,
      if (lastUpdated != null) 'last_updated': lastUpdated!.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [total, completed, failed, pending, lastUpdated];
}


