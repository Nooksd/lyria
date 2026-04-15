class ApiConfig {
  static const String baseUrl = 'https://lyria.risadev.com';
  static const String wsUrl = 'wss://lyria.risadev.com';

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
