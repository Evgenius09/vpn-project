import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vpnclient/gen/l10n/app_localizations.dart';
import 'package:vpnclient/ui/ui.dart';

Widget harness(
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light(),
    locale: locale,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      ),
    ),
  );
}

Future<void> pumpHarness(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(harness(child));
  await tester.pump();
}
