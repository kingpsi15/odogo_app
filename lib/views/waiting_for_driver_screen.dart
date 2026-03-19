import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'ride_confirmed_screen.dart';

class WaitingForDriverScreen extends StatefulWidget {
  final LatLng? dropoffPoint;

  const WaitingForDriverScreen({super.key, this.dropoffPoint});

  @override
  State<WaitingForDriverScreen> createState() => _WaitingForDriverScreenState();
}

class _WaitingForDriverScreenState extends State<WaitingForDriverScreen> {
  @override
  void initState() {
    super.initState();
    // Simulates the backend finding a driver after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => RideConfirmedScreen(dropoffPoint: widget.dropoffPoint),
          ),
        );
      }
    });
  }
  void _cancelRide() {
    // Show a cancellation popup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ride request cancelled.'),
        backgroundColor: Colors.red,
      ),
    );
    // Return to the home map
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true, // Lets the map slide cleanly under the top bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70, // Gives the header a bit more breathing room
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 10)]),
          onPressed: _cancelRide,
        ),
        // Synced Logo from Commuter Home
        title: Image.asset(
          'assets/images/odogo_logo_black_bg.jpeg', 
          height: 40,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_taxi, color: Color(0xFF66D2A3), size: 40),
        ),
        actions: [
          // Synced Schedule Button from Commuter Home
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () {
                print("Schedule Bookings Clicked from Waiting Screen");
              },
              icon: const Icon(Icons.calendar_month, color: Colors.black, size: 18),
              label: const Text(
                'Schedule\nbookings', 
                style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF66D2A3), // Standard OdoGo Green
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // The Live Map Section
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  options: const MapOptions(
                    initialCenter: LatLng(26.5123, 80.2329), // IIT Kanpur Coordinates
                    initialZoom: 16.0,
                    interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.odogo_app',
                      // Dark mode filter perfectly matching the home screen
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
                  ],
                ),
                // The central location pin synced to OdoGo Green
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40.0), // Offset slightly to point exactly at the center
                    child: Icon(Icons.location_on, color: Color(0xFF66D2A3), size: 56),
                  ),
                ),
              ],
            ),
          ),
          
          // The Status Bottom Sheet
          Container(
            padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 40),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -5))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TRIP STATUS', style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 8),
                const Text('WAITING FOR DRIVER', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black87)),
                const SizedBox(height: 24),
                
                // Infinite loading animation synced to OdoGo Green
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    color: const Color(0xFF66D2A3),
                  ),
                ),
                
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF66D2A3).withOpacity(0.15), 
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF66D2A3).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF66D2A3)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Cancellation Policy: You can cancel at most 2 times in 15 minutes.',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _cancelRide,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Cancel Ride', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}