import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:zensort/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:zensort/features/youtube/domain/entities/liked_video.dart';
import 'package:zensort/features/youtube/domain/entities/sync_progress.dart';
import 'package:zensort/features/youtube/domain/repositories/youtube_repository.dart';

part 'youtube_event.dart';
part 'youtube_state.dart';

class YouTubeBloc extends HydratedBloc<YoutubeEvent, YoutubeState> {
  final YoutubeRepository _youtubeRepository;
  final AuthBloc _authBloc;
  StreamSubscription<SyncProgress>? _syncProgressSubscription;
  StreamSubscription<AuthState>? _authStateSubscription;
  StreamSubscription<List<LikedVideo>>? _likedVideosSubscription;
  
  // Boolean latch to prevent race conditions from rapid auth state emissions
  bool _isInitialLoadDispatched = false;

  YouTubeBloc(this._youtubeRepository, this._authBloc)
    : super(YoutubeInitial()) {
    on<SyncLikedVideos>(_onSyncLikedVideos);
    on<LoadInitialVideos>(_onLoadInitialVideos);
    on<_YoutubeSyncProgressUpdated>(_onYoutubeSyncProgressUpdated);
    on<_AuthStatusChanged>(_onAuthStatusChanged, transformer: restartable());
    on<_LikedVideosUpdated>(_onLikedVideosUpdated);
    on<_LikedVideosError>(_onLikedVideosError);

    // Listen to AuthBloc's stable authentication state (hierarchical flow)
    // Repository -> AuthBloc -> YouTubeBloc
    _authStateSubscription = _authBloc.stream.listen((authState) {
      add(_AuthStatusChanged(authState));
    });
    
    // Check current auth state immediately when BLoC starts
    add(_AuthStatusChanged(_authBloc.state));
  }

  void _onAuthStatusChanged(
    _AuthStatusChanged event,
    Emitter<YoutubeState> emit,
  ) async {
    final authState = event.authState;
    print('=== YouTubeBloc._onAuthStatusChanged ===');
    print('Auth state: ${authState.runtimeType}');
    print('Initial load dispatched: $_isInitialLoadDispatched');

    if (authState is Authenticated && authState.accessToken != null && !_isInitialLoadDispatched) {
      print('User authenticated with access token - setting up streams and triggering initial load');
      _isInitialLoadDispatched = true;

      emit(YoutubeLoading());

      // Cancel existing subscriptions
      _syncProgressSubscription?.cancel();
      _likedVideosSubscription?.cancel();

      // Set up sync progress monitoring
      _syncProgressSubscription = _youtubeRepository
          .getSyncProgressStream()
          .listen(
            (progress) => add(_YoutubeSyncProgressUpdated(progress)),
            onError: (error) {
              print('Sync progress stream error: $error');
              emit(YoutubeFailure(error.toString()));
            },
          );

      // Set up reactive liked videos stream
      _likedVideosSubscription = _youtubeRepository.watchLikedVideos().listen(
        (videos) {
          print('watchLikedVideos stream emitted ${videos.length} videos');
          add(_LikedVideosUpdated(videos));
        },
        onError: (error) {
          print('Liked videos stream error: $error');
          add(_LikedVideosError(error.toString()));
        },
      );

      // Check if user has existing videos, if not trigger automatic sync
      try {
        print('Checking for existing videos...');
        final existingVideos = await _youtubeRepository.watchLikedVideos().first;
        print('Found ${existingVideos.length} existing videos');
        
        if (existingVideos.isEmpty) {
          print('No existing videos found, triggering automatic sync...');
          add(SyncLikedVideos());
        }
      } catch (e) {
        print('Error checking existing videos, triggering sync anyway: $e');
        add(SyncLikedVideos());
      }
    } else if (authState is AuthUnauthenticated) {
      print('User unauthenticated - clearing state and resetting latch');
      // Reset the latch when user becomes unauthenticated
      _isInitialLoadDispatched = false;
      
      // Clear state and cancel subscriptions
      _syncProgressSubscription?.cancel();
      _likedVideosSubscription?.cancel();
      _syncProgressSubscription = null;
      _likedVideosSubscription = null;
      emit(YoutubeInitial());
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

  Future<void> _onLoadInitialVideos(
    LoadInitialVideos event,
    Emitter<YoutubeState> emit,
  ) async {
    print('=== YouTubeBloc._onLoadInitialVideos() called ===');
    // Trigger auth state check which will set up streams and sync if needed
    add(_AuthStatusChanged(_authBloc.state));
  }

  void _onYoutubeSyncProgressUpdated(
    _YoutubeSyncProgressUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    final progress = event.progress;
    print('=== YouTubeBloc._onYoutubeSyncProgressUpdated ===');
    print('Progress status: ${progress.status}');
    print('Synced: ${progress.syncedCount}, Total: ${progress.totalCount}');
    
    if (progress.status == SyncStatus.in_progress) {
      emit(YoutubeSyncProgress(progress.syncedCount, progress.totalCount));
    } else if (progress.status == SyncStatus.completed) {
      print('Sync completed! Emitting YoutubeSyncSuccess');
      emit(YoutubeSyncSuccess());
    } else if (progress.status == SyncStatus.failed) {
      print('Sync failed! Emitting YoutubeFailure');
      emit(const YoutubeFailure('Video sync failed.'));
    }
  }

  /// Handles liked videos data from repository stream
  /// SAFE: emit() called within event handler context - follows reactive repository pattern
  void _onLikedVideosUpdated(
    _LikedVideosUpdated event,
    Emitter<YoutubeState> emit,
  ) {
    print('=== YouTubeBloc._onLikedVideosUpdated ===');
    print('Received ${event.videos.length} videos from stream');
    if (event.videos.isNotEmpty) {
      print('First video: ${event.videos.first.title}');
    }
    emit(YoutubeLoaded(videos: event.videos));
  }

  /// Handles stream errors from repository
  /// SAFE: emit() called within event handler context
  void _onLikedVideosError(
    _LikedVideosError event,
    Emitter<YoutubeState> emit,
  ) {
    print('=== YouTubeBloc._onLikedVideosError ===');
    print('Error: ${event.message}');
    emit(YoutubeFailure(event.message));
  }

  @override
  Future<void> close() {
    _syncProgressSubscription?.cancel();
    _authStateSubscription?.cancel();
    _likedVideosSubscription?.cancel();
    return super.close();
  }

  // HydratedBloc serialization methods
  @override
  YoutubeState? fromJson(Map<String, dynamic> json) {
    try {
      final stateType = json['stateType'] as String?;
      if (stateType == 'YoutubeLoaded') {
        return YoutubeLoaded.fromJson(json);
      }
      // For other states, return null to use default initial state
      return null;
    } catch (_) {
      // If deserialization fails, return null to use default initial state
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(YoutubeState state) {
    if (state is YoutubeLoaded) {
      return {
        'stateType': 'YoutubeLoaded',
        ...state.toJson(),
      };
    }
    // Only persist YoutubeLoaded states, ignore others
    return null;
  }
}
