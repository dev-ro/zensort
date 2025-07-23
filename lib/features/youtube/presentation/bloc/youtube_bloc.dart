import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

part 'youtube_event.dart';
part 'youtube_state.dart';

class YouTubeBloc extends Bloc<YoutubeEvent, YoutubeState> {
  final YoutubeRepository _youtubeRepository;
  final AuthBloc _authBloc;
  StreamSubscription<SyncProgress>? _syncProgressSubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  StreamSubscription<List<LikedVideo>>? _likedVideosSubscription;

  YouTubeBloc(this._youtubeRepository, this._authBloc)
    : super(YoutubeInitial()) {
    on<SyncLikedVideos>(_onSyncLikedVideos);
    on<_YoutubeSyncProgressUpdated>(_onYoutubeSyncProgressUpdated);
    on<_AuthStatusChanged>(_onAuthStatusChanged, transformer: restartable());

    // Listen to AuthBloc's stable authentication state (hierarchical flow)
    // Repository -> AuthBloc -> YouTubeBloc
    _authStateSubscription = _authBloc.stream.listen((authState) {
      add(_AuthStatusChanged(authState));
    });
  }

  void _onAuthStatusChanged(
    _AuthStatusChanged event,
    Emitter<YoutubeState> emit,
  ) async {
    final authState = event.authState;

    if (authState is Authenticated) {
      print('=== BLOC: User authenticated, current state before setup: $state');
      print('=== BLOC: User authenticated, setting up reactive streams ===');
      emit(YoutubeLoading());

      // Cancel existing subscriptions
      _syncProgressSubscription?.cancel();
      _likedVideosSubscription?.cancel();

      // Set up sync progress monitoring
      _syncProgressSubscription = _youtubeRepository
          .getSyncProgressStream()
          .listen(
            (progress) => add(_YoutubeSyncProgressUpdated(progress)),
            onError: (error) => emit(YoutubeFailure(error.toString())),
          );

      // Set up reactive liked videos stream
      _likedVideosSubscription = _youtubeRepository.watchLikedVideos().listen(
        (videos) {
          print(
            '=== BLOC: Received ${videos.length} videos from repository stream',
          );
          print(
            '=== BLOC: Sample video data: ${videos.take(2).map((v) => v.title).toList()}',
          );
          print('=== BLOC: About to emit YoutubeLoaded state');
          emit(YoutubeLoaded(videos: videos));
          print('=== BLOC: YoutubeLoaded state emitted successfully');
        },
        onError: (error) {
          print('=== BLOC ERROR: Error in liked videos stream: $error');
          emit(YoutubeFailure(error.toString()));
        },
      );
      print('=== BLOC: Reactive streams setup complete');
    } else if (authState is AuthUnauthenticated) {
      // User is not authenticated - clear state and cancel subscriptions
      print('=== BLOC: User unauthenticated, clearing state from: $state');
      _syncProgressSubscription?.cancel();
      _likedVideosSubscription?.cancel();
      _syncProgressSubscription = null;
      _likedVideosSubscription = null;
      emit(YoutubeInitial());
      print('=== BLOC: State cleared to YoutubeInitial');
    }
    // Ignore AuthLoading, AuthInitial, and AuthError states
  }

  Future<void> _onSyncLikedVideos(
    SyncLikedVideos event,
    Emitter<YoutubeState> emit,
  ) async {
    try {
      print('=== YouTubeBloc._onSyncLikedVideos() called ===');
      print('Calling repository syncLikedVideos()...');
      await _youtubeRepository.syncLikedVideos();
      print('Repository syncLikedVideos() completed');
      emit(YoutubeSyncSuccess());
    } catch (e) {
      print('Error calling sync function: $e');
      print('Stack trace: ${StackTrace.current}');
      emit(YoutubeFailure('Video sync failed: $e'));
    }
  }

  void _onYoutubeSyncProgressUpdated(
    _YoutubeSyncProgressUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    final progress = event.progress;
    if (progress.status == SyncStatus.in_progress) {
      emit(YoutubeSyncProgress(progress.syncedCount, progress.totalCount));
    } else if (progress.status == SyncStatus.completed) {
      emit(YoutubeSyncSuccess());
    } else if (progress.status == SyncStatus.failed) {
      emit(const YoutubeFailure('Video sync failed.'));
    }
  }

  @override
  Future<void> close() {
    _syncProgressSubscription?.cancel();
    _authStateSubscription?.cancel();
    _likedVideosSubscription?.cancel();
    return super.close();
  }
}
