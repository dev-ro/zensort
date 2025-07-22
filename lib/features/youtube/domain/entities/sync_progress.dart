import 'package:equatable/equatable.dart';

enum SyncStatus { in_progress, completed, failed, none }

class SyncProgress extends Equatable {
  final int syncedCount;
  final int totalCount;
  final SyncStatus status;

  const SyncProgress({
    this.syncedCount = 0,
    this.totalCount = 0,
    this.status = SyncStatus.none,
  });

  @override
  List<Object?> get props => [syncedCount, totalCount, status];

  factory SyncProgress.fromMap(Map<String, dynamic> map) {
    return SyncProgress(
      syncedCount: map['syncedCount'] as int? ?? 0,
      totalCount: map['totalCount'] as int? ?? 0,
      status: _statusFromString(map['status'] as String?),
    );
  }

  static SyncStatus _statusFromString(String? status) {
    switch (status) {
      case 'in_progress':
        return SyncStatus.in_progress;
      case 'completed':
        return SyncStatus.completed;
      case 'failed':
        return SyncStatus.failed;
      default:
        return SyncStatus.none;
    }
  }
}
