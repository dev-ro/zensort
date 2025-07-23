import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/auth/domain/entities/sign_in_result.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authStateSubscription;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<SignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<SignOutRequested>(_onSignOutRequested);
    on<_AuthStateChanged>(_onAuthStateChanged);

    _authStateSubscription = _authRepository.authStateChanges.listen((user) {
      add(_AuthStateChanged(user));
    });
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }

  void _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) {
    // The listener for authStateChanges handles the initial state.
  }

  Future<void> _onAuthStateChanged(
    _AuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    final user = event.user;
    if (user != null) {
      // First emit loading state to prevent premature HomeScreen builds
      emit(const AuthLoading());

      // Attempt to get a fresh access token through silent sign-in
      final accessToken = await _authRepository.signInSilentlyWithGoogle();

      // Only emit authenticated state if we have a valid access token
      if (accessToken != null) {
        emit(Authenticated(user: user, accessToken: accessToken));
      } else {
        // If we can't get an access token, treat as unauthenticated
        emit(const AuthUnauthenticated());
      }
    } else {
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onSignInWithGoogleRequested(
    SignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final signInResult = await _authRepository.signInWithGoogle();
      if (signInResult != null) {
        // This handles a user-initiated sign-in.
        // It provides the crucial accessToken.
        emit(
          Authenticated(
            user: signInResult.user,
            accessToken: signInResult.accessToken,
          ),
        );
      } else {
        // This handles the case where the user closes the Google pop-up.
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError('Sign-in failed: ${e.toString()}'));
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.signOut();
      // The authStateChanges listener will automatically handle emitting AuthUnauthenticated.
    } catch (e) {
      emit(AuthError('Sign-out failed: ${e.toString()}'));
    }
  }
}
