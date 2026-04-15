class ApiConfig {
  static const String baseUrl = 'http://192.168.15.11:9000';
  static const String wsUrl = 'ws://192.168.15.11:9000';

  static String fixImageUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      final uri = Uri.parse(url);
      return '$baseUrl${uri.path}';
    }
    if (url.startsWith('/')) {
      return '$baseUrl$url';
    }
    return url;
  }
}
