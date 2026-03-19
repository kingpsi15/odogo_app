import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added Riverpod
import '../controllers/auth_controller.dart'; // Tapping into your auth controller

class EmailEditScreen extends ConsumerStatefulWidget {
  const EmailEditScreen({super.key});

  @override
  ConsumerState<EmailEditScreen> createState() => _EmailEditScreenState();
}

class _EmailEditScreenState extends ConsumerState<EmailEditScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEmail();
  }

  // The new Riverpod-powered fetch function
  void _loadEmail() {
    // Read the current user state directly from your provider
    final activeUser = ref.read(currentUserProvider);

    setState(() {
      // Use the exact same emailID property from your SwitchAccountScreen logic
      if (activeUser != null && activeUser.emailID.isNotEmpty) {
        _controller.text = activeUser.emailID;
      } else {
        _controller.text = "No email linked";
      }
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Inesh', style: TextStyle(color: Colors.white)),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF66D2A3), // OdoGo Green
              child: Icon(Icons.person, color: Colors.white, size: 20),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.email_outlined, size: 40, color: Colors.black87),
                  SizedBox(width: 12),
                  Text(
                    'Email', 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              // Loading state or the Read-Only TextField
              _isLoading 
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF66D2A3)))
                  : TextField(
                      controller: _controller,
                      readOnly: true, // Prevents typing and locks the keyboard
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      style: const TextStyle(fontSize: 18, color: Colors.black87),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}