class Config {
  static const String baseApiUrl = 'https://coonchapp.pythonanywhere.com/';

  static const String baseUrl = 'https://coonchapp.pythonanywhere.com/';

  static String apiUrl(String path) {
    final base = baseApiUrl.endsWith('/') ? baseApiUrl.substring(0, baseApiUrl.length - 1) : baseApiUrl;
    return '$base/$path';
  }
}
 