import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:odogo_app/models/enums.dart';
import 'package:odogo_app/models/vehicle_model.dart';

class UserModel {
  final String userID;
  final String emailID;
  final String name;
  final String phoneNo;
  final String gender;
  final Timestamp dob;
  final UserRole role;
  final List<Timestamp>? cancelHistory; // stores the time stamps of the rides cancelled in last 15 mins

  // Commuter-specific fields
  final List<String>? savedLocations;
  final String? home;

  // Driver-specific fields
  final bool? verificationStatus;
  final String? aadharCard;
  final String? license;
  final VehicleModel? vehicle;
  final DriverMode? mode;
  final double? avgRating;
  final int? ratingCount;

  UserModel({
    required this.userID,
    required this.emailID,
    required this.name,
    required this.phoneNo,
    required this.gender,
    required this.dob,
    required this.role,
    this.savedLocations,
    this.home,
    this.cancelHistory,
    this.verificationStatus,
    this.aadharCard,
    this.license,
    this.vehicle,
    this.mode,
    this.avgRating,
    this.ratingCount,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    var locationsList = json['savedLocations'] as List?;
    List<String>? parsedLocations = locationsList?.cast<String>();

    return UserModel(
      userID: json['userID'] ?? '',
      emailID: json['emailID'] ?? '',
      name: json['name'] ?? '',
      phoneNo: json['phoneNo'] ?? '',
      gender: json['gender'] ?? '',
      dob: json['dob'] as Timestamp,
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.commuter,
      ),
      savedLocations: parsedLocations,
      home: json['home'],
      cancelHistory: json['cancelHistory'] != null
          ? List<Timestamp>.from(json['cancelHistory'])
          : null,
      verificationStatus: json['verificationStatus'],
      aadharCard: json['aadharCard'],
      license: json['license'],
      vehicle: json['vehicle'] != null
          ? VehicleModel.fromJson(json['vehicle'])
          : null,
      mode: json['mode'] != null
          ? DriverMode.values.firstWhere((e) => e.name == json['mode'])
          : null,
      avgRating: (json['avgRating'] as num?)?.toDouble(),
      ratingCount: json['ratingCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'emailID': emailID,
      'name': name,
      'phoneNo': phoneNo,
      'gender': gender,
      'dob': dob,
      'role': role.name,
      if (savedLocations != null) 'savedLocations': savedLocations,
      if (home != null) 'home': home,
      if (cancelHistory != null) 'cancelHistory': cancelHistory,
      if (verificationStatus != null) 'verificationStatus': verificationStatus,
      if (aadharCard != null) 'aadharCard': aadharCard,
      if (license != null) 'license': license,
      if (vehicle != null) 'vehicle': vehicle!.toJson(),
      if (mode != null) 'mode': mode!.name,
      if (avgRating != null) 'avgRating': avgRating,
      if (ratingCount != null) 'ratingCount': ratingCount,
    };
  }
}