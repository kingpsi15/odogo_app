// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../controllers/auth_controller.dart';
// import '../models/enums.dart'; // Make sure this path is correct for UserRole!

// import '../views/landing_page.dart';
// import '../views/sign_in_page.dart';
// import '../views/otp_page.dart';
// import '../views/sign_up_page.dart';
// import '../views/commuter_home.dart';
// import '../views/driver_home_screen.dart';

// final routerProvider = Provider<GoRouter>((ref) {
//   // 1. Create a ValueNotifier to bridge Riverpod and GoRouter
//   final routerNotifier = ValueNotifier<AuthState>(
//     ref.read(authControllerProvider),
//   );

//   // 2. Listen to the auth state and safely update the notifier
//   ref.listen<AuthState>(authControllerProvider, (previous, next) {
//     routerNotifier.value = next;
//   });

//   // 3. Clean up the notifier if the provider is ever destroyed
//   ref.onDispose(() {
//     routerNotifier.dispose();
//   });

//   // 4. Return GoRouter ONLY ONCE. Never rebuild it!
//   return GoRouter(
//     initialLocation: '/login',
//     refreshListenable:
//         routerNotifier, // Tells GoRouter to re-run the redirect when state changes

//     redirect: (context, state) {
//       // ALWAYS read the current state here instead of watching it outside
//       final authState = ref.read(authControllerProvider);
//       final path = state.uri.path;

//       final isAuthRoute =
//           path == '/login' || path == '/sign-in' || path == '/otp';

//       // If checking the hard drive or verifying an OTP, don't interrupt the user
//       if (authState is AuthLoading) return null;

//       // Unauthenticated users get kicked to /login ONLY if they try to go somewhere else
//       if (authState is AuthInitial ||
//           authState is AuthError ||
//           authState is AuthOtpSent) {
//         return isAuthRoute ? null : '/login';
//       }

//       // If Authenticated, seamlessly route them to their specific home screen
//       if (authState is AuthAuthenticated) {
//         if (isAuthRoute) {
//           return authState.user.role == UserRole.driver
//               ? '/driver-home'
//               : '/commuter-home';
//         }
//       }

//       // Prevent infinite redirect loop on the setup page
//       if (authState is AuthNeedsProfileSetup) {
//         return path == '/setup' ? null : '/setup';
//       }

//       return null;
//     },

//     routes: [
//       GoRoute(path: '/login', builder: (context, state) => const LandingPage()),
//       GoRoute(
//         path: '/sign-in',
//         builder: (context, state) {
//           final args = state.extra as Map<String, dynamic>? ?? {};
//           return SignInPage(
//             isDriver: args['isDriver'] ?? false,
//             isSignUp: args['isSignUp'] ?? false,
//           );
//         },
//       ),
//       GoRoute(
//         path: '/otp',
//         builder: (context, state) {
//           final args = state.extra as Map<String, dynamic>? ?? {};
//           return OtpPage(
//             isDriver: args['isDriver'] ?? false,
//             isSignUp: args['isSignUp'] ?? false,
//             email: args['email'] ?? '',
//           );
//         },
//       ),
//       GoRoute(
//         path: '/commuter-home',
//         builder: (context, state) => const CommuterHomeScreen(),
//       ),
//       GoRoute(
//         path: '/driver-home',
//         builder: (context, state) => const DriverHomeScreen(),
//       ),
//       GoRoute(
//         path: '/setup',
//         builder: (context, state) {
//           final isDriver = state.extra as bool? ?? false;
//           return SignUpPage(isDriver: isDriver);
//         },
//       ),
//     ],
//   );
// });
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

    // redirect: (context, state) {
    //   final authState = ref.read(authControllerProvider);
    //   final path = state.uri.path;

    //   // 1. If loading, ALWAYS force the splash screen (unless already there)
    //   if (authState is AuthLoading) {
    //     return path == '/splash' ? null : '/splash';
    //   }

    //   // 2. These are the ONLY screens an unauthenticated user is allowed to see
    //   // Notice: /splash is NO LONGER in this list!
    //   final isUnauthRoute =
    //       path == '/login' || path == '/sign-in' || path == '/otp';

    //   // 3. Handle Unauthenticated users (Fresh app or Logged out)
    //   if (authState is AuthInitial ||
    //       authState is AuthError ||
    //       authState is AuthOtpSent) {
    //     // If they are on the splash screen (or anywhere else), kick them to login
    //     return isUnauthRoute ? null : '/login';
    //   }

    //   // 4. Handle Authenticated users
    //   if (authState is AuthAuthenticated) {
    //     // If they are on an unauth screen, splash screen, or setup, send them Home
    //     if (isUnauthRoute || path == '/splash' || path == '/setup') {
    //       return authState.user.role == UserRole.driver
    //           ? '/driver-home'
    //           : '/commuter-home';
    //     }
    //   }

    //   // 5. Handle users who need to finish registration
    //   if (authState is AuthNeedsProfileSetup) {
    //     return path == '/setup' ? null : '/setup';
    //   }

    //   return null;
    // },
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final path = state.uri.path;

      if (authState is AuthLoading) {
        return path == '/splash' ? null : '/splash';
      }

      final isUnauthRoute =
          path == '/login' ||
          path == '/sign-in' ||
          path == '/otp' ||
          path == '/account-not-found';

      if (authState is AuthInitial ||
          authState is AuthError ||
          authState is AuthOtpSent) {
        return isUnauthRoute ? null : '/login';
      }

      // --- THE UPDATED AUTHENTICATED LOGIC ---
      if (authState is AuthAuthenticated) {
        final user = authState.user;
        final isDriver = user.role == UserRole.driver;

        // Keep user on OTP briefly so OTP screen can show role-mismatch snackbar.
        if (path == '/otp') {
          return null;
        }

        // Check if a driver still needs to upload documents (e.g., vehicle data is null)
        final needsDocs = isDriver && user.vehicle == null;

        if (needsDocs) {
          // Trap them on the docs screen until they submit
          return path == '/driver-docs' ? null : '/driver-docs';
        }

        // If they don't need docs, route them home seamlessly
        if (isUnauthRoute ||
            path == '/splash' ||
            path == '/setup' ||
            path == '/driver-docs') {
          return isDriver ? '/driver-home' : '/commuter-home';
        }
      }

      if (authState is AuthNeedsProfileSetup) {
        return (path == '/setup' || path == '/account-not-found')
            ? null
            : '/account-not-found';
      }

      return null;
    },

    routes: [
      // A clean Splash Screen for loading states
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
    ],
  );
});
