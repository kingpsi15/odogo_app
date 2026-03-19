// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import '../services/email_link_auth_service.dart';
// import 'sign_up_page.dart';
// import 'commuter_home.dart';
// import 'driver_home_screen.dart';

// class OtpPage extends StatefulWidget {
//   final bool isDriver;
//   final String email;
//   final bool isSignUp;

//   const OtpPage({
//     super.key,
//     required this.isDriver,
//     required this.email,
//     required this.isSignUp,
//   });

//   @override
//   State<OtpPage> createState() => _OtpPageState();
// }

// class _OtpPageState extends State<OtpPage> {
//   final TextEditingController _otpController = TextEditingController();
//   bool _isLoading = false;

//   String _extractErrorMessage(Object error) {
//     if (error is StateError) {
//       return error.message;
//     }

//     final raw = error.toString();
//     if (raw.startsWith('Exception: ')) {
//       return raw.replaceFirst('Exception: ', '').trim();
//     }

//     return raw;
//   }

//   @override
//   void dispose() {
//     _otpController.dispose();
//     super.dispose();
//   }

//   void _showError(String message) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text(message), backgroundColor: Colors.red),
//     );
//   }

//   Future<void> _handleContinue() async {
//     final otp = _otpController.text.trim();

//     if (otp.isEmpty) {
//       _showError('Please enter the OTP.');
//       return;
//     }

//     if (otp.length != 4) {
//       _showError('Please enter the full 4-digit OTP.');
//       return;
//     }

//     if (!RegExp(r'^[0-9]+$').hasMatch(otp)) {
//       _showError('OTP can only contain numbers.');
//       return;
//     }

//     FocusScope.of(context).unfocus();

//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       final verified = EmailOtpAuthService.instance.verifyOtp(
//         email: widget.email,
//         otp: otp,
//       );

//       if (!verified) {
//         if (!mounted) return;
//         _showError('Invalid or expired OTP. Please try again.');
//         return;
//       }

//       if (!mounted) return;

//       if (widget.isSignUp) {
//         Navigator.push(
//           context,
//           MaterialPageRoute(
//             builder: (context) => SignUpPage(isDriver: widget.isDriver),
//           ),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Welcome back to OdoGo!'),
//             backgroundColor: Color(0xFF66D2A3),
//           ),
//         );

//         if (widget.isDriver) {
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
//             (route) => false,
//           );
//         } else {
//           Navigator.pushAndRemoveUntil(
//             context,
//             MaterialPageRoute(builder: (context) => const CommuterHomeScreen()),
//             (route) => false,
//           );
//         }
//       }
//     } catch (e) {
//       if (!mounted) return;
//       final message = 'Could not verify OTP. Please request a new one.';
//       _showError(message);
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   Future<void> _resendLink() async {
//     setState(() {
//       _isLoading = true;
//     });

//     try {
//       await EmailOtpAuthService.instance.sendOtp(email: widget.email);

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('A new sign-in email has been sent.')),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       _showError(_extractErrorMessage(e));
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.black),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SafeArea(
//         child: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.symmetric(horizontal: 40),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               ClipRRect(
//                 borderRadius: BorderRadius.circular(16),
//                 child: Image.asset('assets/images/odogo_logo.png', height: 80),
//               ),
//               const SizedBox(height: 10),
//               const Text('OdoGo', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black)),
//               const SizedBox(height: 40),

//               const Text(
//                         'We sent a 4-digit OTP to your email.\nEnter it below to continue.',
//                 textAlign: TextAlign.center,
//                 style: TextStyle(fontSize: 14, color: Colors.grey),
//               ),
//               const SizedBox(height: 20),

//               Container(
//                 width: double.infinity,
//                 padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   widget.email.isEmpty ? 'name@domain.com' : widget.email,
//                   style: const TextStyle(fontSize: 16, color: Colors.black87),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//               const SizedBox(height: 20),

//               TextField(
//                 controller: _otpController,
//                 keyboardType: TextInputType.number,
//                 textAlign: TextAlign.center,
//                 maxLength: 4,
//                 inputFormatters: [
//                   FilteringTextInputFormatter.digitsOnly,
//                 ],
//                 decoration: InputDecoration(
//                   hintText: 'Enter 4-digit OTP',
//                   hintStyle: const TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.normal,
//                     letterSpacing: 0,
//                     color: Colors.grey,
//                   ),
//                   counterText: '',
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//                   contentPadding: const EdgeInsets.symmetric(vertical: 15),
//                 ),
//                 style: const TextStyle(fontSize: 24, letterSpacing: 8.0, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 20),

//               ElevatedButton(
//                 onPressed: _isLoading ? null : _handleContinue,
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: Colors.grey[300],
//                   foregroundColor: Colors.black,
//                   minimumSize: const Size(double.infinity, 50),
//                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                   elevation: 0,
//                 ),
//                 child: _isLoading
//                     ? const SizedBox(
//                         height: 20,
//                         width: 20,
//                         child: CircularProgressIndicator(strokeWidth: 2),
//                       )
//                     : const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
//               ),
//               const SizedBox(height: 10),
//               TextButton(
//                 onPressed: _isLoading ? null : _resendLink,
//                 child: const Text('Resend OTP'),
//               ),
//               const SizedBox(height: 40),
//             ],
//           ),
//         ),
//         ),
//       ),
//     );
//   }
// }

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../models/enums.dart';

class OtpPage extends ConsumerStatefulWidget {
  final bool isDriver;
  final String email;
  final bool isSignUp;

  const OtpPage({
    super.key,
    required this.isDriver,
    required this.email,
    required this.isSignUp,
  });

  @override
  ConsumerState<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends ConsumerState<OtpPage> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _handleAuthenticated(AuthAuthenticated authState) async {
    final user = authState.user;
    final actualIsDriver = user.role == UserRole.driver;
    final selectedRoleLabel = widget.isDriver ? 'driver' : 'commuter';
    final actualRoleLabel = actualIsDriver ? 'driver' : 'commuter';

    if (widget.isDriver != actualIsDriver) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This email is registered as a $actualRoleLabel account. Logging you in as $actualRoleLabel.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      // Small delay so the user can read the role mismatch message.
      await Future.delayed(const Duration(milliseconds: 900));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Signed in as $selectedRoleLabel.'),
          backgroundColor: const Color(0xFF66D2A3),
        ),
      );
      await Future.delayed(const Duration(milliseconds: 400));
    }

    if (!mounted) return;
    final needsDocs = actualIsDriver && user.vehicle == null;
    if (needsDocs) {
      context.go('/driver-docs');
      return;
    }

    context.go(actualIsDriver ? '/driver-home' : '/commuter-home');
  }

  Future<void> _handleContinue() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showError('Please enter the OTP.');
      return;
    }

    if (otp.length != 4) {
      _showError('Please enter the full 4-digit OTP.');
      return;
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(otp)) {
      _showError('OTP can only contain numbers.');
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    // 1. Tell Controller to Verify & Save
    await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(widget.email, otp);

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // 2. Handle the Result cleanly
    if (authState is AuthError) {
      _showError(authState.message);
    } else if (authState is AuthNeedsProfileSetup) {
      context.go(
        '/account-not-found',
        extra: {
          'isDriver': widget.isDriver,
          'email': widget.email,
        },
      );
    } else if (authState is AuthAuthenticated) {
      await _handleAuthenticated(authState);
    }
  }

  Future<void> _resendLink() async {
    setState(() {
      _isLoading = true;
    });

    // 7. Update resend to use the controller as well
    await ref.read(authControllerProvider.notifier).sendOtp(widget.email);

    final authState = ref.read(authControllerProvider);

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (authState is AuthError) {
        _showError(authState.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new sign-in email has been sent.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/odogo_logo.png',
                    height: 80,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'OdoGo',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 40),

                const Text(
                  'We sent a 4-digit OTP to your email.\nEnter it below to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 20),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                    horizontal: 20,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    widget.email.isEmpty ? 'name@domain.com' : widget.email,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    hintText: 'Enter 4-digit OTP',
                    hintStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      letterSpacing: 0,
                      color: Colors.grey,
                    ),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isLoading ? null : _handleContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isLoading ? null : _resendLink,
                  child: const Text('Resend OTP'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
