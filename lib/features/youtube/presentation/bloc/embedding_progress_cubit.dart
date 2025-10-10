import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

class EmbeddingProgressCubit extends Cubit<EmbeddingProgress> {
  final YoutubeRepository _repository;

  EmbeddingProgressCubit(this._repository) : super(const EmbeddingProgress()) {
    _subscribeToProgress();
  }

  void _subscribeToProgress() {
    _repository.watchEmbeddingProgress().listen(
      (progress) {
        emit(progress);
      },
      onError: (error) {
        // Handle errors gracefully - keep current state
        print('Error in EmbeddingProgressCubit: $error');
      },
    );
  }
}
