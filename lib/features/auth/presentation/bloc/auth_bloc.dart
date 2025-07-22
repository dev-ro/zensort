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
      // Fetch the access token when user is authenticated
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
      final accessToken = await _authRepository.signInWithGoogle();

      if (accessToken == null) {
        // User cancelled the sign-in
        emit(const Unauthenticated());
      }
      // If sign-in was successful, the auth state listener will handle
      // emitting the Authenticated state via AuthStateChanged event
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
