import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odogo_app/controllers/auth_controller.dart';
import 'package:odogo_app/models/enums.dart';
import '../models/user_model.dart';
import '../models/trip_model.dart';
import '../repositories/trip_repository.dart';

final tripRepositoryProvider = Provider((ref) => TripRepository());

// We use this to constantly re-evaluate the scheduled ride time windows!
final timeTickerProvider = StreamProvider<DateTime>((ref) {
  return Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});

// Stream for Drivers to see available rides
final pendingTripsProvider = StreamProvider<List<TripModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  // If the driver is currently busy, cut off the broadcast stream so they do not receive any more pending ride requests.
  if (currentUser?.mode == DriverMode.busy) {
    return Stream.value([]);
  }
  // 1. Get the LIVE ticking time
  final now = ref.watch(timeTickerProvider).value ?? DateTime.now();
  final tripsStream = ref.watch(tripRepositoryProvider).streamPendingTrips();

  //Old: return ref.watch(tripRepositoryProvider).streamPendingTrips();

  // 3. Apply the Smart Filtering
  return tripsStream.map((trips) {
    return trips.where((trip) {
      // Immediate rides are always visible
      if (trip.status == TripStatus.pending) return true;

      // Scheduled rides follow the exact broadcast rules
      if (trip.status == TripStatus.scheduled && trip.scheduledTime != null) {
        final scheduledTime = trip.scheduledTime!.toDate();
        final diff = scheduledTime.difference(now);
        final minutesLeft = diff.inMinutes;

        // "inMinutes" truncates. So if diff is 120m 59s, it stays '120' for exactly 1 minute.
        // This perfectly matches your "broadcast for 1 minute" requirement!
        if (minutesLeft == 120) return true; // 2 hours prior
        if (minutesLeft == 60) return true; // 1 hour prior
        if (minutesLeft == 30) return true; // 30 mins prior

        // Continuous broadcast starting 15 mins prior (up until 1 hr after in case of delays)
        if (minutesLeft <= 15 && minutesLeft >= -60) return true;
      }

      // If it doesn't match the time windows, keep it hidden from the driver!
      return false;
    }).toList();
  });
});

// Stream for Commuters to watch their specific active ride
final activeTripStreamProvider = StreamProvider.family<TripModel?, String>((
  ref,
  tripID,
) {
  // Changed to ref.watch for better reactivity
  return ref.watch(tripRepositoryProvider).streamTrip(tripID);
});

final tripControllerProvider =
    NotifierProvider<TripController, AsyncValue<void>>(() {
      return TripController();
    });

// 1. Fetches specific user details (like phone numbers) on the fly
final userInfoProvider = FutureProvider.family<UserModel?, String>((
  ref,
  uid,
) async {
  if (uid.isEmpty) return null;
  return await ref.read(userRepositoryProvider).getUser(uid);
});

// 2. Centralized Commuter Trips Stream
final commuterTripsProvider = StreamProvider.autoDispose<List<TripModel>>((
  ref,
) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('trips')
      .where('commuterID', isEqualTo: currentUser.userID)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => TripModel.fromJson(doc.data())).toList(),
      );
});

// 3. Centralized Driver Trips Stream
final driverTripsProvider = StreamProvider.autoDispose<List<TripModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('trips')
      .where('driverID', isEqualTo: currentUser.userID)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => TripModel.fromJson(doc.data())).toList(),
      );
});

// 2. UPDATED to Notifier
class TripController extends Notifier<AsyncValue<void>> {
  // 3. Notifiers use build() to set the initial state instead of super()
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  // Getter to access the repository using the internal 'ref'
  TripRepository get _repository => ref.read(tripRepositoryProvider);

  Future<void> requestRide(TripModel trip) async {
    state = const AsyncValue.loading();
    try {
      await _repository.createTrip(trip);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Driver: Accepts a pending ride
  Future<void> acceptRide(
    String tripID,
    String driverName,
    String driverID,
  ) async {
    state = const AsyncValue.loading();
    try {
      print('DEBUG: acceptRide called for tripID=$tripID, driverID=$driverID');
      
      // 1. Assign driver and confirm trip
      await _repository.updateTripData(tripID, {
        'status': TripStatus.confirmed.name,
        'driverName': driverName,
        'driverID': driverID,
      });
      print('DEBUG: Trip updated to confirmed');

      // Set the driver's mode to busy
      await ref.read(userRepositoryProvider).updateUser(driverID, {
        'mode': DriverMode.busy.name,
      });
      print('DEBUG: Driver mode set to busy');

      // Refresh local user state so the pendingTripsProvider instantly cuts off
      await ref.read(authControllerProvider.notifier).refreshUser();
      print('DEBUG: User refreshed');

      // Verify the mode was actually set
      final updatedUser = ref.read(currentUserProvider);
      print('DEBUG: Updated user mode: ${updatedUser?.mode}');

      state = const AsyncValue.data(null);
    } catch (e, st) {
      print('DEBUG: acceptRide error: $e');
      print('DEBUG: Stack trace: $st');
      state = AsyncValue.error(e, st);
    }
  }

  /// Driver: Marks the ride as picked up / in progress
  Future<void> startRide(String tripID) async {
    state = const AsyncValue.loading();
    try {
      await _repository.updateTripData(tripID, {'status': 'ongoing'});
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// User/Driver: Cancels the ride with smart constraint rules and re-broadcasting
  Future<void> cancelRide(String tripID) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) throw Exception("User not authenticated.");

      // 1. Fetch trip data FIRST to understand the current state
      final tripDoc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripID)
          .get();
      if (!tripDoc.exists) throw Exception("Trip not found");
      final tripData = tripDoc.data() as Map<String, dynamic>;

      // Determine roles and trip state
      final bool isDriverCancelling = currentUser.role == UserRole.driver;
      final bool isCommuterCancelling = currentUser.role == UserRole.commuter;
      final bool hasDriverAccepted = tripData['driverID'] != null;

      // 2. Determine if the strike constraint applies
      bool applyConstraint = true;

      // RULE: Free cancellation for commuters if no driver has accepted yet
      if (isCommuterCancelling && !hasDriverAccepted) {
        applyConstraint = false;
      }

      final now = DateTime.now();
      List<Timestamp> recentCancels = [];

      // 3. Enforce the 15-minute constraint if applicable
      if (applyConstraint) {
        final fifteenMinsAgo = now.subtract(const Duration(minutes: 15));

        recentCancels =
            currentUser.cancelHistory?.where((timestamp) {
              return timestamp.toDate().isAfter(fifteenMinsAgo);
            }).toList() ??
            [];

        if (recentCancels.length >= 2) {
          throw Exception("You can cancel a maximum of 2 rides in 15 minutes.");
        }
      }

      // 4. Execute the specific cancellation logic based on WHO is cancelling
      if (isDriverCancelling) {
        // RULE: Driver cancels. Re-broadcast the trip!
        // We set status back to pending and completely delete the driverID from the document.
        await _repository.updateTripData(tripID, {
          'status': TripStatus.pending.name,
          'driverID': FieldValue.delete(),
        });

        // Free up this driver so they can receive other broadcasts
        await ref.read(userRepositoryProvider).updateUser(currentUser.userID, {
          'mode': DriverMode.online.name,
        });
      } else if (isCommuterCancelling) {
        // RULE: Commuter cancels. The trip is dead.
        await _repository.updateTripData(tripID, {
          'status': TripStatus.cancelled.name,
        });

        // If a driver was already attached to this doomed trip, free them up!
        if (hasDriverAccepted) {
          await ref.read(userRepositoryProvider).updateUser(
            tripData['driverID'],
            {'mode': DriverMode.online.name},
          );
        }
      }

      // 5. Record the strike ONLY if the constraint applied
      if (applyConstraint) {
        recentCancels.add(Timestamp.fromDate(now));
        await ref.read(userRepositoryProvider).updateUser(currentUser.userID, {
          'cancelHistory': recentCancels,
        });
      }

      // Sync the local user state
      await ref.read(authControllerProvider.notifier).refreshUser();

      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// User: Marks their side of the ride as complete
  Future<void> completeRide({
    required String tripID,
    required bool isDriver,
  }) async {
    state = const AsyncValue.loading();
    try {
      // Updates either 'driverEnd' or 'commuterEnd' to true based on who called it
      await _repository.updateTripData(tripID, {
        isDriver ? 'driverEnd' : 'commuterEnd': true,
      });
      // RULE 3: Fetch the trip to check if BOTH parties have marked it as completed
      final tripDoc = await FirebaseFirestore.instance
          .collection('trips')
          .doc(tripID)
          .get();
      final tripData = tripDoc.data() as Map<String, dynamic>;

      final driverEnd = tripData['driverEnd'] ?? false;
      final commuterEnd = tripData['commuterEnd'] ?? false;

      // If both are true, finalize the ride and free the driver
      if (driverEnd && commuterEnd) {
        await _repository.updateTripData(tripID, {
          'status': TripStatus.completed.name,
        });

        // Revert the driver back to online so they can accept new rides
        final assignedDriverID = tripData['driverID'];
        if (assignedDriverID != null) {
          await ref.read(userRepositoryProvider).updateUser(assignedDriverID, {
            'mode': DriverMode.online.name,
          });
        }

        // Trigger Background Cleanup ---
        final commuterID = tripData['commuterID'];
        if (commuterID != null)
          _repository.cleanupOldTrips(commuterID, 'commuterID');
        if (assignedDriverID != null)
          _repository.cleanupOldTrips(assignedDriverID, 'driverID');
      }

      // Sync the state (especially critical if this user is the driver transitioning back to online)
      await ref.read(authControllerProvider.notifier).refreshUser();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  //ScheduleRide Function
  Future<void> scheduleRide(TripModel trip) async {
    state = const AsyncValue.loading();
    try {
      // Saves the trip to Firestore exactly like a normal ride, but with the 'scheduled' status
      await _repository.createTrip(trip);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
