// import 'package:flutter/material.dart';

// // TODO: Import your landing page!
// import 'landing_page.dart';

// class LogoutWarningScreen extends StatelessWidget {
//   const LogoutWarningScreen({super.key});

//   void _proceedToLandingPage(BuildContext context) {
//     // 1. Grab the messenger to show a quick confirmation
//     final messenger = ScaffoldMessenger.of(context);

//     // 2. Nuke the stack and drop them on the landing page
//     Navigator.pushAndRemoveUntil(
//       context,
//       MaterialPageRoute(builder: (context) => const LandingPage()),
//       (route) => false,
//     );

//     // 3. Show the logout confirmation
//     messenger.showSnackBar(
//       const SnackBar(
//         content: Text('Logged out successfully.'),
//         backgroundColor: Colors.black87,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text('Create Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(24.0),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               const SizedBox(height: 40),
//               // Logout Icon
//               Container(
//                 padding: const EdgeInsets.all(24),
//                 decoration: BoxDecoration(
//                   color: Colors.grey.shade100,
//                   shape: BoxShape.circle,
//                 ),
//                 child: const Icon(Icons.logout_rounded, size: 80, color: Colors.black87),
//               ),
//               const SizedBox(height: 32),

//               const Text(
//                 'Log Out to Continue',
//                 style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
//               ),
//               const SizedBox(height: 16),
//               const Text(
//                 'To create a new account, you need to log out of your current session. You can easily switch back to this account later.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
//               ),

//               const Spacer(),

//               // Cancel Button
//               OutlinedButton(
//                 onPressed: () => Navigator.pop(context),
//                 style: OutlinedButton.styleFrom(
//                   minimumSize: const Size.fromHeight(56),
//                   side: BorderSide(color: Colors.grey.shade300, width: 2),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                 ),
//                 child: const Text('Cancel', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
//               ),
//               const SizedBox(height: 16),

//               // Log Out & Continue Button
//               ElevatedButton(
//                 onPressed: () => _proceedToLandingPage(context),
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFF333333),
//                   minimumSize: const Size.fromHeight(56),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   elevation: 0,
//                 ),
//                 child: const Text('Log Out & Continue', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 1. Added Riverpod
import '../controllers/auth_controller.dart'; // 2. Import your AuthController (Adjust path if needed)

// 3. Upgraded to ConsumerWidget
class LogoutWarningScreen extends ConsumerWidget {
  const LogoutWarningScreen({super.key});

  void _proceedToLandingPage(BuildContext context, WidgetRef ref) {
    // 1. Grab the messenger to show a quick confirmation
    final messenger = ScaffoldMessenger.of(context);

    // 2. Show the logout confirmation BEFORE we change the state
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Logged out successfully.'),
        backgroundColor: Colors.black87,
      ),
    );

    // 3. THE FIX: Tell the controller to prep for a new account.
    // This drops the state to AuthInitial and GoRouter automatically teleports you to the Landing Page!
    // It purposefully leaves your old session on the hard drive so you can easily switch back.
    ref.read(authControllerProvider.notifier).startAddingNewAccount();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logout Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 80,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                'Log Out to Continue',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'To log into a new account, you need to step out of your current session. You can easily switch back to this account later.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),

              const Spacer(),

              // Cancel Button
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  side: BorderSide(color: Colors.grey.shade300, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Log Out & Continue Button
              ElevatedButton(
                // 4. Pass 'ref' into our helper method so it can talk to the Controller
                onPressed: () => _proceedToLandingPage(context, ref),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF333333),
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Log Out & Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
