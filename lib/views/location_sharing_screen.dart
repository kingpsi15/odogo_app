import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../controllers/auth_controller.dart'; // Adjust path if needed

class LocationSharingScreen extends ConsumerStatefulWidget {
  const LocationSharingScreen({super.key});

  @override
  ConsumerState<LocationSharingScreen> createState() => _LocationSharingScreenState();
}

class _LocationSharingScreenState extends ConsumerState<LocationSharingScreen> {
  bool _isSharingLocation = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  // 1. Fetch current status when screen opens
  Future<void> _initializeSettings() async {
    final user = ref.read(currentUserProvider);
    
    // Check OS-level permissions
    var status = await Permission.location.status;

    // Check database-level preference (default to false if not set)
    // Assuming you have an 'isLocationShared' boolean in your user model, 
    // otherwise we just rely on the OS status for the initial UI load
    bool userPref = status.isGranted; 

    setState(() {
      _isSharingLocation = userPref && status.isGranted;
      _isLoading = false;
    });
  }

  // 2. Handle the toggle switch
  Future<void> _handleToggle(bool value) async {
    if (value) {
      // User wants to turn it ON -> Ask OS for permission
      var status = await Permission.location.request();
      
      if (status.isGranted) {
        setState(() => _isSharingLocation = true);
      } else if (status.isPermanentlyDenied) {
        // OS blocked us, guide them to phone settings
        _showSettingsDialog();
      } else {
        // User hit "Deny"
        setState(() => _isSharingLocation = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to share location.'), 
              backgroundColor: Colors.red
            ),
          );
        }
      }
    } else {
      // User wants to turn it OFF -> Update local state
      setState(() => _isSharingLocation = false);
    }
  }

  // 3. Prompt user to open iOS/Android settings if permanently denied
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Permission Required', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Location access was denied. Please enable it in your device settings to share your live location with drivers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel', style: TextStyle(color: Colors.grey))
          ),
          TextButton(
            onPressed: () {
              openAppSettings(); // Native bridge to phone settings
              Navigator.pop(context);
            },
            child: const Text('Open Settings', style: TextStyle(color: Color(0xFF66D2A3), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // 4. Save to Firebase Database
  Future<void> _saveSettings() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Update the user's document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.userID).update({
        'isLocationShared': _isSharingLocation,
      });

      // Refresh Riverpod state to keep everything synced
      await ref.read(authControllerProvider.notifier).refreshUser();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location settings saved successfully!'), 
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Dynamically grab the user's name for the AppBar
    final activeUser = ref.watch(currentUserProvider);
    final displayName = activeUser?.name ?? 'Profile';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        toolbarHeight: 80,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 20,
              backgroundColor: Color(0xFF66D2A3),
              child: Icon(Icons.person, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(
              displayName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF66D2A3)))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location Sharing',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A)),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      value: _isSharingLocation,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.black, // Sleek black track when ON
                      inactiveThumbColor: Colors.grey,
                      onChanged: _handleToggle, // Triggers the OS logic
                      title: const Text('Share my Location', style: TextStyle(fontWeight: FontWeight.bold)),
                      secondary: Icon(
                        Icons.my_location, 
                        color: _isSharingLocation ? const Color(0xFF66D2A3) : Colors.grey // Turns green when ON
                      ),
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Settings', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }
}