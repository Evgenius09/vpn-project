/// Values from --dart-define-from-file (tech.md 9).
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrls,
    required this.fakeVpn,
    required this.fakeApi,
  });

  factory AppConfig.fromEnvironment() => AppConfig(
    flavor: const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    apiBaseUrls: parseUrls(const String.fromEnvironment('API_BASE_URLS')),
    fakeVpn: const bool.fromEnvironment('FAKE_VPN'),
    fakeApi: const bool.fromEnvironment('FAKE_API'),
  );

  final String flavor;
  final List<String> apiBaseUrls;
  final bool fakeVpn;
  final bool fakeApi;

  static List<String> parseUrls(String raw) => raw
      .split(',')
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList();
}
