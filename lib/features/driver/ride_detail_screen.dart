import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'driver_ride_control.dart';

class RideDetailScreen extends StatefulWidget {
  final String rideId;
  final String driverId;

  const RideDetailScreen({
    super.key,
    required this.rideId,
    required this.driverId,
  });

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  final MapController mapController = MapController();
  final Map<String, String> _addressCache = {};

  bool isAccepting = false;
  List<LatLng> routePoints = [];
  String? lastRouteKey;

  LatLng? driverLocation;
  List<LatLng> driverToPickupRoute = [];
  double? driverToPickupKm;
  String? lastDriverRouteKey;

  @override
  void initState() {
    super.initState();
    _loadDriverLocation();
  }

  Future<void> _loadDriverLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        driverLocation = LatLng(position.latitude, position.longitude);
      });
    } catch (e) {
      debugPrint("Driver location error: $e");
    }
  }

  Future<void> fetchDriverToPickupRoute(LatLng driver, LatLng pickup) async {
    final key = '${driver.latitude},${driver.longitude}-'
        '${pickup.latitude},${pickup.longitude}';
    if (key == lastDriverRouteKey) return;
    lastDriverRouteKey = key;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${driver.longitude},${driver.latitude};'
        '${pickup.longitude},${pickup.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords =
            data['routes'][0]['geometry']['coordinates'] as List<dynamic>;
        final points = coords
            .map<LatLng>((c) => LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ))
            .toList();
        final distanceMeters =
            (data['routes'][0]['distance'] as num).toDouble();

        if (!mounted) return;
        setState(() {
          driverToPickupRoute = points;
          driverToPickupKm = distanceMeters / 1000;
        });
        _fitAllPoints(pickup: pickup);
      }
    } catch (e) {
      debugPrint("Driver route error: $e");
    }
  }

  Future<String> getAddress(double lat, double lng) async {
    final key = '$lat,$lng';
    if (_addressCache.containsKey(key)) return _addressCache[key]!;

    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'json',
      });

      final response =
          await http.get(url, headers: {'User-Agent': 'flutter_app'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];
        String readable = '';

        if (address != null) {
          final road = address['road'] ??
              address['pedestrian'] ??
              address['suburb'] ??
              '';
          final house = address['house_number'] ?? '';
          readable = house.isNotEmpty ? '$road $house' : road;
        }

        if (readable.isEmpty) {
          readable = data['display_name'] ?? 'Onbekend adres';
          if (readable.length > 60) {
            readable = '${readable.substring(0, 60)}...';
          }
        }

        _addressCache[key] = readable;
        return readable;
      }
    } catch (e) {
      debugPrint('Reverse geocode error: $e');
    }

    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  Future<void> fetchRoute(LatLng pickup, LatLng destination) async {
    final key = '${pickup.latitude},${pickup.longitude}-'
        '${destination.latitude},${destination.longitude}';
    if (key == lastRouteKey) return;
    lastRouteKey = key;

    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${pickup.longitude},${pickup.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords =
            data['routes'][0]['geometry']['coordinates'] as List<dynamic>;
        final points = coords
            .map<LatLng>((c) => LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ))
            .toList();

        if (!mounted) return;
        setState(() => routePoints = points);

        _fitAllPoints(pickup: pickup, destination: destination);
      }
    } catch (e) {
      debugPrint("Route error: $e");
    }
  }

  void _fitAllPoints({LatLng? pickup, LatLng? destination}) {
    final points = <LatLng>[
      if (driverLocation != null) driverLocation!,
      if (pickup != null) pickup,
      if (destination != null) destination,
    ];
    if (points.length < 2) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bounds = LatLngBounds.fromPoints(points);
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    });
  }

  Future<void> acceptRide(BuildContext context, String rideId) async {
    if (isAccepting) return;
    setState(() => isAccepting = true);

    final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);
    bool success = false;

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snapshot = await tx.get(rideRef);
        if (!snapshot.exists) throw Exception("Ride bestaat niet");

        final data = snapshot.data() as Map<String, dynamic>;
        if (data['status'] != 'searching') throw Exception("Ride al gepakt");

        tx.update(rideRef, {
          'status': 'accepted',
          'driverId': widget.driverId,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });
      success = true;
    } catch (e) {
      debugPrint("Accept error: $e");
    }

    if (!mounted) return;

    if (!success) {
      setState(() => isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rit is al door iemand anders gepakt")),
      );
      Navigator.pop(context);
      return;
    }

    // isAccepting blijft bewust 'true' tot aan de navigatie, om een
    // korte terugflits naar de normale staat te voorkomen.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DriverRideControlScreen(
          rideId: rideId,
          driverId: widget.driverId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rit details")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.data!.exists) {
            return const Center(child: Text("Rit bestaat niet meer"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';

          // Een andere chauffeur was sneller, of de passagier annuleerde
          // terwijl deze chauffeur naar het scherm keek.
          if (status != 'searching') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.info_outline, size: 60, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      "Deze rit is niet meer beschikbaar",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Terug"),
                    ),
                  ],
                ),
              ),
            );
          }

          final pickup = data['pickup'] as GeoPoint?;
          final destination = data['destination'] as GeoPoint?;
          final distanceKm = (data['distanceKm'] as num?)?.toDouble();
          final price = (data['price'] as num?)?.toDouble();

          final pickupLatLng =
              pickup != null ? LatLng(pickup.latitude, pickup.longitude) : null;
          final destLatLng = destination != null
              ? LatLng(destination.latitude, destination.longitude)
              : null;

          if (pickupLatLng != null && destLatLng != null) {
            fetchRoute(pickupLatLng, destLatLng);
          }
          if (driverLocation != null && pickupLatLng != null) {
            fetchDriverToPickupRoute(driverLocation!, pickupLatLng);
          }

          return Column(
            children: [
              SizedBox(
                height: 260,
                child: pickupLatLng == null
                    ? const Center(child: Text("Locatie onbekend"))
                    : FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: pickupLatLng,
                          initialZoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.zizzr.app',
                          ),
                          if (driverToPickupRoute.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: driverToPickupRoute,
                                  strokeWidth: 4,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                          if (routePoints.isNotEmpty)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: routePoints,
                                  strokeWidth: 4,
                                  color: Colors.green,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (driverLocation != null)
                                Marker(
                                  point: driverLocation!,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(Icons.local_taxi,
                                      color: Colors.black, size: 32),
                                ),
                              Marker(
                                point: pickupLatLng,
                                width: 60,
                                height: 60,
                                child: const Icon(Icons.person_pin_circle,
                                    color: Colors.blue, size: 40),
                              ),
                              if (destLatLng != null)
                                Marker(
                                  point: destLatLng,
                                  width: 60,
                                  height: 60,
                                  child: const Icon(Icons.location_on,
                                      color: Colors.red, size: 40),
                                ),
                            ],
                          ),
                        ],
                      ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (driverToPickupKm != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              const Icon(Icons.local_taxi,
                                  size: 16, color: Colors.black87),
                              const SizedBox(width: 6),
                              Text(
                                "${driverToPickupKm!.toStringAsFixed(2)} km tot ophaalpunt",
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (driverLocation == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6),
                          child: Text(
                            "Jouw locatie wordt bepaald...",
                            style: TextStyle(
                                fontSize: 13, color: Colors.black45),
                          ),
                        ),
                      if (distanceKm != null)
                        Text(
                          "Rit: ${distanceKm.toStringAsFixed(2)} km",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      const SizedBox(height: 16),

                      const Text("Ophalen bij",
                          style: TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.person_pin_circle,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: pickupLatLng == null
                                ? const Text("Onbekend")
                                : FutureBuilder<String>(
                                    future: getAddress(
                                        pickupLatLng.latitude, pickupLatLng.longitude),
                                    builder: (context, snap) => Text(
                                      snap.data ?? 'Adres laden...',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      const Text("Bestemming",
                          style: TextStyle(color: Colors.black54, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.location_on,
                              color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: destLatLng == null
                                ? const Text("Onbekend")
                                : FutureBuilder<String>(
                                    future: getAddress(
                                        destLatLng.latitude, destLatLng.longitude),
                                    builder: (context, snap) => Text(
                                      snap.data ?? 'Adres laden...',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Geschatte prijs (excl. wachttijd)",
                              style: TextStyle(color: Colors.black54),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              price != null
                                  ? "srd ${price.toStringAsFixed(2)}"
                                  : "-",
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isAccepting
                        ? null
                        : () => acceptRide(context, widget.rideId),
                    child: isAccepting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Pak Rit", style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}