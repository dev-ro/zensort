import 'package:equatable/equatable.dart';

class EmbeddingProgress extends Equatable {
  final int total;
  final int completed;
  final int failed;
  final int pending;
  final DateTime? lastUpdated;

  EmbeddingProgress({
    this.total = 0,
    this.completed = 0,
    this.failed = 0,
    int? pending,
    this.lastUpdated,
  }) : pending = pending ?? (total - completed - failed).clamp(0, total);

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

  @override
  List<Object?> get props => [total, completed, failed, pending, lastUpdated];
}
