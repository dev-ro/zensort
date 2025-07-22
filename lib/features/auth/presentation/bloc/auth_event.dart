part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthStarted extends AuthEvent {}

class _AuthStateChanged extends AuthEvent {
  final User? user;

  const _AuthStateChanged(this.user);

  @override
  List<Object> get props => [user ?? ''];
}

class SignInWithGoogleRequested extends AuthEvent {}

class SignOutRequested extends AuthEvent {}
