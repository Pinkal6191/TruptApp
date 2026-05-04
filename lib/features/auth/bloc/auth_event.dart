import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class CheckAuthStatus extends AuthEvent {}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  const LoginEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}
class SignupEvent extends AuthEvent {
  final String name;
  final String mobile;
  final String email;
  final String password;
  final String role; // 'partner' or 'distributor'

  const SignupEvent({
    required this.name,
    required this.mobile,
    required this.email,
    required this.password,
    required this.role,
  });

  @override
  List<Object?> get props => [name, mobile, email, password, role];
}


class ForgotPasswordEvent extends AuthEvent {
  final String email;

  const ForgotPasswordEvent({required this.email});

  @override
  List<Object?> get props => [email];
}

class LogoutEvent extends AuthEvent {}
