import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart'; // ADDED: Required to safely route using context.go
import '../controllers/trip_controller.dart'; 

class DriverCancelConfirmationScreen extends ConsumerStatefulWidget {
  final String tripID; 
  
  const DriverCancelConfirmationScreen({super.key, required this.tripID});

  @override
  ConsumerState<DriverCancelConfirmationScreen> createState() => _DriverCancelConfirmationScreenState();
}

class _DriverCancelConfirmationScreenState extends ConsumerState<DriverCancelConfirmationScreen> {
  final Color odogoGreen = const Color(0xFF66D2A3);
  bool _isLoading = false;

  Future<void> _confirmCancel() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Tell the backend to reset the trip
      await ref.read(tripControllerProvider.notifier).cancelRide(widget.tripID);

      if (!mounted) return;

      // 2. Show confirmation snackbar BEFORE routing
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride cancelled successfully'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      // 3. NUCLEAR ROUTING FIX (GoRouter Safe): 
      // This safely tells GoRouter to wipe the current flow and route to the home dashboard.
      context.go('/driver-home');

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error cancelling ride: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Live Dark Map Background
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(26.5123, 80.2329),
              initialZoom: 16.5,
              interactionOptions: InteractionOptions(flags: InteractiveFlag.none),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.odogo_app',
                tileBuilder: (context, tileWidget, tile) {
                  return ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      -0.2126, -0.7152, -0.0722, 0, 255,
                      0,       0,       0,       1, 0,
                    ]),
                    child: tileWidget,
                  );
                },
              ),
              Container(color: Colors.black.withOpacity(0.6)), 
            ],
          ),

          // The Confirmation Card
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Warning Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 48),
                  ),
                  const SizedBox(height: 24),
                  
                  // Text Content
                  const Text(
                    'Cancel Trip?',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Are you sure you want to cancel this ride? You can cancel at most 2 rides in 15 minutes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.4),
                  ),
                  const SizedBox(height: 32),
                  
                  // Action Buttons
                  Column(
                    children: [
                      // NO - Keep the ride
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: odogoGreen,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : () => Navigator.pop(context), 
                          child: const Text('No, Keep Ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // YES - Cancel it
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _isLoading ? Colors.grey : Colors.red, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _isLoading ? null : _confirmCancel,
                          child: _isLoading 
                              ? const SizedBox(
                                  height: 20, 
                                  width: 20, 
                                  child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2)
                                )
                              : const Text('Yes, Cancel Trip', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}