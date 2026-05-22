class ApiConfig {
  static const String baseUrl = 'https://lyria.risadev.com';
  static const String wsUrl = 'wss://lyria.risadev.com';
  static final Map<String, String> _imageCacheBusters = {};

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

  static String? bustImageCache(String? url) {
    final fixedUrl = _imageCacheBaseUrl(url);
    if (fixedUrl.isEmpty) return null;

    final version = DateTime.now().microsecondsSinceEpoch.toString();
    _imageCacheBusters[fixedUrl] = version;
    return version;
  }

  static String versionedImageUrl(String? url, {String? version}) {
    final fixedUrl = _imageCacheBaseUrl(url);
    if (fixedUrl.isEmpty) return '';

    final resolvedVersion = version ?? _imageCacheBusters[fixedUrl];
    if (resolvedVersion == null || resolvedVersion.isEmpty) {
      return fixedUrl;
    }

    final uri = Uri.tryParse(fixedUrl);
    if (uri == null) {
      return '$fixedUrl?v=$resolvedVersion';
    }

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'v': resolvedVersion,
      },
    ).toString();
  }

  static String? versionedImageCacheKey(String? url, {String? version}) {
    final versionedUrl = versionedImageUrl(url, version: version);
    return versionedUrl.isEmpty ? null : versionedUrl;
  }

  static String _imageCacheBaseUrl(String? url) {
    final fixedUrl = fixImageUrl(url);
    if (fixedUrl.isEmpty) return '';

    final uri = Uri.tryParse(fixedUrl);
    if (uri == null) {
      return fixedUrl.split('?').first;
    }

    return uri.replace(query: null, fragment: null).toString();
  }
}
