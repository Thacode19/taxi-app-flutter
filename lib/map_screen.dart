import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {

  LatLng? currentLocation;

  @override
  void initState() {
    super.initState();
    getLocation();
  }

  Future<void> getLocation() async {

    LocationPermission permission;

    permission = await Geolocator.requestPermission();

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    setState(() {
      currentLocation = LatLng(
          position.latitude,
          position.longitude
      );
    });

  }

  @override
  Widget build(BuildContext context) {

    if(currentLocation == null){
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: FlutterMap(
        options: MapOptions(
          initialCenter: currentLocation!,
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
              Marker(
                point: currentLocation!,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.person_pin_circle,
                  size: 40,
                  color: Colors.red,
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }
}