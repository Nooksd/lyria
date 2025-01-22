import 'dart:convert';

import 'package:lyria/app/core/services/http/my_http_client.dart';
import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:lyria/app/modules/auth/domain/entities/app_user.dart';
import 'package:lyria/app/modules/auth/domain/repos/auth_repo.dart';

class MongoAuthRepo implements AuthRepo {
  MyHttpClient http;
  MyLocalStorage storage;

  MongoAuthRepo({required this.http, required this.storage});

  @override
  Future<AppUser?> loginWithEmailPassword(String email, String password) async {
    try {
      final body = {
        'email': email,
        'password': password,
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

        return AppUser.fromMap({
          'name': userData['name'],
          'role': userData['role'],
          'profilePictureUrl': userData['profilePictureUrl'],
          'email': userData['email'],
          'id': userData['id'],
        });
      }
      return null;
    } catch (e) {
      throw Exception('Failed to login: $e');
    }
  }

  @override
  Future<AppUser?> isLoggedIn() async {
    try {
      final user = await await storage.get('user');
      final token = await storage.get('accessToken');

      final userData = user is String ? jsonDecode(user) : null;

      if (user != null && token != null) {
        return AppUser.fromMap({
          'name': userData['name'],
          'role': userData['role'],
          'profilePictureUrl': userData['profilePictureUrl'],
          'email': userData['email'],
          'id': userData['id'],
        });
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch current user: $e');
    }
  }

  @override
  Future<void> logout() async {
    await storage.remove('accessToken');
    await storage.remove('refreshToken');
    await storage.remove('user');
  }
}
