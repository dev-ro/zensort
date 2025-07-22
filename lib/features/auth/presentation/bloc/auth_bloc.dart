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
      // For auth state changes (like app restart), try to get access token
      final accessToken = await _authRepository.getAccessToken() ?? '';
      emit(Authenticated(event.user!, accessToken));
    } else {
      emit(const Unauthenticated());
    }
  }

  Future<void> _onSignInWithGoogle(
    SignInWithGoogle event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await _authRepository.signInWithGoogle();

      if (result == null) {
        // User cancelled the sign-in
        emit(const Unauthenticated());
      } else {
        // Emit authenticated state directly with both user and access token
        emit(Authenticated(result.user, result.accessToken));
      }
    } catch (e) {
      emit(Unauthenticated(error: 'Sign-in failed. Please try again.'));
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
