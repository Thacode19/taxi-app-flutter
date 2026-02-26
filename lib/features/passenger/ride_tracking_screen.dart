// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class RideTrackingScreen extends StatelessWidget {
  
//   LatLng? userLocation;

//   final String rideId;
// @override
// void initState() {
//   super.initState();
//   loadLocation();
// }

// void loadLocation() async {

//   Position pos = await getUserLocation();

//   setState(() {

//     userLocation = LatLng(
//       pos.latitude,
//       pos.longitude,
//     );

//   });

// }
//   const RideTrackingScreen({
//     super.key,
//     required this.rideId,
//   });





//   @override
//   Widget build(BuildContext context) {

//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Driver Tracking"),
//       ),

//       body: StreamBuilder<DocumentSnapshot>(
//         stream: FirebaseFirestore.instance
//             .collection('rides')
//             .doc(rideId)
//             .snapshots(),

//         builder: (context, snapshot) {

//           if (!snapshot.hasData) {
//             return Center(child: CircularProgressIndicator());
//           }

//           var ride = snapshot.data!;

//           double lat = ride['driverLat'];
//           double lng = ride['driverLng'];

//           LatLng driverLocation = LatLng(lat, lng);

//           return FlutterMap(

//             options: MapOptions(
//               initialCenter: driverLocation,
//               initialZoom: 15,
//             ),

//             children: [

//               TileLayer(
//                 urlTemplate:
// 'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=0i9BZLxl9l3F3rT4froL',
//                 userAgentPackageName: 'com.example.taxi_passenger',
//               ),

//               MarkerLayer(
//                 markers: [

//                   Marker(
//                     point: driverLocation,
//                     width: 80,
//                     height: 80,
//                     child: Icon(
//                       Icons.local_taxi,
//                       size: 40,
//                       color: Colors.blue,
//                     ),
//                   ),

//                 ],
//               ),

//             ],

//           );

//         },

//       ),

//     );

//   }

// }

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;

  const RideTrackingScreen({
    super.key,
    required this.rideId,
  });

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {

  LatLng? userLocation;

  @override
  void initState() {
    super.initState();
    loadLocation();
  }

  Future<Position> getUserLocation() async {
    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  void loadLocation() async {
    try {
      Position pos = await getUserLocation();

      setState(() {
        userLocation = LatLng(
          pos.latitude,
          pos.longitude,
        );
      });
    } catch (e) {
      print("Location error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Tracking"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          var data = snapshot.data!.data() as Map<String, dynamic>;

          double lat = (data['driverLat'] ?? 0).toDouble();
          double lng = (data['driverLng'] ?? 0).toDouble();

          LatLng driverLocation = LatLng(lat, lng);

          return FlutterMap(
            options: MapOptions(
              initialCenter: driverLocation,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.maptiler.com/maps/streets/{z}/{x}/{y}.png?key=0i9BZLxl9l3F3rT4froL',
                userAgentPackageName: 'com.example.taxi_passenger',
              ),
              MarkerLayer(
                markers: [
                  // Driver marker
                  Marker(
                    point: driverLocation,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.local_taxi,
                      size: 40,
                      color: Colors.black,
                    ),
                  ),

                  // User marker
                  if (userLocation != null)
                    Marker(
                      point: userLocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.person_pin_circle,
                        size: 40,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}


  
  





  





 

