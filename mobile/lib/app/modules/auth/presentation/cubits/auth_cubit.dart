import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/modules/auth/domain/entities/app_user.dart';
import 'package:lyria/app/modules/auth/domain/repos/auth_repo.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_states.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepo authRepo;
  AppUser? _currentUser;

  AuthCubit({required this.authRepo}) : super(AuthInitial());

  void checkAuth() async {
    final AppUser? user = await authRepo.isLoggedIn();

    if (user != null) {
      _currentUser = user;
      emit(Authenticated(user));
    } else {
      emit(Unauthenticated());
    }
  }

  AppUser? get currentUser => _currentUser;

  Future<void> login(String email, String password, bool keepLoggedIn) async {
    try {
      emit(AuthLoading());

      final user = await authRepo.login(email, password, keepLoggedIn);

      if (user != null) {
        _currentUser = user;
        emit(Authenticated(user));
      } else {
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError("Email ou senha incorretos"));
      emit(Unauthenticated());
    }
  }

  logout(BuildContext context) {
    authRepo.logout();
    _currentUser = null;

    emit(Unauthenticated());

    context.go('/auth/decide');
  }
}
