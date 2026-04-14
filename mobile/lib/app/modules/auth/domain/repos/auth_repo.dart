import 'package:lyria/app/modules/auth/domain/entities/app_user.dart';

abstract class AuthRepo {
  Future<AppUser?> login(String email, String password, bool keepLoggedIn);
  Future<AppUser?> isLoggedIn();
  Future<void> logout();
  Future<bool> register(String name, String email, String password);
  Future<bool> verifyEmail(String email, String code);
  Future<bool> resendVerification(String email);
}
