import 'package:cloud_firestore/cloud_firestore.dart';
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
    return (ratio * 1000).round() / 1000;
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
      if (raw is Timestamp) {
        parsed = raw.toDate();
      } else if (raw is DateTime) {
        parsed = raw.toUtc();
      } else if (raw is String) {
        try {
          parsed = DateTime.parse(raw).toUtc();
        } catch (_) {
          // Ignore parse errors
        }
      }
    }

    final total = (map['total'] as num?)?.toInt() ?? 0;
    final completed = (map['completed'] as num?)?.toInt() ?? 0;
    final failed = (map['failed'] as num?)?.toInt() ?? 0;
    final pending =
        (map['pending'] as num?)?.toInt() ??
        (total - completed - failed).clamp(0, total);

    return EmbeddingProgress(
      total: total,
      completed: completed,
      failed: failed,
      pending: pending,
      lastUpdated: parsed,
    );
  }

  @override
  List<Object?> get props => [total, completed, failed, pending, lastUpdated];
}
