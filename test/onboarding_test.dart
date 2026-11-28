import 'package:daftar/screens/onboarding_screen.dart';
import 'package:daftar/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('onboarding: 3 cards, next to the end, sets the flag (scale $scale)', (t) async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.init();
      t.view.physicalSize = const Size(360, 700);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: Directionality(textDirection: TextDirection.rtl, child: w!)),
        home: Builder(builder: (c) => Scaffold(body: Center(child: ElevatedButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const OnboardingScreen())), child: const Text('open'))))),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('فاتورة في ثوانٍ'), findsOneWidget);
      expect(SettingsService.instance.onboarded, isFalse);
      await t.tap(find.byKey(const ValueKey('next')));
      await t.pumpAndSettle();
      expect(find.text('يفهم نشاطك'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('next')));
      await t.pumpAndSettle();
      expect(find.text('ابدأ'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('next')));
      await t.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(SettingsService.instance.onboarded, isTrue);
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('skip closes and sets the flag', (t) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) => Scaffold(body: ElevatedButton(onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const OnboardingScreen())), child: const Text('open'))))));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('skip')));
    await t.pumpAndSettle();
    expect(SettingsService.instance.onboarded, isTrue);
  });
}
