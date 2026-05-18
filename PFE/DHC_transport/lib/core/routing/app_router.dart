import 'package:flutter/material.dart';

import '../../features/admin/presentation/admin_booking_details_screen.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/auth/presentation/auth_welcome_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/destination_guide/presentation/destination_guide_screen.dart';
import '../../features/recommendations/presentation/recommendation_management_screen.dart';
import '../../screens/client/client_shell.dart';
import '../../screens/assistant_screen.dart';
import '../models/admin_booking.dart';
import 'app_routes.dart';

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.authWelcome:
        return MaterialPageRoute(
            builder: (_) => const AuthWelcomeScreen(), settings: settings);
      case AppRoutes.login:
        return MaterialPageRoute(
            builder: (_) => const LoginScreen(), settings: settings);
      case AppRoutes.signup:
        return MaterialPageRoute(
            builder: (_) => const SignupScreen(), settings: settings);
      case AppRoutes.forgotPassword:
        return MaterialPageRoute(
            builder: (_) => const ForgotPasswordScreen(), settings: settings);
      case AppRoutes.clientShell:
        final initialIndex =
            settings.arguments is int ? settings.arguments as int : 0;
        return MaterialPageRoute(
            builder: (_) => ClientShell(initialIndex: initialIndex),
            settings: settings);
      case AppRoutes.adminShell:
        return MaterialPageRoute(
            builder: (_) => const AdminShell(), settings: settings);
      case AppRoutes.adminBookingDetails:
        final booking = settings.arguments as AdminBooking;
        return MaterialPageRoute(
          builder: (_) => AdminBookingDetailsScreen(booking: booking),
          settings: settings,
        );
      case AppRoutes.destinationGuide:
        final destination = (settings.arguments as String?) ?? 'Bizerte';
        return MaterialPageRoute(
          builder: (_) => DestinationGuideScreen(destination: destination),
          settings: settings,
        );
      case AppRoutes.recommendationManagement:
        return MaterialPageRoute(
          builder: (_) => const RecommendationManagementScreen(),
          settings: settings,
        );
      case AppRoutes.assistant:
        return MaterialPageRoute(
            builder: (_) => const AssistantScreen(), settings: settings);
      default:
        return MaterialPageRoute(
            builder: (_) => const AuthWelcomeScreen(), settings: settings);
    }
  }
}
