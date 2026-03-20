import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:odogo_app/controllers/trip_controller.dart';
import 'package:odogo_app/views/trip_end_request_screen.dart';

class PickupConfirmedScreen extends ConsumerStatefulWidget {
  final LatLng? dropoffPoint;
  final String tripID;

  const PickupConfirmedScreen({super.key, required this.tripID, this.dropoffPoint});

  @override
  ConsumerState<PickupConfirmedScreen> createState() => _PickupConfirmedScreenState();
}

class _PickupConfirmedScreenState extends ConsumerState<PickupConfirmedScreen> {
  final Color odogoGreen = const Color(0xFF66D2A3);
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

  @override
  void initState() {
    super.initState();
    _dropoffLocation = widget.dropoffPoint ?? _fallbackDropoffLocation;
    _initializeTrip();
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

  @override
  void dispose() {
    _userLocationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeTripStreamProvider(widget.tripID), (previous, next) {
      final trip = next.value;
      if (trip != null && trip.driverEnd == true) { 
        // Instantly push the commuter to the final confirmation screen!
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TripEndRequestScreen(tripID: widget.tripID), // Make sure to update this screen to accept the ID too!
          ),
        );
      }
    });
    final activeTripAsync = ref.watch(activeTripStreamProvider(widget.tripID));
    final trip = activeTripAsync.value;
    final routePoints = _polylinePoints();
    final mapKey =
        '${routePoints.length}-${_userLocation.latitude.toStringAsFixed(5)}-${_userLocation.longitude.toStringAsFixed(5)}-${_bottomCardHeight.round()}';
    _measureBottomCardHeight();

    return Scaffold(
      backgroundColor: Colors.black,
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
                      color: odogoGreen,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
                // Markers
                MarkerLayer(
                  markers: [
                    // Current trip position marker
                    Marker(
                      point: _userLocation,
                      width: 56,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(
                          color: odogoGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/odogo_logo_black_bg.jpeg',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
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

          // 2. Back Button Overlay
          Positioned(
            top: 50,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black87,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _cancelRide,
              ),
            ),
          ),

          // 3. Bottom Card (Driver-style layout)
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              key: _bottomCardKey,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 20,
                    color: Colors.black26,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Heading to Drop-off',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: odogoGreen.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '$_etaMinutesToDropoff mins',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on, color: Colors.red, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip?.endLocName ?? '---',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Text(
                              'IIT Kanpur Campus',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32, thickness: 1, color: Colors.black12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        child: const Icon(Icons.person, color: Colors.grey),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          trip?.driverName ?? '---',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.phone_in_talk, color: Colors.grey[700]),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[700]),
                        onPressed: () {},
                      ),
                    ],
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
