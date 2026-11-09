import 'package:flutter/material.dart';
import 'accessibility_settings.dart';
import 'screens/auth_screen.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AccessibilitySettings.instance.load();
  runApp(const MediReminderApp());
}

class MediReminderApp extends StatelessWidget {
  const MediReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = AccessibilitySettings.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        final highContrast = settings.highContrast;
        const standardSurface = Color(0xFFF7FAFC);
        const standardBorder = Color(0xFFD9E4EC);
        const contrastPrimary = Color(0xFF003B73);
        final surface = highContrast ? Colors.white : standardSurface;
        final border = highContrast ? Colors.black : standardBorder;
        final primary = highContrast ? contrastPrimary : kBlue;
        final colorScheme = ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          surface: surface,
        ).copyWith(
          onSurface: Colors.black,
          onSurfaceVariant:
              highContrast ? Colors.black : const Color(0xFF657786),
          outline: border,
        );

        return MaterialApp(
          title: 'MediReminder',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: colorScheme,
            useMaterial3: true,
            scaffoldBackgroundColor: surface,
            textTheme: const TextTheme(
              headlineMedium:
                  TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
              titleMedium: TextStyle(fontWeight: FontWeight.w700),
            ),
            appBarTheme: AppBarTheme(
              centerTitle: false,
              backgroundColor: Colors.transparent,
              foregroundColor:
                  highContrast ? Colors.black : const Color(0xFF183B56),
              elevation: 0,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primary, width: 2),
              ),
            ),
            navigationBarTheme: NavigationBarThemeData(
              height: 72,
              backgroundColor: Colors.white,
              indicatorColor: highContrast
                  ? const Color(0xFFFFD54F)
                  : const Color(0xFFE3F2FD),
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              margin: EdgeInsets.zero,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                side: BorderSide(
                  color: highContrast ? Colors.black : const Color(0xFFE8EFF4),
                  width: highContrast ? 1.5 : 1,
                ),
              ),
            ),
          ),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(settings.textScale),
                disableAnimations: settings.reduceMotion,
              ),
              child: child!,
            );
          },
          home: const LoginScreen(),
        );
      },
    );
  }
}
