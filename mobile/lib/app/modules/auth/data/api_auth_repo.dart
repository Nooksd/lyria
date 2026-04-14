import 'dart:convert';

import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/auth/domain/entities/app_user.dart';
import 'package:lyria/app/modules/auth/domain/repos/auth_repo.dart';

class ApiAuthRepo implements AuthRepo {
  MyHttpClient http;
  MyLocalStorage storage;

  ApiAuthRepo({required this.http, required this.storage});

  @override
  Future<AppUser?> login(
      String email, String password, bool keepLoggedIn) async {
    try {
      final body = {
        'email': email,
        'password': password,
        'keepLoggedIn': true,
      };

      final data = jsonEncode(body);
      final response = await http.post('/auth/login', data: data);

      if (response['status'] == 200) {
        final data = response['data'];

        final newAccessToken = data['accessToken'];
        final newRefreshToken = data['refreshToken'];
        final userData = data['user'];

        await storage.set('accessToken', newAccessToken);
        await storage.set('refreshToken', newRefreshToken);
        await storage.set('user', jsonEncode(userData));

        return AppUser.fromMap(userData);
      } else if (response['status'] == 403 &&
          response['data']?['emailNotVerified'] == true) {
        throw Exception('emailNotVerified:$email');
      }
      return null;
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  @override
  Future<AppUser?> isLoggedIn() async {
    try {
      final user = await storage.get('user');
      final token = await storage.get('accessToken');

      final userData = user is String ? jsonDecode(user) : null;

      if (userData != null && token != null) {
        return AppUser.fromMap(userData);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch current user: $e');
    }
  }

  @override
  Future<void> logout() async {
    await storage.clear();
  }

  @override
  Future<bool> register(String name, String email, String password) async {
    try {
      final body = jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      });

      final response = await http.post('/auth/register', data: body);
      return response['status'] == 201;
    } catch (e) {
      throw Exception('Erro ao registrar: $e');
    }
  }

  @override
  Future<bool> verifyEmail(String email, String code) async {
    try {
      final body = jsonEncode({
        'email': email,
        'code': code,
      });

      final response = await http.post('/auth/verify-email', data: body);
      return response['status'] == 200;
    } catch (e) {
      throw Exception('Erro ao verificar email: $e');
    }
  }

  @override
  Future<bool> resendVerification(String email) async {
    try {
      final body = jsonEncode({'email': email});

      final response =
          await http.post('/auth/resend-verification', data: body);
      return response['status'] == 200;
    } catch (e) {
      throw Exception('Erro ao reenviar código: $e');
    }
  }
}
