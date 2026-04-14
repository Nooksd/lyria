import 'package:lyria/app/modules/auth/domain/entities/app_user.dart';

abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final AppUser user;
  Authenticated(this.user);
}

class Unauthenticated extends AuthState {}

class AuthNeedsVerification extends AuthState {
  final String email;
  AuthNeedsVerification(this.email);
}

class AuthVerified extends AuthState {}

class AuthError extends AuthState {
  final String error;
  AuthError(this.error);
}
