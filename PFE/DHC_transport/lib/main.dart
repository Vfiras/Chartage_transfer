import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/routing/app_routes.dart';
import 'core/routing/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/language_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/theme_service.dart';
import 'core/constants/app_colors.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    AuthService.instance.loadFromStorage(),
    LanguageService.instance.loadFromStorage(),
    ThemeService.instance.loadFromStorage(),
  ]);
  // Notifications come after auth so the background poll only starts for a
  // signed-in device. Failures here are swallowed inside the service — the
  // app must start whether or not the OS allows notifications.
  await PushNotificationService.instance.init();
  if (AuthService.instance.isAuthenticated) {
    await PushNotificationService.instance.start();
  }

  runApp(const DhcTransportApp());
}

class DhcTransportApp extends StatelessWidget {
  const DhcTransportApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTextTheme = GoogleFonts.montserratTextTheme();
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.instance.mode,
      builder: (context, themeMode, _) {
        return ValueListenableBuilder<AppLanguage>(
          valueListenable: LanguageService.instance.language,
          builder: (context, language, __) {
            AppColors.setDarkMode(themeMode == ThemeMode.dark);
            return MaterialApp(
              title: 'Carthage Transfer',
              debugShowCheckedModeBanner: false,
              locale: Locale(LanguageService.instance.code),
              supportedLocales: const [
                Locale('en'),
                Locale('fr'),
              ],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              themeMode: themeMode,
              theme: AppTheme.lightTheme(baseTextTheme: baseTextTheme),
              darkTheme: AppTheme.darkTheme(baseTextTheme: baseTextTheme),
              initialRoute: AuthService.instance.isAuthenticated
                  ? (AuthService.instance.currentUser?.role == 'admin'
                      ? AppRoutes.adminShell
                      : AppRoutes.clientShell)
                  : AppRoutes.authWelcome,
              onGenerateRoute: AppRouter.onGenerateRoute,
            );
          },
        );
      },
    );
  }
}
