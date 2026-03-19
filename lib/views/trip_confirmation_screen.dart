import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'waiting_for_driver_screen.dart'; // Import the waiting screen!

class TripConfirmationScreen extends StatefulWidget {
  final String destination;
  final String pickupLabel;
  final LatLng? pickupPoint;
  final LatLng? dropoffPoint;

  // We pass the searched destination into this screen so it dynamically updates
  const TripConfirmationScreen({
    super.key,
    required this.destination,
    required this.pickupLabel,
    this.pickupPoint,
    this.dropoffPoint,
  });

  @override
  State<TripConfirmationScreen> createState() => _TripConfirmationScreenState();
}

class _TripConfirmationScreenState extends State<TripConfirmationScreen> {
  List<LatLng>? _routePoints;
  static const double _minFitDistanceMeters = 5;

  @override
  void initState() {
    super.initState();
    _loadRoadRoute();
  }

  Future<void> _loadRoadRoute() async {
    final pickup = widget.pickupPoint;
    final dropoff = widget.dropoffPoint;
    if (pickup == null || dropoff == null) return;

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${pickup.longitude},${pickup.latitude};${dropoff.longitude},${dropoff.latitude}'
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
        padding: const EdgeInsets.all(40), // Added more padding so it doesn't hide behind the bottom sheet
      );
    }

    if (widget.pickupPoint == null || widget.dropoffPoint == null) {
      return null;
    }

    final distanceMeters = Geolocator.distanceBetween(
      widget.pickupPoint!.latitude,
      widget.pickupPoint!.longitude,
      widget.dropoffPoint!.latitude,
      widget.dropoffPoint!.longitude,
    );
    if (distanceMeters < _minFitDistanceMeters) {
      return null;
    }

    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([widget.pickupPoint!, widget.dropoffPoint!]),
      padding: const EdgeInsets.all(40),
    );
  }

  List<LatLng>? _polylinePoints() {
    if (_routePoints != null && _routePoints!.length >= 2) {
      return _routePoints;
    }
    if (widget.pickupPoint != null && widget.dropoffPoint != null) {
      return [widget.pickupPoint!, widget.dropoffPoint!];
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _polylinePoints();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black, // Synced to OdoGo theme
        elevation: 0,
        title: const Text('Trip Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 1. FULL SCREEN MAP AREA
          Expanded(
            child: FlutterMap(
              key: ValueKey<int>(routePoints?.length ?? 0),
              options: MapOptions(
                initialCenter: widget.pickupPoint ?? const LatLng(26.5123, 80.2329),
                initialZoom: 15,
                initialCameraFit: _initialCameraFit(),
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
                if (routePoints != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: routePoints,
                        strokeWidth: 5,
                        color: Colors.blue,
                      ),
                    ],
                  ),
                if (widget.pickupPoint != null || widget.dropoffPoint != null)
                  MarkerLayer(
                    markers: [
                      if (widget.pickupPoint != null)
                        Marker(
                          point: widget.pickupPoint!,
                          width: 34,
                          height: 34,
                          child: const Icon(Icons.my_location, color: Color(0xFF66D2A3), size: 28),
                        ),
                      if (widget.dropoffPoint != null)
                        Marker(
                          point: widget.dropoffPoint!,
                          width: 34,
                          height: 34,
                          child: const Icon(Icons.location_on, color: Colors.redAccent, size: 30),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          
          // 2. BOTTOM DETAILS & ACTION SHEET
          Container(
            padding: const EdgeInsets.only(top: 24, left: 20, right: 20, bottom: 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)), // Rounded top corners
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))
              ],
            ),
            child: SafeArea(
              top: false, // Prevents safe area from adding space at the top of the container
              child: Column(
                mainAxisSize: MainAxisSize.min, // Wraps tightly around the content
                children: [
                  // Location Cards
                  _buildLocationCard(
                    icon: Icons.my_location, // Changed to a dot-style icon for pickup
                    label: 'PICKUP',
                    address: widget.pickupLabel,
                  ),
                  const SizedBox(height: 12),
                  _buildLocationCard(
                    icon: Icons.location_on,
                    label: 'DESTINATION',
                    address: widget.destination,
                  ),
                  const SizedBox(height: 24),
                  
                  // Confirm Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => WaitingForDriverScreen(dropoffPoint: widget.dropoffPoint),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66D2A3),
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(56), // Standardized height
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text('Confirm Trip', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard({required IconData icon, required String label, required String address}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F6F6), // Very light grey background to separate from the white sheet
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF66D2A3), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                const SizedBox(height: 4),
                Text(address, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}