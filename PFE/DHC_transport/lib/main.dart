import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/routing/app_routes.dart';
import 'core/routing/app_router.dart';
import 'core/services/auth_service.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    AuthService.instance.loadFromStorage(),
    ThemeService.instance.loadFromStorage(),
  ]);
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
        return MaterialApp(
          title: 'Carthage Transfer',
          debugShowCheckedModeBanner: false,
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
  }
}
