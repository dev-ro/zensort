part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthStarted extends AuthEvent {}

/// Private event triggered by repository stream changes
/// Carries User data from repository to AuthBloc for state translation
class _AuthenticationUserChanged extends AuthEvent {
  final User? user;

  const _AuthenticationUserChanged(this.user);

  @override
  List<Object> get props => [user ?? 'null'];
}

class SignInWithGoogleRequested extends AuthEvent {}

class SignOutRequested extends AuthEvent {}
