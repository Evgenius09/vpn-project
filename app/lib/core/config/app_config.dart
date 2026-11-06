/// Values from --dart-define-from-file (tech.md 9).
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrls,
    required this.fakeVpn,
    required this.fakeApi,
    this.botUrl,
  });

  factory AppConfig.fromEnvironment() => AppConfig(
    flavor: const String.fromEnvironment('FLAVOR', defaultValue: 'dev'),
    apiBaseUrls: parseUrls(const String.fromEnvironment('API_BASE_URLS')),
    fakeVpn: const bool.fromEnvironment('FAKE_VPN'),
    fakeApi: const bool.fromEnvironment('FAKE_API'),
    botUrl: switch (const String.fromEnvironment('BOT_URL')) {
      '' => null,
      final url => url,
    },
  );

  final String flavor;
  final List<String> apiBaseUrls;
  final bool fakeVpn;
  final bool fakeApi;

  /// The Telegram bot, for the screens that come before any profile: the
  /// free mode and the first login step.
  final String? botUrl;

  static List<String> parseUrls(String raw) => raw
      .split(',')
      .map((url) => url.trim())
      .where((url) => url.isNotEmpty)
      .toList();
}
