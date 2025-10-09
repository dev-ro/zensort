import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:zensort/features/youtube/domain/entities/embedding_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';
import 'package:zensort/features/youtube/presentation/bloc/embedding_progress_cubit.dart';

class _MockYoutubeRepository extends Mock implements YoutubeRepository {}

void main() {
  group('EmbeddingProgressCubit', () {
    late _MockYoutubeRepository repo;
    late StreamController<EmbeddingProgress> controller;

    setUp(() {
      repo = _MockYoutubeRepository();
      controller = StreamController<EmbeddingProgress>.broadcast();
      when(repo.watchEmbeddingProgress()).thenAnswer((_) => controller.stream);
    });

    tearDown(() async {
      await controller.close();
    });

    blocTest<EmbeddingProgressCubit, EmbeddingProgress>(
      'emits values from repository stream',
      build: () => EmbeddingProgressCubit(repo),
      act: (cubit) async {
        controller.add(const EmbeddingProgress());
        controller.add(const EmbeddingProgress(total: 10, completed: 5, pending: 4));
      },
      expect: () => [
        const EmbeddingProgress(),
        const EmbeddingProgress(total: 10, completed: 5, pending: 4),
      ],
    );
  });
}


