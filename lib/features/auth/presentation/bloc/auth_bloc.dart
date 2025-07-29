import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Central State Authority for Authentication
/// Subscribes to AuthRepository and provides stable authentication state to entire application
/// Acts as "reactive translator" - never originates state, only reflects repository truth
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authSubscription;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<SignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<RefreshTokenRequested>(_onRefreshTokenRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<_AuthenticationUserChanged>(_onAuthenticationUserChanged);

    // Subscribe to repository's user stream (the Single Source of Truth)
    // This creates the hierarchical flow: Repository -> AuthBloc -> UI/Feature BLoCs
    _authSubscription = _authRepository.currentUser.listen((user) {
      add(_AuthenticationUserChanged(user));
    });
  }

  @override
  Future<void> close() {
    _authSubscription?.cancel();
    return super.close();
  }

  void _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) {
    // Initial state is handled by the repository stream listener
  }

  /// Core state translation logic - converts repository User changes to stable AuthState
  /// This is the central authority that determines authentication state for entire app
  Future<void> _onAuthenticationUserChanged(
    _AuthenticationUserChanged event,
    Emitter<AuthState> emit,
  ) async {
    final user = event.user;

    if (user != null) {
      // User is authenticated - get access token and emit stable Authenticated state
      final accessToken = await _authRepository.getAccessToken();
      emit(Authenticated(user: user, accessToken: accessToken));
    } else {
      // User is null - emit stable Unauthenticated state
      emit(const AuthUnauthenticated());
    }
  }

  /// Delegates sign-in action to repository - does NOT emit states directly
  /// Repository will update its stream, triggering the reactive loop
  Future<void> _onSignInWithGoogleRequested(
    SignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signInWithGoogle();
      // Do NOT emit success state here - let reactive loop complete
      // Repository stream will trigger _AuthenticationUserChanged event
    } catch (e) {
      emit(AuthError('Sign-in failed: ${e.toString()}'));
    }
  }

  /// Attempt to refresh access token silently without user interaction
  /// Used when access token is null but user is still authenticated
  Future<void> _onRefreshTokenRequested(
    RefreshTokenRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      // Attempt silent sign-in to refresh token
      final accessToken = await _authRepository.signInSilentlyWithGoogle();
      
      if (accessToken != null) {
        // If we got a token, trigger the auth state update
        // This will cause _onAuthenticationUserChanged to be called with the fresh token
        final currentUser = _authRepository.authStateChanges.take(1);
        await for (final user in currentUser) {
          if (user != null) {
            emit(Authenticated(user: user, accessToken: accessToken));
          }
          break;
        }
      } else {
        // Silent refresh failed, user needs to sign in again
        emit(const AuthError('Session expired. Please sign in again.'));
      }
    } catch (e) {
      emit(AuthError('Token refresh failed: ${e.toString()}'));
    }
  }

  /// Delegates sign-out action to repository - does NOT emit states directly
  /// Repository will update its stream, triggering the reactive loop
  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.signOut();
      // Clear all persisted state on sign-out for security
      await HydratedBloc.storage.clear();
      // Do NOT emit unauthenticated state here - let reactive loop complete
      // Repository stream will trigger _AuthenticationUserChanged event
    } catch (e) {
      emit(AuthError('Sign-out failed: ${e.toString()}'));
    }
  }
}
