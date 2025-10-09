import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

class EmbeddingProgressCubit extends Cubit<EmbeddingProgress> {
  final YoutubeRepository _repository;
  StreamSubscription<EmbeddingProgress>? _sub;

  EmbeddingProgressCubit(this._repository) : super(const EmbeddingProgress()) {
    _sub = _repository.watchEmbeddingProgress().listen(emit);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
