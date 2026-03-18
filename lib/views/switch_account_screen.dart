// import 'package:flutter/material.dart';
// import 'logout_warning_screen.dart';

// class SwitchAccountScreen extends StatefulWidget {
//   const SwitchAccountScreen({super.key});

//   @override
//   State<SwitchAccountScreen> createState() => _SwitchAccountScreenState();
// }

// class _SwitchAccountScreenState extends State<SwitchAccountScreen> {
//   // State variable to track which account is currently selected
//   String _activeEmail = 'email2@example.com';

//   final List<String> _linkedAccounts = [
//     'email1@example.com',
//     'email2@example.com',
//   ];

//   void _saveAccountSwitch() {
//     print("Switched active account to: $_activeEmail");

//     // Show a quick success popup
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Switched to $_activeEmail successfully!'),
//         backgroundColor: Colors.green,
//       ),
//     );

//     // Return to the Profile Page
//     Navigator.pop(context);
//   }

//   // --- UPDATED ROUTING LOGIC ---
//   void _createNewAccount() {
//   // Route to the warning screen first!
//   Navigator.push(
//     context,
//     MaterialPageRoute(builder: (context) => const LogoutWarningScreen()),
//   );
// }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF8F6F6), // Theme: Light Mode Background
//       appBar: AppBar(
//         backgroundColor: Colors.black,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: const Text('Inesh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
//         actions: const [
//           Padding(
//             padding: EdgeInsets.only(right: 16.0),
//             child: CircleAvatar(
//               radius: 16,
//               backgroundColor: Color(0xFF66D2A3), // Standard OdoGo Green
//               child: Icon(Icons.person, color: Colors.white, size: 20),
//             ),
//           )
//         ],
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(24.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const Row(
//                 children: [
//                   Text(
//                     'Switch Account',
//                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
//                   ),
//                   SizedBox(width: 12),
//                   Icon(Icons.swap_horiz, color: Color.fromARGB(255, 0, 0, 0), size: 28), // Orange accent
//                 ],
//               ),
//               const SizedBox(height: 32),

//               // Dynamically generates the list of linked accounts
//               ..._linkedAccounts.map((email) {
//                 return Padding(
//                   padding: const EdgeInsets.only(bottom: 12.0),
//                   child: _buildAccountItem(email),
//                 );
//               }),

//               const Spacer(),

//               // Save Button
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF424242),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   ),
//                   onPressed: _saveAccountSwitch,
//                   child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                 ),
//               ),
//               const SizedBox(height: 12),

//               // Create New Button
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: const Color(0xFF424242),
//                     foregroundColor: Colors.white,
//                     padding: const EdgeInsets.symmetric(vertical: 16),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                   ),
//                   onPressed: _createNewAccount, // Now calls the updated routing function
//                   child: const Text('Create New', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // Extracted into a method so we can easily pass the onTap function
//   Widget _buildAccountItem(String email) {
//     bool isActive = _activeEmail == email;
//     return InkWell(
//       onTap: () {
//         setState(() {
//           _activeEmail = email;
//         });
//       },
//       borderRadius: BorderRadius.circular(12),
//       child: Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
//         decoration: BoxDecoration(
//           color: isActive ? Colors.black : const Color(0xFFE0E0E0),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(
//             color: isActive ? const Color.fromARGB(255, 0, 0, 0) : Colors.transparent, // Orange border if active
//             width: 2,
//           ),
//         ),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               email,
//               style: TextStyle(
//                 color: isActive ? Colors.white : Colors.black87,
//                 fontWeight: FontWeight.w600,
//                 fontSize: 16,
//               ),
//             ),
//             if (isActive)
//               const Icon(Icons.check_circle, color: Color.fromARGB(255, 0, 0, 0), size: 20),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added Riverpod
import '../controllers/auth_controller.dart'; // Adjust path
import 'logout_warning_screen.dart';

// Upgraded to ConsumerStatefulWidget
class SwitchAccountScreen extends ConsumerStatefulWidget {
  const SwitchAccountScreen({super.key});

  @override
  ConsumerState<SwitchAccountScreen> createState() =>
      _SwitchAccountScreenState();
}

class _SwitchAccountScreenState extends ConsumerState<SwitchAccountScreen> {
  String? _activeEmail;
  List<String> _linkedAccounts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  // Fetches the data from the controller when the screen opens
  Future<void> _loadAccounts() async {
    final activeUser = ref.read(currentUserProvider);
    final linked = await ref
        .read(authControllerProvider.notifier)
        .getLinkedAccounts();

    setState(() {
      _activeEmail = activeUser?.emailID;
      _linkedAccounts = linked;
      _isLoading = false;
    });
  }

  void _saveAccountSwitch() async {
    if (_activeEmail == null) return;

    // Trigger the backend switch
    await ref
        .read(authControllerProvider.notifier)
        .switchAccount(_activeEmail!);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to $_activeEmail successfully!'),
        backgroundColor: Colors.green,
      ),
    );

    // Return to the Profile Page
    Navigator.pop(context);
  }

  void _createNewAccount() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LogoutWarningScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6F6),
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text(
                    'Switch Account',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 12),
                  Icon(
                    Icons.swap_horiz,
                    color: Color.fromARGB(255, 0, 0, 0),
                    size: 28,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Dynamically generates the list of REAL linked accounts
              ..._linkedAccounts.map((email) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: _buildAccountItem(email),
                );
              }),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF424242),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _saveAccountSwitch,
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF424242),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _createNewAccount,
                  child: const Text(
                    'Log into Another Account',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountItem(String email) {
    bool isActive = _activeEmail == email;
    return InkWell(
      onTap: () {
        setState(() {
          _activeEmail = email;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : const Color(0xFFE0E0E0),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? const Color.fromARGB(255, 0, 0, 0)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              email,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            if (isActive)
              const Icon(
                Icons.check_circle,
                color: Color.fromARGB(255, 0, 0, 0),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
