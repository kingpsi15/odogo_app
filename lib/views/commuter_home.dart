import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/auth_controller.dart';
import '../data/iitk_dropoff_locations.dart';
import 'bookings_screen.dart';
import 'profile_screen.dart';
import 'trip_confirmation_screen.dart';
import 'schedule_booking_screen.dart';

class CommuterHomeScreen extends ConsumerStatefulWidget {
  const CommuterHomeScreen({super.key});

  @override
  ConsumerState<CommuterHomeScreen> createState() => _CommuterHomeScreenState();
}

class _CommuterHomeScreenState extends ConsumerState<CommuterHomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const _MapHomeView(),
    const BookingsScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number_rounded), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION: The Home (Map) Tab UI
// ============================================================================
class _MapHomeView extends ConsumerStatefulWidget {
  const _MapHomeView();

  @override
  ConsumerState<_MapHomeView> createState() => _MapHomeViewState();
}

class _MapHomeViewState extends ConsumerState<_MapHomeView> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  static const LatLng _defaultCenter = LatLng(26.5123, 80.2329);
  static const double _recenterThresholdMeters = 25;
  static const double _bottomOverlayInset = 20;
  
  LatLng? _currentLocation;
  LatLng? _lastRecenterLocation;
  StreamSubscription<Position>? _locationSubscription;
  final GlobalKey _bottomOverlayKey = GlobalKey();
  double _bottomOverlayHeight = 0;
  
  // Pickup State Variables
  bool _useCurrentLocationAsPickup = true;
  DropoffLocation? _selectedPickupLocation;
  String? _customPickupName; 

  double get _verticalCenterOffsetPx {
    return (_bottomOverlayHeight + _bottomOverlayInset) / 2;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    _enforceLocationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _mapController.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _enforceLocationPermission(); 
    }
  }

  Future<void> _enforceLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    
    if (!serviceEnabled) {
      await _showBlockingDialog(
        title: 'GPS is Disabled',
        message: 'OdoGo requires GPS to find rides. Please turn on your location services.',
        buttonText: 'Open Settings',
        onAction: () => Geolocator.openLocationSettings(),
      );
      return; 
    }

    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        await _showBlockingDialog(
          title: 'Location Required',
          message: 'We absolutely need your location to connect you with drivers. Please allow access.',
          buttonText: 'Try Again',
          onAction: () => _enforceLocationPermission(),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      await _showBlockingDialog(
        title: 'Permission Denied',
        message: 'You have permanently denied location access. You must open your phone settings, find OdoGo, and allow location access to use the app.',
        buttonText: 'Open App Settings',
        onAction: () => Geolocator.openAppSettings(),
      );
      return;
    }

    _startLocationStream();
  }

  Future<void> _showBlockingDialog({required String title, required String message, required String buttonText, required VoidCallback onAction}) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => PopScope(
        canPop: false, 
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF66D2A3), foregroundColor: Colors.black),
              onPressed: () {
                Navigator.pop(context); 
                onAction(); 
              },
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _startLocationStream() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3);
    
    _locationSubscription?.cancel(); 
    _locationSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) {
        _applyLocationUpdate(LatLng(position.latitude, position.longitude));
      },
      onError: (_) {},
    );
  }

  void _applyLocationUpdate(LatLng location) {
    if (!mounted) return;
    setState(() => _currentLocation = location);

    final shouldRecenter = _lastRecenterLocation == null ||
        Geolocator.distanceBetween(
          _lastRecenterLocation!.latitude, _lastRecenterLocation!.longitude,
          location.latitude, location.longitude,
        ) >= _recenterThresholdMeters;

    if (!shouldRecenter) return;

    _lastRecenterLocation = location;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(location, _mapController.camera.zoom, offset: Offset(0, -_verticalCenterOffsetPx));
    });
  }

  void _measureBottomOverlayHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _bottomOverlayKey.currentContext;
      if (context == null || !mounted) return;
      final renderObject = context.findRenderObject();
      if (renderObject is! RenderBox) return;
      final measuredHeight = renderObject.size.height;
      if ((measuredHeight - _bottomOverlayHeight).abs() < 1) return;
      setState(() => _bottomOverlayHeight = measuredHeight);
    });
  }

  void _openTripConfirmation({required String destinationName, DropoffLocation? dropoff}) {
    final pickupPoint = _resolvedPickupPoint();
    final dropoffPoint = dropoff == null ? null : LatLng(dropoff.latitude, dropoff.longitude);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripConfirmationScreen(
          destination: destinationName,
          pickupLabel: _buildPickupLabel(),
          pickupPoint: pickupPoint,
          dropoffPoint: dropoffPoint,
        ),
      ),
    );
  }

  LatLng? _resolvedPickupPoint() {
    if (_useCurrentLocationAsPickup) return _currentLocation;
    if (_selectedPickupLocation != null) return LatLng(_selectedPickupLocation!.latitude, _selectedPickupLocation!.longitude);
    return _currentLocation; 
  }

  DropoffLocation? _resolveDropoffLocation(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final location in iitkDropoffLocations) {
      if (location.name.toLowerCase() == normalized) return location;
    }
    for (final location in iitkDropoffLocations) {
      if (location.matches(normalized)) return location;
    }
    return null;
  }

  String _buildPickupLabel() {
    if (_customPickupName != null) return _customPickupName!;
    if (!_useCurrentLocationAsPickup && _selectedPickupLocation != null) return _selectedPickupLocation!.name;
    final nearest = _nearestCampusLocationName();
    return nearest == null ? 'Near your current location' : 'Near $nearest';
  }

  String? _nearestCampusLocationName() {
    final current = _currentLocation;
    if (current == null || iitkDropoffLocations.isEmpty) return null;

    DropoffLocation nearest = iitkDropoffLocations.first;
    double nearestDistance = Geolocator.distanceBetween(current.latitude, current.longitude, nearest.latitude, nearest.longitude);

    for (final location in iitkDropoffLocations.skip(1)) {
      final distance = Geolocator.distanceBetween(current.latitude, current.longitude, location.latitude, location.longitude);
      if (distance < nearestDistance) {
        nearest = location;
        nearestDistance = distance;
      }
    }
    return nearest.name;
  }

  // --- PICKUP SELECTOR ---
  Future<void> _openPickupSelector() async {
    String localSearchText = '';
    
    final user = ref.read(currentUserProvider);
    final homeAddress = (user?.roomNo != null && user!.roomNo!.isNotEmpty) ? user.roomNo : null;
    final workAddress = (user?.savedLocations != null && user!.savedLocations!.isNotEmpty && user.savedLocations![0].isNotEmpty) 
        ? user.savedLocations![0] 
        : null;
    
    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            
            List<DropoffLocation> sheetFiltered = localSearchText.isEmpty 
              ? iitkDropoffLocations 
              : iitkDropoffLocations.where((loc) => 
                  loc.name.toLowerCase().contains(localSearchText.toLowerCase()) || 
                  loc.matches(localSearchText) 
                ).toList();

            bool showHome = homeAddress != null && (localSearchText.isEmpty || 'home'.contains(localSearchText.toLowerCase()) || homeAddress.toLowerCase().contains(localSearchText.toLowerCase()));
            bool showWork = workAddress != null && (localSearchText.isEmpty || 'work'.contains(localSearchText.toLowerCase()) || workAddress.toLowerCase().contains(localSearchText.toLowerCase()));

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), 
              child: Container(
                decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.65,
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Text('Choose Pickup Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: TextField(
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search or type custom location...',
                              prefixIcon: const Icon(Icons.search, color: Colors.black54),
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: (val) {
                              setSheetState(() => localSearchText = val);
                            },
                          ),
                        ),

                        ListTile(
                          leading: const Icon(Icons.my_location, color: Color(0xFF66D2A3)),
                          title: const Text('Use current location', style: TextStyle(fontWeight: FontWeight.bold)),
                          onTap: () => Navigator.pop(sheetContext, null),
                        ),

                        if (showHome)
                          ListTile(
                            leading: const Icon(Icons.home, color: Colors.black54),
                            title: const Text('Home', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(homeAddress!, style: const TextStyle(color: Colors.grey)),
                            onTap: () => Navigator.pop(sheetContext, homeAddress),
                          ),
                        
                        if (showWork)
                          ListTile(
                            leading: const Icon(Icons.work, color: Colors.black54),
                            title: const Text('Work', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(workAddress!, style: const TextStyle(color: Colors.grey)),
                            onTap: () => Navigator.pop(sheetContext, workAddress),
                          ),
                        
                        if (localSearchText.isNotEmpty && sheetFiltered.isEmpty && !showHome && !showWork)
                          ListTile(
                            leading: const Icon(Icons.edit_location_alt, color: Colors.black),
                            title: Text('Set pickup as "$localSearchText"', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () => Navigator.pop(sheetContext, localSearchText), 
                          ),

                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: sheetFiltered.length,
                            itemBuilder: (context, index) {
                              final location = sheetFiltered[index];
                              return ListTile(
                                leading: const Icon(Icons.place_outlined, color: Colors.black54),
                                title: Text(location.name),
                                onTap: () => Navigator.pop(sheetContext, location), 
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );

    if (!mounted) return;
    
    // ---> FIX: Resolve the Home/Work string into a real GPS coordinate for Pickup <---
    setState(() {
      if (selected == null) {
        _useCurrentLocationAsPickup = true;
        _selectedPickupLocation = null;
        _customPickupName = null;
      } else if (selected is String) {
        _useCurrentLocationAsPickup = false;
        
        // Try to match the Home/Work string to actual IITK coordinates
        final matchedLoc = _resolveDropoffLocation(selected);
        if (matchedLoc != null) {
          _selectedPickupLocation = matchedLoc;
          _customPickupName = null;
        } else {
          // If it really doesn't exist, treat it as custom text
          _selectedPickupLocation = null;
          _customPickupName = selected; 
        }
      } else if (selected is DropoffLocation) {
        _useCurrentLocationAsPickup = false;
        _selectedPickupLocation = selected;
        _customPickupName = null;
      }
    });
  }

  // --- DROPOFF SELECTOR ---
  Future<void> _openDropoffSelector() async {
    String localSearchText = '';
    
    final user = ref.read(currentUserProvider);
    final homeAddress = (user?.roomNo != null && user!.roomNo!.isNotEmpty) ? user.roomNo : null;
    final workAddress = (user?.savedLocations != null && user!.savedLocations!.isNotEmpty && user.savedLocations![0].isNotEmpty) 
        ? user.savedLocations![0] 
        : null;
        
    final selected = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, 
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            
            List<DropoffLocation> sheetFiltered = localSearchText.isEmpty 
              ? iitkDropoffLocations 
              : iitkDropoffLocations.where((loc) => 
                  loc.name.toLowerCase().contains(localSearchText.toLowerCase()) || 
                  loc.matches(localSearchText) 
                ).toList();

            bool showHome = homeAddress != null && (localSearchText.isEmpty || 'home'.contains(localSearchText.toLowerCase()) || homeAddress.toLowerCase().contains(localSearchText.toLowerCase()));
            bool showWork = workAddress != null && (localSearchText.isEmpty || 'work'.contains(localSearchText.toLowerCase()) || workAddress.toLowerCase().contains(localSearchText.toLowerCase()));

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), 
              child: Container(
                decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                child: SafeArea(
                  bottom: false,
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.65,
                    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                          child: Text('Choose Dropoff Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                        
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: TextField(
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: 'Search or type custom destination...',
                              prefixIcon: const Icon(Icons.search, color: Colors.black54),
                              filled: true,
                              fillColor: Colors.grey[200],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                            ),
                            onChanged: (val) {
                              setSheetState(() => localSearchText = val);
                            },
                          ),
                        ),

                        if (showHome)
                          ListTile(
                            leading: const Icon(Icons.home, color: Colors.black54),
                            title: const Text('Home', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(homeAddress!, style: const TextStyle(color: Colors.grey)),
                            onTap: () => Navigator.pop(sheetContext, homeAddress),
                          ),
                        
                        if (showWork)
                          ListTile(
                            leading: const Icon(Icons.work, color: Colors.black54),
                            title: const Text('Work', style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(workAddress!, style: const TextStyle(color: Colors.grey)),
                            onTap: () => Navigator.pop(sheetContext, workAddress),
                          ),
                        
                        if (localSearchText.isNotEmpty && sheetFiltered.isEmpty && !showHome && !showWork)
                          ListTile(
                            leading: const Icon(Icons.edit_location_alt, color: Colors.black),
                            title: Text('Drop off at "$localSearchText"', style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () => Navigator.pop(sheetContext, localSearchText), 
                          ),

                        const Divider(height: 1),
                        Expanded(
                          child: ListView.builder(
                            itemCount: sheetFiltered.length,
                            itemBuilder: (context, index) {
                              final location = sheetFiltered[index];
                              return ListTile(
                                leading: const Icon(Icons.place_outlined, color: Colors.black54),
                                title: Text(location.name),
                                onTap: () => Navigator.pop(sheetContext, location), 
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        );
      },
    );

    if (!mounted || selected == null) return;
    
    // ---> FIX: Resolve the Home/Work string into a real GPS coordinate for Dropoff <---
    if (selected is String) {
      final matchedDropoff = _resolveDropoffLocation(selected);
      
      _openTripConfirmation(
        destinationName: matchedDropoff?.name ?? selected, // Uses the official name if found
        dropoff: matchedDropoff // Passes the coordinates so the map draws the line!
      );
    } else if (selected is DropoffLocation) {
      _openTripConfirmation(destinationName: selected.name, dropoff: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    _measureBottomOverlayHeight();

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation ?? _defaultCenter,
            initialZoom: 15.0,
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
                    0, 0, 0, 1, 0,
                  ]),
                  child: tileWidget,
                );
              },
            ),
            if (_currentLocation != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _currentLocation!,
                    width: 36,
                    height: 36,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF66D2A3),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.my_location, color: Colors.black, size: 18),
                    ),
                  ),
                ],
              ),
          ],
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Image.asset(
                  'assets/images/odogo_logo_black_bg.jpeg',
                  height: 50,
                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.local_taxi, color: Colors.greenAccent, size: 40),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduleBookingScreen()));
                  },
                  icon: const Icon(Icons.calendar_month, color: Colors.black),
                  label: const Text('Schedule\nbookings', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF66D2A3),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            key: _bottomOverlayKey,
            margin: const EdgeInsets.only(bottom: 20),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.all(Radius.circular(24)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))],
            ),
            width: MediaQuery.of(context).size.width * 0.92,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F6F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: Color(0xFF66D2A3)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pickup: ${_buildPickupLabel()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                      ),
                      TextButton(
                        onPressed: _openPickupSelector,
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
                
                GestureDetector(
                  onTap: _openDropoffSelector,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F6F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.redAccent),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Dropoff',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                          ),
                        ),
                        TextButton(
                          onPressed: _openDropoffSelector,
                          child: const Text('Search'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}