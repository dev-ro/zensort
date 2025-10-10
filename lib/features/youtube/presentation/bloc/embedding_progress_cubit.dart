import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

class EmbeddingProgressCubit extends Cubit<EmbeddingProgress> {
  final YoutubeRepository _repository;
  StreamSubscription<EmbeddingProgress>? _subscription;

  EmbeddingProgressCubit(this._repository) : super(const EmbeddingProgress()) {
    _subscribeToProgress();
  }

  void _subscribeToProgress() {
    _subscription?.cancel();
    _subscription = _repository.watchEmbeddingProgress().listen(
      (progress) {
        if (!isClosed) {
          emit(progress);
        }
      },
      onError: (error) {
        // Handle errors gracefully - keep current state
        print('Error in EmbeddingProgressCubit: $error');
      },
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
