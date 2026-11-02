/// Values from --dart-define-from-file (tech.md 9).
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrls,
    required this.fakeVpn,
    required this.fakeApi,
    this.devToken = '',
  });

  factory AppConfig.fromEnvironment() => AppConfig(
    flavor: const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    apiBaseUrls: parseUrls(const String.fromEnvironment('API_BASE_URLS')),
    fakeVpn: const bool.fromEnvironment('FAKE_VPN'),
    fakeApi: const bool.fromEnvironment('FAKE_API'),
    devToken: const String.fromEnvironment('DEV_TOKEN'),
  );

  final String flavor;
  final List<String> apiBaseUrls;
  final bool fakeVpn;
  final bool fakeApi;

  /// The seed device token, set only in dev until S1-07 adds the login.
  final String devToken;

  static List<String> parseUrls(String raw) => raw
      .split(',')
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList();
}
