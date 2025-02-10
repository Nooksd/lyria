import 'package:lyria/app/core/services/storege/my_local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreferencesClient implements MyLocalStorage {
  Future<SharedPreferences> _getPreferences() async {
    return await SharedPreferences.getInstance();
  }

  @override
  Future<void> set(String key, dynamic value) async {
    final prefs = await _getPreferences();
    if (value is String) {
      await prefs.setString(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is List<String>) {
      await prefs.setStringList(key, value);
    } else {
      throw Exception('Invalid type for shared preferences');
    }
  }

  @override
  dynamic get(String key) async {
    final prefs = await _getPreferences();
    return prefs.get(key);
  }

  @override
  Future<void> remove(String key) async {
    final prefs = await _getPreferences();
    await prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    final prefs = await _getPreferences();
    await prefs.clear();
  }
}
