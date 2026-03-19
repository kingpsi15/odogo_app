import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:geolocator/geolocator.dart';

import 'package:latlong2/latlong.dart';

import 'package:odogo_app/controllers/auth_controller.dart';

import 'package:odogo_app/controllers/trip_controller.dart';

import 'package:odogo_app/controllers/user_controller.dart';

import 'package:odogo_app/models/enums.dart';

import 'package:odogo_app/models/trip_model.dart';

import 'dart:async';

// 1. LINKING THE PROFILE & BOOKINGS PAGES

import 'driver_profile_screen.dart';

import 'driver_bookings_screen.dart';

import 'driver_active_pickup_screen.dart';

class DriverHomeScreen extends ConsumerStatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  ConsumerState<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends ConsumerState<DriverHomeScreen> {
  final Color odogoGreen = const Color(0xFF66D2A3);

  final MapController _mapController = MapController();

  static const LatLng _defaultCenter = LatLng(26.5123, 80.2329);

  static const double _recenterThresholdMeters = 25;

  static const double _bottomOverlayInset = 20;

  LatLng? _currentLocation;

  LatLng? _lastRecenterLocation;

  StreamSubscription<Position>? _locationSubscription;

  final GlobalKey _bottomOverlayKey = GlobalKey();

  double _bottomOverlayHeight = 0;

  double get _verticalCenterOffsetPx {
    return (_bottomOverlayHeight + _bottomOverlayInset) / 2;
  }

  void _measureBottomOverlayHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _bottomOverlayKey.currentContext;

      if (context == null || !mounted) return;

      final renderObject = context.findRenderObject();

      if (renderObject is! RenderBox) return;

      final measuredHeight = renderObject.size.height;

      if ((measuredHeight - _bottomOverlayHeight).abs() < 1) return;

      setState(() {
        _bottomOverlayHeight = measuredHeight;
      });
    });
  }

  // --- NAVIGATION STATE ---

  int _selectedIndex = 0; // 0 = Map, 1 = Bookings, 2 = Profile

  // --- MAP STATE ---

  // bool _isOnline = false;

  // bool _hasIncomingRequest = false;

  // Timer? _simulationTimer;

  @override
  void initState() {
    super.initState();

    _startLocationStream();
  }

  Future<void> _startLocationStream() async {
    // Request permission first — before checking service, so the dialog appears.

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (!mounted) return;

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled || !mounted) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,

      distanceFilter: 3,
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            _applyLocationUpdate(LatLng(position.latitude, position.longitude));
          },

          onError: (_) {},
        );
  }

  void _applyLocationUpdate(LatLng location) {
    if (!mounted) return;

    setState(() {
      _currentLocation = location;
    });

    final shouldRecenter =
        _lastRecenterLocation == null ||
        Geolocator.distanceBetween(
              _lastRecenterLocation!.latitude,

              _lastRecenterLocation!.longitude,

              location.latitude,

              location.longitude,
            ) >=
            _recenterThresholdMeters;

    if (!shouldRecenter) {
      return;
    }

    _lastRecenterLocation = location;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final zoom = _mapController.camera.zoom;

      _mapController.move(
        location,

        zoom,

        offset: Offset(0, -_verticalCenterOffsetPx),
      );
    });
  }

  @override
  void dispose() {
    _mapController.dispose();

    _locationSubscription?.cancel();

    super.dispose();
  }

  // --- BOTTOM NAV LOGIC ---

  void _onBottomNavTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _toggleOnlineState() async {
    // 1. Get the current user to check their status

    final currentUser = ref.read(currentUserProvider);

    if (currentUser == null) return;

    // 2. Determine what the NEW mode should be

    final isCurrentlyOnline = currentUser.mode == DriverMode.online;

    final newMode = isCurrentlyOnline ? DriverMode.offline : DriverMode.online;

    // 3. Tell the backend to update the database

    await ref.read(userControllerProvider.notifier).updateDriverMode(newMode);

    // 4. Show the SnackBar

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newMode == DriverMode.online
                ? 'You are now ONLINE.'
                : 'You are OFFLINE.',
          ),

          backgroundColor: newMode == DriverMode.online
              ? odogoGreen
              : Colors.red,

          duration: const Duration(seconds: 2),
        ),
      );
    }

    // void _acceptRide() {

    // // Push to the active pickup screen!

    // Navigator.push(

    // context,

    // MaterialPageRoute(builder: (context) => const DriverActivePickupScreen()),

    // );
  }

  @override // Removed the duplicate @override
  Widget build(BuildContext context) {
    _measureBottomOverlayHeight();

    // WATCH THE BACKEND FOR REAL-TIME STATUS

    final currentUser = ref.watch(currentUserProvider);

    final _isOnline = currentUser?.mode == DriverMode.online;

    // --- THE REAL BACKEND CONNECTION ---

    // Watch the stream of pending trips

    final pendingTripsAsync = ref.watch(pendingTripsProvider);

    // Extract the list (default to empty if loading/error)

    final availableTrips = pendingTripsAsync.value ?? [];

    // Grab the first trip in the queue, if any exist

    final incomingTrip = availableTrips.isNotEmpty
        ? availableTrips.first
        : null;

    return Scaffold(
      backgroundColor: Colors.white,

      body: IndexedStack(
        index: _selectedIndex,

        children: [
          _buildMapHome(_isOnline, incomingTrip),

          const DriverBookingsScreen(),

          const DriverProfileScreen(),
        ],
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,

        onTap: _onBottomNavTapped,

        selectedItemColor: Colors.black,

        unselectedItemColor: Colors.grey,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.confirmation_number_rounded),
            label: 'Bookings',
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ==========================================

  // VIEW 1: THE MAP DASHBOARD

  // ==========================================

  Widget _buildMapHome(bool _isOnline, TripModel? incomingTrip) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,

          options: MapOptions(
            initialCenter: _currentLocation ?? _defaultCenter,

            initialZoom: 16.0,
          ),

          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

              userAgentPackageName: 'com.example.odogo_app',

              tileBuilder: (context, tileWidget, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,

                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,

                    -0.2126,
                    -0.7152,
                    -0.0722,
                    0,
                    255,

                    0,
                    0,
                    0,
                    1,
                    0,
                  ]),

                  child: tileWidget,
                );
              },
            ),

            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation ?? _defaultCenter,

                  // 1. ADJUST THESE: The total size of the circular map pin
                  width: 56,

                  height: 56,

                  child: Container(
                    decoration: BoxDecoration(
                      color: _isOnline ? odogoGreen : Colors.grey,

                      shape: BoxShape.circle,

                      border: Border.all(color: Colors.white, width: 2),
                    ),

                    // 2. ADJUST THIS: The spacing between the white border and the logo
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),

                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/odogo_logo_black_bg.jpeg',

                          // 3. THIS KEEPS IT FROM CLIPPING
                          fit: BoxFit.contain,

                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                color: Colors.black,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        Positioned(
          top: 50,

          left: 20,

          right: 20,

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,

            children: [
              Column(
                children: [
                  Image.asset(
                    'assets/images/odogo_logo_black_bg.jpeg',

                    height: 40,

                    errorBuilder: (context, error, stackTrace) =>
                        Icon(Icons.broken_image, color: odogoGreen, size: 40),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'OdoGo',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),

              GestureDetector(
                onTap: _toggleOnlineState,

                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),

                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),

                  decoration: BoxDecoration(
                    color: _isOnline ? Colors.black87 : odogoGreen,

                    borderRadius: BorderRadius.circular(20),

                    border: Border.all(
                      color: _isOnline ? odogoGreen : Colors.transparent,
                      width: 2,
                    ),
                  ),

                  child: Row(
                    children: [
                      Switch(
                        value: _isOnline,

                        onChanged: (v) => _toggleOnlineState(),

                        activeThumbColor: odogoGreen,

                        inactiveThumbColor: Colors.black,

                        inactiveTrackColor: Colors.black26,
                      ),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,

                        children: [
                          Text(
                            'Go',
                            style: TextStyle(
                              color: _isOnline ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Text(
                            _isOnline ? 'Offline' : 'Online',
                            style: TextStyle(
                              color: _isOnline ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        Positioned(
          bottom: 20,

          left: 20,

          right: 20,

          child: Column(
            key: _bottomOverlayKey,

            mainAxisSize: MainAxisSize.min,

            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),

                width: double.infinity,

                padding: const EdgeInsets.symmetric(vertical: 16),

                decoration: BoxDecoration(
                  color: _isOnline ? odogoGreen.withOpacity(0.1) : Colors.white,

                  border: Border.all(
                    color: _isOnline ? odogoGreen : Colors.black,
                    width: 2,
                  ),

                  borderRadius: BorderRadius.circular(30),
                ),

                child: Center(
                  child: _isOnline
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [
                            // 1. Replaced !_hasIncomingRequest with checking the real trip!
                            if (incomingTrip == null) ...[
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: odogoGreen,
                                  strokeWidth: 2.5,
                                ),
                              ),

                              const SizedBox(width: 12),

                              const Text(
                                'Searching for rides...',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Ride Found!',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        )
                      : const Text(
                          'You are Offline',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: Colors.black,
                          ),
                        ),
                ),
              ),

              if (incomingTrip != null) ...[
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),

                    borderRadius: BorderRadius.circular(20),

                    color: Colors.white,
                  ),

                  child: Column(
                    children: [
                      const Text(
                        'Incoming Request',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // 3. Replaced hardcoded text with REAL database fields!
                      _buildMapInfoRow('Passenger:', incomingTrip.commuterName),

                      _buildMapInfoRow('Pickup:', incomingTrip.startLocName),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,

                        children: [
                          _buildMapInfoRow('Drop:', incomingTrip.endLocName),

                          ElevatedButton(
                            onPressed: () async {
                              final currentUserName = ref
                                  .read(currentUserProvider)
                                  ?.name;

                              final currentUserId = ref
                                  .read(currentUserProvider)
                                  ?.userID;

                              if (currentUserName != null &&
                                  currentUserId != null) {
                                // 1. Execute your robust backend method

                                await ref
                                    .read(tripControllerProvider.notifier)
                                    .acceptRide(
                                      incomingTrip.tripID,

                                      currentUserName,

                                      currentUserId,
                                    );

                                // 2. Navigate away from the searching screen

                                if (mounted) {
                                  Navigator.pushReplacement(
                                    context,

                                    MaterialPageRoute(
                                      builder: (context) =>
                                          DriverActivePickupScreen(
                                            tripID: incomingTrip.tripID,
                                          ),
                                    ),
                                  );
                                }
                              }
                            },

                            style: ElevatedButton.styleFrom(
                              backgroundColor: odogoGreen,

                              foregroundColor: Colors.black,

                              side: const BorderSide(
                                color: Colors.black,
                                width: 2,
                              ),

                              shape: const StadiumBorder(),
                            ),

                            child: const Text(
                              'Accept',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),

      child: Row(
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black,
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
