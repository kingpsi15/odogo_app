import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class PickupConfirmedScreen extends StatefulWidget {
  final LatLng? dropoffPoint;

  const PickupConfirmedScreen({super.key, this.dropoffPoint});

  @override
  State<PickupConfirmedScreen> createState() => _PickupConfirmedScreenState();
}

class _PickupConfirmedScreenState extends State<PickupConfirmedScreen> {
  static const LatLng _fallbackUserLocation = LatLng(26.5123, 80.2329);
  static const LatLng _fallbackDropoffLocation = LatLng(26.5170, 80.2310);
  static const double _avgSpeedMetersPerSecond = 4.5; // ~16.2 km/h
  static const double _minFitDistanceMeters = 5;
  static const double _routeRefreshThresholdMeters = 15;

  LatLng _userLocation = _fallbackUserLocation;
  LatLng _dropoffLocation = _fallbackDropoffLocation;
  List<LatLng>? _routePoints;
  bool _isRouteLoading = false;
  StreamSubscription<Position>? _userLocationSubscription;
  final GlobalKey _bottomCardKey = GlobalKey();
  double _bottomCardHeight = 0;
  Timer? _tripEndNotificationTimer;

  @override
  void initState() {
    super.initState();
    _dropoffLocation = widget.dropoffPoint ?? _fallbackDropoffLocation;
    _initializeTrip();
    _scheduleTripEndConfirmationPopup();
  }

  void _scheduleTripEndConfirmationPopup() {
    _tripEndNotificationTimer?.cancel();
    _tripEndNotificationTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        _showTripEndConfirmationDialog();
      }
    });
  }

  Future<void> _initializeTrip() async {
    await _setInitialUserLocation();
    await _startUserLocationStream();
    await _loadRoadRoute();
  }

  Future<void> _setInitialUserLocation() async {
    final hasPermission = await _ensureLocationPermission();
    if (!mounted || !hasPermission) {
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (_) {
      // Keep fallback user location if fetch fails
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    return serviceEnabled;
  }

  Future<void> _startUserLocationStream() async {
    final hasPermission = await _ensureLocationPermission();
    if (!mounted || !hasPermission) {
      return;
    }

    _userLocationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(distanceFilter: 3),
    ).listen((position) {
      if (!mounted) return;

      final newLocation = LatLng(position.latitude, position.longitude);
      final distanceMoved = Geolocator.distanceBetween(
        _userLocation.latitude,
        _userLocation.longitude,
        newLocation.latitude,
        newLocation.longitude,
      );

      setState(() {
        _userLocation = newLocation;
      });

      // Refresh route if user moved 15m+
      if (distanceMoved >= _routeRefreshThresholdMeters) {
        _loadRoadRoute();
      }
    });
  }

  Future<void> _loadRoadRoute() async {
    if (_isRouteLoading) return;

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_userLocation.longitude},${_userLocation.latitude};'
      '${_dropoffLocation.longitude},${_dropoffLocation.latitude}'
      '?overview=full&geometries=geojson',
    );

    setState(() {
      _isRouteLoading = true;
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        setState(() {
          _isRouteLoading = false;
        });
        return;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) {
        setState(() {
          _isRouteLoading = false;
        });
        return;
      }

      final firstRoute = routes.first as Map<String, dynamic>;
      final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'];
      if (coordinates is! List) {
        setState(() {
          _isRouteLoading = false;
        });
        return;
      }

      final points = <LatLng>[];
      for (final item in coordinates) {
        if (item is List && item.length >= 2) {
          final lon = (item[0] as num).toDouble();
          final lat = (item[1] as num).toDouble();
          points.add(LatLng(lat, lon));
        }
      }

      if (!mounted || points.length < 2) {
        setState(() {
          _isRouteLoading = false;
        });
        return;
      }

      setState(() {
        _routePoints = points;
        _isRouteLoading = false;
      });
    } catch (_) {
      setState(() {
        _isRouteLoading = false;
      });
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
        padding: _cameraFitPadding(),
      );
    }

    final distanceMeters = Geolocator.distanceBetween(
      _userLocation.latitude,
      _userLocation.longitude,
      _dropoffLocation.latitude,
      _dropoffLocation.longitude,
    );

    if (distanceMeters < _minFitDistanceMeters) {
      return null;
    }

    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([_userLocation, _dropoffLocation]),
      padding: _cameraFitPadding(),
    );
  }

  EdgeInsets _cameraFitPadding() {
    final baseMargin = 28.0;
    final bottomPadding = _bottomCardHeight + (baseMargin * 1.5);
    return EdgeInsets.only(top: baseMargin, left: baseMargin, right: baseMargin, bottom: bottomPadding);
  }

  void _measureBottomCardHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final renderBox = _bottomCardKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final height = renderBox.size.height;
        if (height != _bottomCardHeight) {
          setState(() {
            _bottomCardHeight = height;
          });
        }
      }
    });
  }

  int get _etaMinutesToDropoff {
    final distanceMeters = Geolocator.distanceBetween(
      _userLocation.latitude,
      _userLocation.longitude,
      _dropoffLocation.latitude,
      _dropoffLocation.longitude,
    );

    final etaMinutes = (distanceMeters / _avgSpeedMetersPerSecond / 60).ceil();
    return etaMinutes < 1 ? 1 : etaMinutes;
  }

  List<LatLng> _polylinePoints() {
    if (_routePoints != null && _routePoints!.length >= 2) {
      return _routePoints!;
    }
    return [_userLocation, _dropoffLocation];
  }

  void _cancelRide() {
    Navigator.pop(context);
  }

  void _showTripEndConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Trip Completed', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Did you reach your destination? Please confirm or decline.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // For testing: if user declines, show the same popup again after 5 seconds.
              _scheduleTripEndConfirmationPopup();
            },
            child: const Text('Decline', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              _tripEndNotificationTimer?.cancel();
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Confirm', style: TextStyle(color: Color(0xFF66D2A3))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tripEndNotificationTimer?.cancel();
    _userLocationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final routePoints = _polylinePoints();
    final mapKey =
        '${routePoints.length}-${_userLocation.latitude.toStringAsFixed(5)}-${_userLocation.longitude.toStringAsFixed(5)}-${_bottomCardHeight.round()}';
    _measureBottomCardHeight();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 1. Live Map with Route
          Positioned.fill(
            child: FlutterMap(
              key: ValueKey<String>(mapKey),
              options: MapOptions(
                initialCenter: _userLocation,
                initialZoom: 16.0,
                initialCameraFit: _initialCameraFit(),
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
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
                // Route Line
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      color: const Color(0xFF66D2A3),
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
                // Markers
                MarkerLayer(
                  markers: [
                    // User Location
                    Marker(
                      point: _userLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Color(0xFF66D2A3), size: 40),
                    ),
                    // Dropoff Location
                    Marker(
                      point: _dropoffLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Back Button
          Positioned(
            top: 50,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _cancelRide,
              ),
            ),
          ),

          // 3. Driver Info Card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              key: _bottomCardKey,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: const [BoxShadow(blurRadius: 20, color: Colors.black45)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: const Color(0xFF66D2A3), size: 18),
                      const SizedBox(width: 8),
                      const Text('Driver has arrived at pickup', 
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 30, 
                        backgroundColor: Color(0xFF66D2A3),
                        child: Icon(Icons.person, color: Colors.white, size: 35),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Arman', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            const Text('E-RICKSHAW', style: TextStyle(color: Colors.grey, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF66D2A3).withOpacity(0.15), 
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('UP12 WA 9363', 
                                style: TextStyle(color: Color(0xFF66D2A3), fontWeight: FontWeight.bold, fontSize: 12)),
                            )
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          _buildCircleAction(Icons.phone, Colors.white24),
                          const SizedBox(width: 8),
                          _buildCircleAction(Icons.chat_bubble, const Color(0xFF66D2A3)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ETA to Dropoff
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF66D2A3).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, color: const Color(0xFF66D2A3), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'ETA: $_etaMinutesToDropoff min',
                          style: const TextStyle(
                            color: Color(0xFF66D2A3),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
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

  Widget _buildCircleAction(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
