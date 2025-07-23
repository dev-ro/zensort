import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:zensort/features/auth/domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Pure action handler for user-initiated authentication events
/// Does NOT manage authentication state - only delegates actions to repository
/// State comes directly from AuthRepository.currentUser stream consumed by UI/other BLoCs
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<SignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<SignOutRequested>(_onSignOutRequested);
  }

  void _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) {
    // Nothing to do - state comes from repository stream
    emit(const AuthInitial());
  }

  Future<void> _onSignInWithGoogleRequested(
    SignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final signInResult = await _authRepository.signInWithGoogle();
      if (signInResult != null) {
        // Successful sign-in - repository stream will update automatically
        // Return to initial state as AuthGate will handle navigation
        emit(const AuthInitial());
      } else {
        // User cancelled sign-in
        emit(const AuthInitial());
      }
    } catch (e) {
      emit(AuthError('Sign-in failed: ${e.toString()}'));
    }
  }

  Future<void> _onSignOutRequested(
    SignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _authRepository.signOut();
      // Repository stream will update automatically - return to initial state
      emit(const AuthInitial());
    } catch (e) {
      emit(AuthError('Sign-out failed: ${e.toString()}'));
    }
  }
}
