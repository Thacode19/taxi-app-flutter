// import 'dart:async';

// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';

// class DriverTrackingScreen extends StatefulWidget {
//   final String rideId;

//   const DriverTrackingScreen({super.key, required this.rideId});

//   @override
//   State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
// }

// class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
//   Timer? timer;

//   @override
//   void initState() {
//     super.initState();

//     startTracking();
//   }

//   void startTracking() {
//     timer = Timer.periodic(const Duration(seconds: 3), (timer) async {
//       Position pos = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );

//       await FirebaseFirestore.instance
//           .collection('rides')
//           .doc(widget.rideId)
//           .update({'driverLat': pos.latitude, 'driverLng': pos.longitude});

//       print("Driver updated location");
//     });
//   }

//   @override
//   void dispose() {
//     timer?.cancel();

//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Driver Tracking")),
//       body: const Center(
//         child: Text("Driver is online 🚕", style: TextStyle(fontSize: 22)),
//       ),
//     );
//   }
// }
