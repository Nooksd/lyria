abstract class MyLocalStorage {
  Future<void> set(String key, dynamic value);
  dynamic get(String key);
  Future<void> remove(String key);
  Future<void> clear();
}