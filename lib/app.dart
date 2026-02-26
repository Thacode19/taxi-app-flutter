 import 'package:flutter/material.dart';
import 'package:taxi_passenger/map_screen.dart';
import './features/passenger/ride_tracking_screen.dart';
import './features/auth/auth_gate.dart';
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AuthGate(),
      //home: MapScreen(),
      //home: RideTrackingScreen(),
    );
  }
}
