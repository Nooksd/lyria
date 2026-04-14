import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lyria/app/modules/auth/domain/entities/app_user.dart';
import 'package:lyria/app/modules/auth/domain/repos/auth_repo.dart';
import 'package:lyria/app/modules/auth/presentation/cubits/auth_states.dart';
import 'package:path_provider/path_provider.dart';

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
      final msg = e.toString();
      if (msg.contains('emailNotVerified:')) {
        final email = msg.split('emailNotVerified:').last;
        emit(AuthError("Email não verificado. Verifique sua caixa de entrada."));
        emit(AuthNeedsVerification(email));
      } else {
        emit(AuthError("Email ou senha incorretos"));
        emit(Unauthenticated());
      }
    }
  }

  Future<void> register(String name, String email, String password) async {
    try {
      emit(AuthLoading());
      final success = await authRepo.register(name, email, password);
      if (success) {
        emit(AuthNeedsVerification(email));
      } else {
        emit(AuthError("Erro ao registrar"));
        emit(Unauthenticated());
      }
    } catch (e) {
      emit(AuthError("Erro ao registrar"));
      emit(Unauthenticated());
    }
  }

  Future<void> verifyEmail(String email, String code) async {
    try {
      emit(AuthLoading());
      final success = await authRepo.verifyEmail(email, code);
      if (success) {
        emit(AuthVerified());
      } else {
        emit(AuthError("Código inválido"));
        emit(AuthNeedsVerification(email));
      }
    } catch (e) {
      emit(AuthError("Erro ao verificar email"));
      emit(AuthNeedsVerification(email));
    }
  }

  Future<void> resendVerification(String email) async {
    try {
      await authRepo.resendVerification(email);
    } catch (_) {}
  }

  logout(BuildContext context) async {
    await authRepo.logout();
    _currentUser = null;

    try {
      final dir = await getApplicationDocumentsDirectory();
      final files = dir.listSync().whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('.mp3')) {
          await file.delete();
        }
      }
    } catch (_) {}

    emit(Unauthenticated());

    if (context.mounted) {
      context.go('/auth');
    }
  }
}
