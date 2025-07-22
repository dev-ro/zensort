import 'package:equatable/equatable.dart';

part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

class AuthStateChanged extends AuthEvent {
  final User? user;

  const AuthStateChanged(this.user);

  @override
  List<Object> get props => [user ?? ''];
}

class SignInWithGoogle extends AuthEvent {}

class SignOut extends AuthEvent {}
