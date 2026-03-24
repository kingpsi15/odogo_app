import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:odogo_app/views/driver_home_screen.dart';
import 'driver_active_trip_screen.dart';
import 'driver_cancel_confirmation_screen.dart';
import '../services/notification_permission_service.dart';

class DriverActivePickupScreen extends ConsumerStatefulWidget {
  final String tripID;
  const DriverActivePickupScreen({super.key, required this.tripID});

  @override
  ConsumerState<DriverActivePickupScreen> createState() =>
      _DriverActivePickupScreenState();
}

class _DriverActivePickupScreenState extends ConsumerState<DriverActivePickupScreen> {
  final Color odogoGreen = const Color(0xFF66D2A3);
  final Color etaOrange = const Color(0xFFEC5B13);
  static const LatLng _fallbackDriverLocation = LatLng(26.5100, 80.2300);
  static const LatLng _fallbackPickupLocation = LatLng(26.5140, 80.2340);
  static const double _avgDriverSpeedMetersPerSecond = 4.5; 
  static const double _minFitDistanceMeters = 5;
  static const double _routeRefreshThresholdMeters = 15;
  static const double _destinationRefreshThresholdMeters = 5;
  
  LatLng _driverLocation = _fallbackDriverLocation;
  LatLng _pickupLocation = _fallbackPickupLocation;
  List<LatLng>? _routePoints;
  LatLng? _lastRouteOrigin;
  bool _isRouteLoading = false;
  bool _pickupResolvedFromTrip = false;
  
  StreamSubscription<Position>? _driverLocationSubscription;
  final GlobalKey _bottomCardKey = GlobalKey();
  double _bottomCardHeight = 0;

  // 🔥 ADDED: MapController for active camera tracking
  final MapController _mapController = MapController();
  bool _isMapReady = false;

  // Focus nodes for the 4 PIN boxes
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  final List<TextEditingController> _controllers = List.generate(4, (index) => TextEditingController());

  @override
  void initState() {
    super.initState();
    _initializeTripMap();
  }

  Future<void> _initializeTripMap() async {
    await _setInitialDriverLocation();
    await _startDriverLocationStream();
    await _loadRoadRoute();
  }

  Future<void> _setInitialDriverLocation() async {
    final hasPermission = await _ensureLocationPermission();
    if (!mounted || !hasPermission) return;

    try {
      // 🔥 ADDED: Timeout to prevent GPS from hanging the app
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10));
      
      if (!mounted) return;
      setState(() {
        _driverLocation = LatLng(position.latitude, position.longitude);
      });
      
      // 🔥 FIXED: Removed blocking await
      _broadcastDriverTelemetry(_driverLocation);
    } catch (_) {}
  }

  Future<void> _broadcastDriverTelemetry(LatLng location) async {
    final driverID = ref.read(currentUserProvider)?.userID;
    if (driverID == null || driverID.isEmpty) return;

    try {
      await ref.read(telemetryControllerProvider).broadcastLocation(
        DriverTelemetry(
          driverID: driverID,
          latitude: location.latitude,
          longitude: location.longitude,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (e) {
      print("Telemetry Error: $e");
    }
  }

  void _syncPickupFromTrip(TripModel? trip) {
    if (trip == null || _pickupResolvedFromTrip) return;

    LatLng? nextPickup;

    if (trip.startLatitude != null && trip.startLongitude != null) {
      nextPickup = LatLng(trip.startLatitude!, trip.startLongitude!);
    } else if (trip.startLocName.isNotEmpty) {
      final mappedPickup = DropoffLocation.fromName(trip.startLocName);
      if (mappedPickup != null) {
        nextPickup = LatLng(mappedPickup.latitude, mappedPickup.longitude);
      }
    }

    if (nextPickup == null) return;

    final hasChanged = Geolocator.distanceBetween(
      _pickupLocation.latitude,
      _pickupLocation.longitude,
      nextPickup.latitude,
      nextPickup.longitude
    ) > _destinationRefreshThresholdMeters;

    if (!hasChanged) {
      _pickupResolvedFromTrip = true;
      return;
    }

    setState(() {
      _pickupLocation = nextPickup!;
      _routePoints = null;
      _pickupResolvedFromTrip = true;
    });
    _loadRoadRoute();
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

    _driverLocationSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) => _applyDriverLocationUpdate(LatLng(position.latitude, position.longitude)),
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

    final shouldRefreshRoute = _lastRouteOrigin == null ||
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
      '${_pickupLocation.longitude},${_pickupLocation.latitude}'
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
          points.add(LatLng((item[1] as num).toDouble(), (item[0] as num).toDouble()));
        }
      }

      if (!mounted || points.length < 2) return;
      setState(() {
        _routePoints = points;
        _lastRouteOrigin = _driverLocation;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRouteLoading = false);
    }
  }

  List<LatLng> get _polylinePoints {
    if (_routePoints != null && _routePoints!.length >= 2) {
      // 🔥 FIXED: Blue line is now glued to the moving car
      return [_driverLocation, ..._routePoints!];
    }
    return [_driverLocation, _pickupLocation];
  }

  EdgeInsets _cameraFitPadding() {
    return EdgeInsets.fromLTRB(28, 28, 28, 28 + _bottomCardHeight);
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

  int get _etaMinutesToPickup {
    final distanceMeters = Geolocator.distanceBetween(
      _driverLocation.latitude,
      _driverLocation.longitude,
      _pickupLocation.latitude,
      _pickupLocation.longitude,
    );

    final etaMinutes = (distanceMeters / _avgDriverSpeedMetersPerSecond / 60).ceil();
    return etaMinutes < 1 ? 1 : etaMinutes;
  }

  CameraFit? _initialCameraFit() {
    if (_routePoints != null && _routePoints!.length >= 2) {
      final distanceMeters = Geolocator.distanceBetween(
        _routePoints!.first.latitude, _routePoints!.first.longitude,
        _routePoints!.last.latitude, _routePoints!.last.longitude,
      );
      if (distanceMeters < _minFitDistanceMeters) return null;

      return CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(_routePoints!),
        padding: _cameraFitPadding(),
      );
    }

    final distanceMeters = Geolocator.distanceBetween(
      _driverLocation.latitude, _driverLocation.longitude,
      _pickupLocation.latitude, _pickupLocation.longitude,
    );

    if (distanceMeters < 10) return null;

    return CameraFit.bounds(
      bounds: LatLngBounds.fromPoints([_driverLocation, _pickupLocation]),
      padding: _cameraFitPadding(),
    );
  }

  @override
  void dispose() {
    _driverLocationSubscription?.cancel();
    final driverID = ref.read(currentUserProvider)?.userID;
    if (driverID != null && driverID.isNotEmpty) {
      ref.read(telemetryControllerProvider).stopBroadcasting(driverID);
    }
    // 🔥 FIXED: Removed duplicate dispose loops
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _verifyPinAndStartTrip() async {
    final trip = ref.read(activeTripStreamProvider(widget.tripID)).value;
    if (trip == null) return;

    String enteredPin = _controllers.map((c) => c.text).join();

    if (enteredPin == trip.ridePIN) {
      FocusScope.of(context).unfocus();
      await ref.read(tripControllerProvider.notifier).startRide(widget.tripID);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DriverActiveTripScreen(
              pickupLocation: _pickupLocation,
              tripID: trip.tripID,
            ),
          ),
        );
      }
    } else if (enteredPin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the full 4-digit PIN.'), backgroundColor: Colors.orange),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect PIN. Please try again.'), backgroundColor: Colors.red),
      );
      for (var controller in _controllers) {
        controller.clear();
      }
      FocusScope.of(context).requestFocus(_focusNodes[0]);
    }
  }

  void _cancelTrip() {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DriverCancelConfirmationScreen(tripID: widget.tripID)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTripAsync = ref.watch(activeTripStreamProvider(widget.tripID));
    final trip = activeTripAsync.value;
    
    // 🔥 FIXED: Safely sync data after build phase to prevent UI crashes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPickupFromTrip(trip);
    });
    
    final commuterInfoAsync = ref.watch(userInfoProvider(trip?.commuterID ?? ''));
    final commuterPhone = commuterInfoAsync.value?.phoneNo;

    ref.listen<AsyncValue<TripModel?>>(activeTripStreamProvider(widget.tripID), (previous, next) {
      final currentTrip = next.value;
      final prevTrip = previous?.value;

      if (currentTrip != null && currentTrip.status == TripStatus.cancelled && prevTrip?.status != TripStatus.cancelled) {
        if (mounted) {
          NotificationService().showNotification(title: 'Ride Cancelled', body: 'The commuter cancelled the ride.');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ride cancelled by commuter'), backgroundColor: Colors.red, duration: Duration(seconds: 2)),
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
                (route) => false,
              );
            }
          });
        }
      }
    });

    final polylinePoints = _polylinePoints;
    _measureBottomCardHeight();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              // 🔥 FIXED: Stable key!
              key: ValueKey<String>(widget.tripID),
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _pickupLocation,
                initialZoom: 16.5,
                initialCameraFit: _initialCameraFit(),
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                // 🔥 FIXED: Unlocks camera tracking safely
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
                    Polyline(points: polylinePoints, color: odogoGreen, strokeWidth: 5.0),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _driverLocation,
                      width: 56,
                      height: 56,
                      child: Container(
                        decoration: BoxDecoration(color: odogoGreen, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: Padding(
                          padding: const EdgeInsets.all(4.0),
                          child: ClipOval(child: Image.asset('assets/images/odogo_logo_black_bg.jpeg', fit: BoxFit.contain)),
                        ),
                      ),
                    ),
                    Marker(
                      point: _pickupLocation,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on, color: Colors.white, size: 40),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              key: _bottomCardKey,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -5))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You have confirmed the ride', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)),
                          SizedBox(height: 4),
                          Text('Meet at the pickup point', style: TextStyle(color: Colors.grey, fontSize: 14)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: odogoGreen.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text('$_etaMinutesToPickup mins', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ENTER PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.5)),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) => _buildPinBox(index)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      CircleAvatar(backgroundColor: Colors.grey[300], child: const Icon(Icons.person, color: Colors.grey)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(trip?.commuterName ?? '---', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(child: Text('Pickup: ${trip?.startLocName ?? '---'}', style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(icon: Icon(Icons.phone_in_talk, color: Colors.grey[700]), onPressed: () => ContactLauncherService.callNumber(context, commuterPhone)),
                      IconButton(icon: Icon(Icons.chat_bubble_outline, color: Colors.grey[700]), onPressed: () => ContactLauncherService.smsNumber(context, commuterPhone)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: _cancelTrip,
                          child: const Text('Cancel Trip', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: odogoGreen, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16), elevation: 0),
                          onPressed: _verifyPinAndStartTrip,
                          child: const Text('Start Trip', style: TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildPinBox(int index) {
    return Container(
      width: 55,
      height: 65,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 2)),
      child: Center(
        child: TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          inputFormatters: [LengthLimitingTextInputFormatter(1)],
          decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
          onChanged: (value) {
            if (value.isNotEmpty) {
              if (index < 3) FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
              else FocusScope.of(context).unfocus();
            } else if (value.isEmpty && index > 0) {
              FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
            }
          },
        ),
      ),
    );
  }
}