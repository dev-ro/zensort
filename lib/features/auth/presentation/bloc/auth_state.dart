part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final User user;
  final String accessToken;

  const Authenticated(this.user, this.accessToken);

  @override
  List<Object> get props => [user, accessToken];
}

class Unauthenticated extends AuthState {
  final String? error;

  const Unauthenticated({this.error});

  @override
  List<Object> get props => [error ?? ''];
}
