import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:odogo_app/controllers/auth_controller.dart';
import 'package:odogo_app/controllers/telemetry_controller.dart';
import 'package:odogo_app/controllers/trip_controller.dart';
import 'package:odogo_app/data/iitk_dropoff_locations.dart';
import 'package:odogo_app/models/driver_telemetry_model.dart';
import 'package:odogo_app/models/enums.dart';
import 'package:odogo_app/models/trip_model.dart';
import 'package:odogo_app/services/contact_launcher_service.dart';
import 'package:odogo_app/services/notification_permission_service.dart';
import 'package:odogo_app/views/driver_home_screen.dart';

class DriverActiveTripScreen extends ConsumerStatefulWidget {
  final LatLng pickupLocation;
  final String tripID;

  const DriverActiveTripScreen({
    super.key,
    required this.tripID,
    required this.pickupLocation,
  });

  @override
  ConsumerState<DriverActiveTripScreen> createState() =>
      _DriverActiveTripScreenState();
}

class _DriverActiveTripScreenState extends ConsumerState<DriverActiveTripScreen> {
  static const LatLng _fallbackDropoffLocation = LatLng(26.5170, 80.2310);
  static const double _avgDriverSpeedMetersPerSecond = 4.5; // ~16.2 km/h
  static const double _minFitDistanceMeters = 5;
  static const double _routeRefreshThresholdMeters = 15;
  static const double _destinationRefreshThresholdMeters = 5;
  final Color odogoGreen = const Color(0xFF66D2A3);

  late LatLng _driverLocation;
  LatLng _dropoffLocation = _fallbackDropoffLocation;
  List<LatLng>? _routePoints;
  LatLng? _lastRouteOrigin;
  bool _isRouteLoading = false;
  bool _dropoffResolvedFromTrip = false;
  
  StreamSubscription<Position>? _driverLocationSubscription;
  final GlobalKey _bottomCardKey = GlobalKey();
  double _bottomCardHeight = 0;

  // 🔥 ADDED: MapController to make the camera follow the car
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  @override
  void initState() {
    super.initState();
    _driverLocation = widget.pickupLocation;
    _initializeTripMap();
  }

  Future<void> _initializeTripMap() async {
    await _setInitialDriverLocation();
    await _startDriverLocationStream();
    await _loadRoadRoute();
  }

  void _syncDropoffFromTrip(TripModel? trip) {
    if (trip == null || _dropoffResolvedFromTrip) return;

    final dropoffName = trip.endLocName;
    if (dropoffName.isEmpty) return;

    final mappedDropoff = DropoffLocation.fromName(dropoffName);
    if (mappedDropoff == null) return;

    final nextDropoff = LatLng(mappedDropoff.latitude, mappedDropoff.longitude);
    final hasChanged =
        Geolocator.distanceBetween(
          _dropoffLocation.latitude,
          _dropoffLocation.longitude,
          nextDropoff.latitude,
          nextDropoff.longitude,
        ) > _destinationRefreshThresholdMeters;

    if (!hasChanged) {
      _dropoffResolvedFromTrip = true;
      return;
    }

    setState(() {
      _dropoffLocation = nextDropoff;
      _routePoints = null;
      _dropoffResolvedFromTrip = true;
    });
    _loadRoadRoute();
  }

  Future<void> _setInitialDriverLocation() async {
    final hasPermission = await _ensureLocationPermission();
    if (!mounted || !hasPermission) return;

    try {
      // 🔥 ADDED: Timeout so weak GPS doesn't freeze the screen
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      
      if (!mounted) return;
      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
      });
      
      // 🔥 FIXED: Removed 'await' so Firebase doesn't block the UI
      _broadcastDriverTelemetry(_driverLocation);
    } catch (_) {
      // Keep fallback/start point if location fetch fails.
    }
  }

  Future<void> _broadcastDriverTelemetry(LatLng location) async {
    final driverID = ref.read(currentUserProvider)?.userID;
    if (driverID == null || driverID.isEmpty) return;

    try {
      await ref
          .read(telemetryControllerProvider)
          .broadcastLocation(
            DriverTelemetry(
              driverID: driverID,
              latitude: location.latitude,
              longitude: location.longitude,
              timestampMs: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    } catch (e) {
      print("Firebase write error: $e");
    }
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return false;
    }
    return await Geolocator.isLocationServiceEnabled();
  }

  Future<void> _startDriverLocationStream() async {
    final hasPermission = await _ensureLocationPermission();
    if (!mounted || !hasPermission) return;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
    );

    _driverLocationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) => _applyDriverLocationUpdate(
            LatLng(position.latitude, position.longitude),
          ),
          onError: (_) {},
        );
  }

  void _applyDriverLocationUpdate(LatLng location) {
    if (!mounted) return;

    setState(() {
      _driverLocation = location;
    });
    
    _broadcastDriverTelemetry(location);

    // 🔥 ADDED: Force camera to smoothly follow the driver
    if (_isMapReady) {
      _mapController.move(location, _mapController.camera.zoom);
    }

    final shouldRefreshRoute =
        _lastRouteOrigin == null ||
        Geolocator.distanceBetween(
              _lastRouteOrigin!.latitude,
              _lastRouteOrigin!.longitude,
              location.latitude,
              location.longitude,
            ) >= _routeRefreshThresholdMeters;

    if (shouldRefreshRoute) {
      _loadRoadRoute();
    }
  }

  Future<void> _loadRoadRoute() async {
    if (_isRouteLoading) return;
    _isRouteLoading = true;

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${_driverLocation.longitude},${_driverLocation.latitude};'
      '${_dropoffLocation.longitude},${_dropoffLocation.latitude}'
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
        _lastRouteOrigin = _driverLocation;
      });
    } catch (_) {
      // Keep straight-line fallback if routing API is unavailable.
    } finally {
      if (mounted) setState(() => _isRouteLoading = false);
    }
  }

  List<LatLng> get _polylinePoints {
    if (_routePoints != null && _routePoints!.length >= 2) {
      // 🔥 FIXED: Dynamically glue the blue route line to the moving car
      return [_driverLocation, ..._routePoints!];
    }
    return [_driverLocation, _dropoffLocation];
  }

  int get _etaMinutesToDropoff {
    final distanceMeters = Geolocator.distanceBetween(
      _driverLocation.latitude,
      _driverLocation.longitude,
      _dropoffLocation.latitude,
      _dropoffLocation.longitude,
    );

    final etaMinutes = (distanceMeters / _avgDriverSpeedMetersPerSecond / 60).ceil();
    return etaMinutes < 1 ? 1 : etaMinutes;
  }

  EdgeInsets _cameraFitPadding() {
    return EdgeInsets.fromLTRB(28, 28, 28, 28 + _bottomCardHeight + 24);
  }

  void _measureBottomCardHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _bottomCardKey.currentContext;
      if (context == null || !mounted) return;

      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) return;

      final measuredHeight = renderObject.size.height;
      if ((measuredHeight - _bottomCardHeight).abs() > 1) {
        setState(() {
          _bottomCardHeight = measuredHeight;
        });
      }
    });
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
      if (distanceMeters < _minFitDistanceMeters) return null;

      return CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_routePoints!),
        padding: _cameraFitPadding(),
      );
    }

    final fallbackDistanceMeters = Geolocator.distanceBetween(
      _driverLocation.latitude,
      _driverLocation.longitude,
      _dropoffLocation.latitude,
      _dropoffLocation.longitude,
    );
    if (fallbackDistanceMeters < _minFitDistanceMeters) return null;

    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([_driverLocation, _dropoffLocation]),
      padding: _cameraFitPadding(),
    );
  }

  Future<void> _endTrip(BuildContext context) async {
    await ref
        .read(tripControllerProvider.notifier)
        .completeRide(tripID: widget.tripID, isDriver: true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip Ended! Waiting for commuter confirmation...'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    final driverID = ref.read(currentUserProvider)?.userID;
    if (driverID != null && driverID.isNotEmpty) {
      ref.read(telemetryControllerProvider).stopBroadcasting(driverID);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(activeTripStreamProvider(widget.tripID), (previous, next) {
      final trip = next.value;
      if (trip != null && trip.status == TripStatus.completed) {
        if (context.mounted) {
          NotificationService().showNotification(
            title: 'Trip Completed',
            body: 'The commuter confirmed the drop-off. You are back online!',
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip Officially Completed!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
            (route) => false, 
          );
        }
      }
    });

    final activeTripAsync = ref.watch(activeTripStreamProvider(widget.tripID));
    final trip = activeTripAsync.value;
    
    // 🔥 FIXED: Safely sync the dropoff info AFTER the build is finished to prevent crashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDropoffFromTrip(trip);
    });

    final commuterInfoAsync = ref.watch(userInfoProvider(trip?.commuterID ?? ''));
    final commuterPhone = commuterInfoAsync.value?.phoneNo;
    final polylinePoints = _polylinePoints;
    
    _measureBottomCardHeight();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              // 🔥 FIXED: Stable key prevents map destruction!
              key: ValueKey<String>(widget.tripID),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _driverLocation,
                initialZoom: 16.0,
                initialCameraFit: _initialCameraFit(),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                // 🔥 FIXED: Unlocks camera tracking only after map exists
                onMapReady: () {
                  _isMapReady = true;
                },
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
                      points: polylinePoints,
                      color: odogoGreen,
                      strokeWidth: 5.0,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driverLocation,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
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
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip?.endLocName ?? '---',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                          trip?.commuterName ?? '---',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.phone_in_talk, color: Colors.grey[700]),
                        onPressed: () => ContactLauncherService.callNumber(context, commuterPhone),
                      ),
                      IconButton(
                        icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[700]),
                        onPressed: () => ContactLauncherService.smsNumber(context, commuterPhone),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () => _endTrip(context),
                      child: const Text(
                        'END TRIP',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 1.2,
                        ),
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