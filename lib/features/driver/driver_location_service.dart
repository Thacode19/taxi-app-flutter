// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';

// class DriverLocationService {
//   StreamSubscription<Position>? _positionStream;

//   void startSharingLocation(String driverId) async {
//     LocationPermission permission =
//         await Geolocator.requestPermission();

//     if (permission == LocationPermission.denied ||
//         permission == LocationPermission.deniedForever) {
//       return;
//     }

//     _positionStream =
//         Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.high,
//         distanceFilter: 1,
//       ),
//     ).listen((Position position) async {
//       await FirebaseFirestore.instance
//           .collection('users')
//           .doc(driverId)
//           .set({
//         'role': 'driver',
//         'isOnline': true,
//         'location': {
//           'lat': position.latitude,
//           'lng': position.longitude,
//         },
//         'updatedAt': FieldValue.serverTimestamp(),
//       }, SetOptions(merge: true));
//     });
//   }

//   void stopSharingLocation() {
//     _positionStream?.cancel();
//   }
// }