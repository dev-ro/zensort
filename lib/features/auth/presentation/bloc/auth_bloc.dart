import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authStateSubscription;
  String? _pendingAccessToken;

  AuthBloc(this._authRepository) : super(AuthInitial()) {
    on<AuthStateChanged>(_onAuthStateChanged);
    on<SignInWithGoogle>(_onSignInWithGoogle);
    on<SignOut>(_onSignOut);

    _authStateSubscription = _authRepository.authStateChanges.listen((user) {
      add(AuthStateChanged(user));
    });
  }

  Future<void> _onAuthStateChanged(
    AuthStateChanged event,
    Emitter<AuthState> emit,
  ) async {
    if (event.user != null) {
      // Use the pending access token from sign-in if available
      String accessToken = '';
      if (_pendingAccessToken != null) {
        accessToken = _pendingAccessToken!;
        _pendingAccessToken = null; // Clear it after use
      } else {
        // Try to get the access token from the repository
        accessToken = await _authRepository.getAccessToken() ?? '';
      }
      emit(Authenticated(event.user!, accessToken));
    } else {
      emit(const Unauthenticated());
      _pendingAccessToken = null; // Clear on sign out
    }
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogle event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final accessToken = await _authRepository.signInWithGoogle();

      if (accessToken == null) {
        // User cancelled the sign-in
        emit(const Unauthenticated());
      } else {
        // Store the access token for the auth state changed handler
        _pendingAccessToken = accessToken;
        // The auth state listener will handle emitting the Authenticated state
      }
    } catch (e) {
      emit(Unauthenticated(error: e.toString()));
    }
  }

  Future<void> _onSignOut(SignOut event, Emitter<AuthState> emit) async {
    await _authRepository.signOut();
    // The auth state stream will emit a new state
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
