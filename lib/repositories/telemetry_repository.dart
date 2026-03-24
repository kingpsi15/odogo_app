import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:odogo_app/models/driver_telemetry_model.dart';

class TelemetryRepository {
  static const String _rtdbRegion = 'asia-southeast1';

  FirebaseDatabase get _rtdb {
    final app = Firebase.app();
    final projectId = app.options.projectId;
    final databaseUrl =
        'https://${projectId}-default-rtdb.${_rtdbRegion}.firebasedatabase.app/';

    return FirebaseDatabase.instanceFor(
      app: app,
      databaseURL: databaseUrl,
    );
  }

  // 🔥 THE FIX: Firebase RTDB paths cannot contain '.', '#', '$', '[', or ']'.
  String _sanitizeID(String id) {
    return id.replaceAll('.', ',');
  }

  /// Driver: Pushes their live location to the RTDB.
  Future<void> updateDriverLocation(DriverTelemetry telemetry) async {
    try {
      final safeID = _sanitizeID(telemetry.driverID);
      await _rtdb
          .ref('drivers_locations/$safeID')
          .set(telemetry.toJson());
    } catch (e) {
      throw Exception('Failed to update telemetry: $e');
    }
  }

  /// Driver: Removes their location from the map when they go offline.
  Future<void> removeDriverLocation(String driverID) async {
    final safeID = _sanitizeID(driverID);
    await _rtdb.ref('drivers_locations/$safeID').remove();
  }

  /// Commuter: Listens to a specific driver's location as they approach.
  Stream<DriverTelemetry?> streamDriverLocation(String driverID) {
    final safeID = _sanitizeID(driverID);
    return _rtdb.ref('drivers_locations/$safeID').onValue.map((event) {
      if (event.snapshot.exists) {
        return DriverTelemetry.fromJson(
          event.snapshot.value as Map<dynamic, dynamic>,
        );
      }
      return null;
    });
  }
}