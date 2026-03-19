import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'commuter_cancel_confirmation_screen.dart';
import 'pickup_confirmed_screen.dart';

class RideConfirmedScreen extends StatefulWidget {
  final LatLng? dropoffPoint;

  const RideConfirmedScreen({super.key, this.dropoffPoint});

  @override
  State<RideConfirmedScreen> createState() => _RideConfirmedScreenState();
}

class _RideConfirmedScreenState extends State<RideConfirmedScreen> {
  static const LatLng _fallbackCurrentLocation = LatLng(26.5123, 80.2329);
  static const LatLng _driverLocation = LatLng(26.5150, 80.2300);
  static const LatLng _fallbackDropoffLocation = LatLng(26.5170, 80.2310);
  static const double _avgDriverSpeedMetersPerSecond = 4.5; // ~16.2 km/h
  static const double _minFitDistanceMeters = 5;
  LatLng _currentLocation = _fallbackCurrentLocation;
  List<LatLng>? _routePoints;
  Timer? _autoAdvanceTimer;
  late LatLng _dropoffLocation;

  @override
  void initState() {
    super.initState();
    _dropoffLocation = widget.dropoffPoint ?? _fallbackDropoffLocation;
    _loadCurrentLocationAndRoute();
    // Auto-advance to pickup confirmed screen after 5 seconds (simulates driver entering OTP)
    _autoAdvanceTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PickupConfirmedScreen(dropoffPoint: _dropoffLocation),
          ),
        );
      }
    });
  }

  Future<void> _loadCurrentLocationAndRoute() async {
    await _setCurrentLocationFromDevice();
    await _loadRoadRoute();
  }

  Future<void> _setCurrentLocationFromDevice() async {
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

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _routePoints = null;
      });
    } catch (_) {
      // Keep fallback location when GPS fetch fails.
    }
  }

  Future<void> _loadRoadRoute() async {
    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_driverLocation.longitude},${_driverLocation.latitude};'
      '${_currentLocation.longitude},${_currentLocation.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) return;

      final firstRoute = routes.first as Map<String, dynamic>;
      final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'];
      if (coordinates is! List) return;

      final points = <LatLng>[];
      for (final item in coordinates) {
        if (item is List && item.length >= 2) {
          final lon = (item[0] as num).toDouble();
          final lat = (item[1] as num).toDouble();
          points.add(LatLng(lat, lon));
        }
      }

      if (!mounted || points.length < 2) return;
      setState(() {
        _routePoints = points;
      });
    } catch (_) {
      // Keep straight-line fallback when routing is unavailable.
    }
  }

  CameraFit? _initialCameraFit() {
    if (_routePoints != null && _routePoints!.length >= 2) {
      final first = _routePoints!.first;
      final last = _routePoints!.last;
      final distanceMeters = Geolocator.distanceBetween(
        first.latitude,
        first.longitude,
        last.latitude,
        last.longitude,
      );
      if (distanceMeters < _minFitDistanceMeters) {
        return null;
      }

      return CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_routePoints!),
        padding: const EdgeInsets.all(32),
      );
    }

    final fallbackDistanceMeters = Geolocator.distanceBetween(
      _driverLocation.latitude,
      _driverLocation.longitude,
      _currentLocation.latitude,
      _currentLocation.longitude,
    );
    if (fallbackDistanceMeters < _minFitDistanceMeters) {
      return null;
    }

    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([_driverLocation, _currentLocation]),
      padding: const EdgeInsets.all(32),
    );
  }

  List<LatLng> _polylinePoints() {
    if (_routePoints != null && _routePoints!.length >= 2) {
      return _routePoints!;
    }
    return [_driverLocation, _currentLocation];
  }

  int get _etaMinutesToPickup {
    final distanceMeters = Geolocator.distanceBetween(
      _driverLocation.latitude,
      _driverLocation.longitude,
      _currentLocation.latitude,
      _currentLocation.longitude,
    );

    final etaMinutes = (distanceMeters / _avgDriverSpeedMetersPerSecond / 60).ceil();
    return etaMinutes < 1 ? 1 : etaMinutes;
  }

  void _cancelTrip(BuildContext context) {
  // Navigate to the confirmation screen instead of instantly canceling
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const CommuterCancelConfirmationScreen()),
  );
}

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _polylinePoints();
    final mapKey =
        '${routePoints.length}-${_currentLocation.latitude.toStringAsFixed(5)}-${_currentLocation.longitude.toStringAsFixed(5)}';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. The Real Live Map Background
          Positioned.fill(
            child: FlutterMap(
              key: ValueKey<String>(mapKey),
              options: MapOptions(
                initialCenter: _currentLocation,
                initialZoom: 16.0,
                initialCameraFit: _initialCameraFit(),
                interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
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
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: Colors.blue,
                    ),
                  ],
                ),
                // Simulated markers for the user and the incoming Rickshaw
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _currentLocation,
                      child: const Icon(Icons.location_on, color: Color(0xFF66D2A3), size: 40),
                    ),
                    // The Incoming Rickshaw Marker
                    Marker(
                      point: _driverLocation, 
                      width: 150,
                      height: 150,
                      child: Image.asset(
                        'assets/images/odogo_logo_without_bg.png', // <-- Put your image path here!
                        fit: BoxFit.contain,
                        // Fallback icon just in case the image path is wrong
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.electric_rickshaw, color: Color(0xFF66D2A3), size: 40),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // 2. Bottom Confirmation Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Title & Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your ride is confirmed',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Meet at the pickup point',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text('$_etaMinutesToPickup', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Text('MINS', style: TextStyle(color: Color(0xFF66D2A3), fontSize: 10, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // PIN Section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PIN for this trip',
                          style: TextStyle(color: Colors.grey[800], fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const Text(
                          '8403',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 6, color: Colors.black),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Driver Info Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF66D2A3).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person, size: 36, color: Color(0xFF66D2A3)),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Arman',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              'UP12 WA 9363 • E-Rickshaw',
                              style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                        child: IconButton(onPressed: () {}, icon: const Icon(Icons.phone_in_talk, color: Colors.black87)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(color: Colors.grey[100], shape: BoxShape.circle),
                        child: IconButton(onPressed: () {}, icon: const Icon(Icons.message_rounded, color: Colors.black87)),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Cancel Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _cancelTrip(context),
                      child: const Text(
                        'Cancel Trip',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}