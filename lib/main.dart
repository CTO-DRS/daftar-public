import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'widgets/app_lock.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/invoices_list_screen.dart';
import 'services/settings_service.dart';
import 'utils/number_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService.instance.init();
  useArabicDigits = SettingsService.instance.arabicDigits;
  themeModeNotifier.value = themeModeFrom(SettingsService.instance.themeMode);
  runApp(const DaftarApp());
}

/// انتقالات ناعمة موحّدة (تتلاشى وتنزلق قليلاً) على كل المنصات.
final _pageTransitions = PageTransitionsTheme(builders: {
  TargetPlatform.android: const FadeForwardsPageTransitionsBuilder(),
  TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
  TargetPlatform.windows: const FadeForwardsPageTransitionsBuilder(),
  TargetPlatform.linux: const FadeForwardsPageTransitionsBuilder(),
  TargetPlatform.macOS: const CupertinoPageTransitionsBuilder(),
});

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode themeModeFrom(String v) => switch (v) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F766E),
      brightness: b,
      surface: dark ? const Color(0xFF131A1A) : null);
  final card = dark ? const Color(0xFF1B2525) : Colors.white;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'IBMPlexSansArabic',
    pageTransitionsTheme: _pageTransitions,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    scaffoldBackgroundColor:
        dark ? const Color(0xFF0E1414) : const Color(0xFFF6F8F8),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'IBMPlexSansArabic',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
    ),
    dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF1B2525) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? const Color(0xFF1B2525) : null,
        showDragHandle: true),
  );
}

class DaftarApp extends StatelessWidget {
  const DaftarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'دفتر',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar', 'SA'),
        supportedLocales: const [Locale('ar', 'SA'), Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: mode,
        home: const AppLock(child: InvoicesListScreen()),
      ),
    );
  }
}
