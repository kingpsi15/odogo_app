import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../models/enums.dart';

import '../views/landing_page.dart';
import '../views/sign_in_page.dart';
import '../views/otp_page.dart';
import '../views/sign_up_page.dart';
import '../views/commuter_home.dart';
import '../views/driver_home_screen.dart';
import '../views/driver_document_upload_screen.dart';
import '../views/driver_active_pickup_screen.dart';
import '../views/account_not_found_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ValueNotifier<AuthState>(
    ref.read(authControllerProvider),
  );

  ref.listen<AuthState>(authControllerProvider, (previous, next) {
    routerNotifier.value = next;
  });

  ref.onDispose(() {
    routerNotifier.dispose();
  });

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: routerNotifier,

    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final path = state.uri.path;

      // 1. If Loading, freeze routing entirely.
      if (authState is AuthLoading) {
        return null;
      }

      // 2. THE FIX: Use .startsWith() to prevent hidden trailing slashes from breaking the route.
      final isUnauthRoute =
          path.startsWith('/login') ||
          path.startsWith('/sign-in') ||
          path.startsWith('/otp') ||
          path.startsWith('/account-not-found');

      // 3. Handle Logged-Out Users (BRUTE FORCE BYPASS)
      if (authState is AuthInitial ||
          authState is AuthError ||
          authState is AuthOtpSent) {
        
        if (path.startsWith('/splash')) return '/login'; 
        
        // If they are going to ANY unauth route (like /otp), DO NOT INTERFERE.
        if (isUnauthRoute) return null; 
        
        return '/login'; 
      }

      // 4. Handle Logged-In Users
      if (authState is AuthAuthenticated) {
        final user = authState.user;
        final isDriver = user.role == UserRole.driver;

        if (path.startsWith('/otp')) return null;
        
        // Allow drivers to access active-pickup screen regardless of mode
        if (path.startsWith('/active-pickup')) return null;

        final needsDocs = isDriver && user.vehicle == null;
        if (needsDocs) {
          return path.startsWith('/driver-docs') ? null : '/driver-docs';
        }

        if (isUnauthRoute || path.startsWith('/splash') || path.startsWith('/setup') || path.startsWith('/driver-docs')) {
          return isDriver ? '/driver-home' : '/commuter-home';
        }
      }

      // 5. Handle Setup
      if (authState is AuthNeedsProfileSetup) {
        return (path.startsWith('/setup') || path.startsWith('/account-not-found'))
            ? null
            : '/account-not-found';
      }

      return null;
    },

    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(
          backgroundColor: Colors.white,
          body: Center(child: CircularProgressIndicator(color: Colors.black)),
        ),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LandingPage()),
      GoRoute(
        path: '/sign-in',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return SignInPage(
            isDriver: args['isDriver'] ?? false,
            isSignUp: args['isSignUp'] ?? false,
          );
        },
      ),
      GoRoute(
        path: '/otp',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return OtpPage(
            isDriver: args['isDriver'] ?? false,
            isSignUp: args['isSignUp'] ?? false,
            email: args['email'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/account-not-found',
        builder: (context, state) {
          final args = state.extra as Map<String, dynamic>? ?? {};
          return AccountNotFoundScreen(
            isDriver: args['isDriver'] ?? false,
            email: args['email'] ?? '',
          );
        },
      ),
      GoRoute(
        path: '/commuter-home',
        builder: (context, state) => const CommuterHomeScreen(),
      ),
      GoRoute(
        path: '/driver-home',
        builder: (context, state) => const DriverHomeScreen(),
      ),
      GoRoute(
        path: '/setup',
        builder: (context, state) {
          final isDriver = state.extra as bool? ?? false;
          return SignUpPage(isDriver: isDriver);
        },
      ),
      GoRoute(
        path: '/driver-docs',
        builder: (context, state) => const DriverDocumentUploadScreen(),
      ),
      GoRoute(
        path: '/active-pickup',
        builder: (context, state) {
          final tripID = state.extra as String? ?? '';
          return DriverActivePickupScreen(tripID: tripID);
        },
      ),
    ],
  );
});