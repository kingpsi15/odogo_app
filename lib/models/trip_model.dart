import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odogo_app/models/enums.dart';

class TripModel {
  final String tripID;
  final TripStatus status;
  final String commuterName;
  final String commuterID;
  final String? driverName; // Nullable until a driver accepts
  final String? driverID; // Nullable until a driver accepts
  final String startLocName;
  final double? startLatitude;
  final double? startLongitude;
  final String endLocName;
  final DateTime? startTime;
  final Timestamp? eta;
  final String ridePIN;
  final bool driverEnd;
  final bool commuterEnd;
  final DateTime? scheduledTime; // Null for immediate rides

  TripModel({
    required this.tripID,
    required this.status,
    required this.commuterName,
    required this.commuterID,
    this.driverName,
    this.driverID,
    required this.startLocName,
    this.startLatitude,
    this.startLongitude,
    required this.endLocName,
    required this.startTime,
    this.eta,
    required this.ridePIN,
    required this.driverEnd,
    required this.commuterEnd,
    this.scheduledTime,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      tripID: json['tripID'] ?? '',
      status: TripStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TripStatus.pending,
      ),
      commuterName: json['commuterName'] ?? '',
      commuterID: json['commuterID'] ?? '',
      driverName: json['driverName'],
      driverID: json['driverID'],
      startLocName: json['startLoc'] ?? '',
      startLatitude: (json['startLatitude'] as num?)?.toDouble(),
      startLongitude: (json['startLongitude'] as num?)?.toDouble(),
      endLocName: json['endLoc'] ?? '',
      startTime: json['startTime'] != null ? (json['startTime'] as Timestamp).toDate() : null,
      eta: json['eta'] as Timestamp?,
      ridePIN: json['ridePIN'] ?? '',
      driverEnd: json['driverEnd'] ?? false,
      commuterEnd: json['commuterEnd'] ?? false,
      scheduledTime: json['scheduledTime'] != null ? (json['scheduledTime'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tripID': tripID,
      'status': status.name,
      'commuterName': commuterName,
      'commuterID': commuterID,
      if (driverName != null) 'driverName': driverName,
      if (driverID != null) 'driverID': driverID,
      'startLoc': startLocName,
      if (startLatitude != null) 'startLatitude': startLatitude,
      if (startLongitude != null) 'startLongitude': startLongitude,
      'endLoc': endLocName,
      if (startTime != null) 'startTime': Timestamp.fromDate(startTime!),
      if (eta != null) 'eta': eta,
      'ridePIN': ridePIN,
      'driverEnd': driverEnd,
      'commuterEnd': commuterEnd,
      if (scheduledTime != null) 'scheduledTime': Timestamp.fromDate(scheduledTime!),
    };
  }
}
