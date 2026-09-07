 import 'package:flutter/material.dart';
import 'package:taxi_passenger/map_screen.dart';
import './features/passenger/ride_tracking_screen.dart';
import './infoscreen.dart';
//import './testscreen.dart';
import './features/auth/auth_gate.dart';
import './features/driver/driver_request_screen.dart';
import './features/auth/login_screen.dart';
import './features/driver/driver_register_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
    //home: DriverRequestScreen(driverId: "driver_001",),
      home: AuthGate(),
      //home: TestScreen(),
      //home: MapScreen(),
      //home: RideTrackingScreen(),
      //home: LoginScreen(),
      //home: DriverRegisterScreen(),

    );
  }
}
