import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../services/notification_service.dart';
import '../../utils/fare_calculator.dart';

class RideTrackingScreen extends StatefulWidget {
  final String rideId;

  const RideTrackingScreen({super.key, required this.rideId});

  @override
  State<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends State<RideTrackingScreen> {
  final MapController mapController = MapController();

  bool firstMoveDone = false;
  List<LatLng> routePoints = [];
  String? lastRouteKey;

  int selectedStars = 0;
  final commentController = TextEditingController();
  bool submittingRating = false;

  String? _lastNotifiedStatus;
  bool _isFirstStatusUpdate = true;

  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    // Enkel voor het live bijwerken van de stopwatch-weergave (1x/sec).
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  void _notifyStatusChangeIfNeeded(String status) {
    if (_isFirstStatusUpdate) {
      _isFirstStatusUpdate = false;
      _lastNotifiedStatus = status;
      return;
    }

    if (status != _lastNotifiedStatus) {
      _lastNotifiedStatus = status;
      NotificationService().show(
        title: "Update over je rit",
        body: message(status),
      );
    }
  }

  Future<void> submitRating(String? driverId) async {
    if (selectedStars == 0) return;
    setState(() => submittingRating = true);

    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'rating': selectedStars,
        'comment': commentController.text.trim(),
        'ratedAt': FieldValue.serverTimestamp(),
      });

      if (driverId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(driverId)
            .update({
          'ratingSum': FieldValue.increment(selectedStars),
          'ratingCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint("Rating error: $e");
    }

    if (mounted) setState(() => submittingRating = false);
  }

  @override
  void dispose() {
    commentController.dispose();
    _tickTimer?.cancel();
    super.dispose();
  }

  // ===============================
  // ROUTE OPHALEN
  // ===============================
  Future<void> fetchRoute(LatLng start, LatLng end) async {
    final key =
        "${start.latitude},${start.longitude}-${end.latitude},${end.longitude}";

    // Voorkomt spam requests als route niet veranderd is
    if (key == lastRouteKey) return;
    lastRouteKey = key;

    // FIX: http → https zodat Android het niet blokkeert
    final url =
        "https://router.project-osrm.org/route/v1/driving/"
        "${start.longitude},${start.latitude};"
        "${end.longitude},${end.latitude}"
        "?overview=full&geometries=geojson";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords = data['routes'][0]['geometry']['coordinates'];
        final points = coords
            .map<LatLng>(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
            )
            .toList();

        if (mounted) {
          setState(() => routePoints = points);
        }
      }
    } catch (e) {
      debugPrint("Route error: $e");
    }
  }

  // ===============================
  // STATUS → BERICHT
  // ===============================
  String message(String status) {
    switch (status) {
      case 'accepted':
        return "Chauffeur onderweg naar jou";
      case 'arrived':
        return "Chauffeur is gearriveerd!";
      case 'started':
        return "Rit gestart — onderweg naar bestemming";
      case 'completed':
        return "Rit voltooid";
      case 'cancelled':
        return "Rit geannuleerd";
      default:
        return "Even wachten...";
    }
  }

  // ===============================
  // STATUS → KLEUR
  // ===============================
  Color statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.blue;
      case 'arrived':
        return Colors.orange;
      case 'started':
        return Colors.green;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Taxi Tracking"),
        automaticallyImplyLeading: false,
      ),
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
            return const Center(child: Text("Ride niet gevonden"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? '';
          _notifyStatusChangeIfNeeded(status);

          final pickup = data['pickup'] as GeoPoint?;
          final destination = data['destination'] as GeoPoint?;
          final driverLocation = data['driverLocation'];
          final driverId = data['driverId'] as String?;
          final liveDistanceKm = (data['liveDistanceKm'] as num?)?.toDouble();
          final liveFare = (data['liveFare'] as num?)?.toDouble();
          final finalPrice = (data['finalPrice'] as num?)?.toDouble();
          final waitCost = (data['waitCost'] as num?)?.toDouble();
          final isWaiting = data['isWaiting'] == true;
          final totalWaitSeconds =
              (data['totalWaitSeconds'] as num?)?.toDouble() ?? 0;
          final currentWaitStartedAt =
              data['currentWaitStartedAt'] as Timestamp?;

          double liveWaitSeconds = totalWaitSeconds;
          if (isWaiting && currentWaitStartedAt != null) {
            liveWaitSeconds += DateTime.now()
                .difference(currentWaitStartedAt.toDate())
                .inSeconds;
          }
          final liveWaitCost = FareCalculator.calculateWaitCost(
            Duration(seconds: liveWaitSeconds.round()),
          );

          // ===============================
          // COMPLETED / CANCELLED
          // ===============================
          if (status == 'completed' || status == 'cancelled') {
            final alreadyRated = data['rating'] != null;

            return Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      status == 'completed'
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 90,
                      color:
                          status == 'completed' ? Colors.green : Colors.red,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      message(status),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (status == 'completed' && finalPrice != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        "Totaal: srd ${finalPrice.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (waitCost != null && waitCost > 0)
                        Text(
                          "(waarvan srd ${waitCost.toStringAsFixed(2)} wachtgeld)",
                          style: const TextStyle(color: Colors.black54),
                        ),
                    ],
                    const SizedBox(height: 24),
                    if (status == 'completed' && !alreadyRated) ...[
                      const Text(
                        "Hoe was je rit?",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (i) {
                          final starIndex = i + 1;
                          return IconButton(
                            iconSize: 36,
                            icon: Icon(
                              starIndex <= selectedStars
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.amber,
                            ),
                            onPressed: () =>
                                setState(() => selectedStars = starIndex),
                          );
                        }),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                        ),
                        child: TextField(
                          controller: commentController,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            hintText: "Opmerking (optioneel)",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: selectedStars == 0 || submittingRating
                            ? null
                            : () => submitRating(driverId),
                        child: submittingRating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text("Beoordeling versturen"),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (status == 'completed' && alreadyRated) ...[
                      const Icon(Icons.check, color: Colors.green),
                      const Text("Bedankt voor je beoordeling!"),
                      const SizedBox(height: 20),
                    ],
                    ElevatedButton(
                      onPressed: () => Navigator.popUntil(
                          context, (route) => route.isFirst),
                      child: const Text("Terug Home"),
                    ),
                  ],
                ),
              ),
            );
          }

          // ===============================
          // WACHTEN OP GPS
          // ===============================
          if (driverLocation == null) {
            return const Center(
              child: Text("Wachten op chauffeur GPS..."),
            );
          }

          // FIX: null-safety op driverLocation keys
          final lat = (driverLocation['lat'] as num?)?.toDouble();
          final lng = (driverLocation['lng'] as num?)?.toDouble();

          if (lat == null || lng == null) {
            return const Center(child: Text("Locatie chauffeur onbekend..."));
          }

          final driverPos = LatLng(lat, lng);

          final pickupPos = pickup != null
              ? LatLng(pickup.latitude, pickup.longitude)
              : null;

          final destinationPos = destination != null
              ? LatLng(destination.latitude, destination.longitude)
              : null;

          // Centreer kaart op chauffeur bij eerste update
          if (!firstMoveDone) {
            firstMoveDone = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              mapController.move(driverPos, 15);
            });
          }

          // FIX: route wisselt op basis van status
          // - accepted/arrived → chauffeur naar pickup
          // - started         → chauffeur naar bestemming
          if (status == 'started' && destinationPos != null) {
            fetchRoute(driverPos, destinationPos);
          } else if (pickupPos != null) {
            fetchRoute(driverPos, pickupPos);
          }

          // ===============================
          // KAART
          // ===============================
          return Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options:
                    MapOptions(initialCenter: driverPos, initialZoom: 15),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.taxi_passenger',
                  ),
                  PolylineLayer(
                    polylines: [
                      if (routePoints.isNotEmpty)
                        Polyline(
                          points: routePoints,
                          strokeWidth: 4,
                          // Blauw = naar pickup, groen = naar bestemming
                          color: status == 'started'
                              ? Colors.green
                              : Colors.blue,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      // Chauffeur
                      Marker(
                        point: driverPos,
                        width: 80,
                        height: 80,
                        child: const Icon(Icons.local_taxi, size: 45),
                      ),
                      // Pickup
                      if (pickupPos != null)
                        Marker(
                          point: pickupPos,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.person_pin_circle,
                            size: 45,
                            color: Colors.blue,
                          ),
                        ),
                      // Bestemming
                      if (destinationPos != null)
                        Marker(
                          point: destinationPos,
                          width: 80,
                          height: 80,
                          child: const Icon(
                            Icons.location_on,
                            size: 45,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              // Status banner bovenaan
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor(status),
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: statusColor(status), size: 12),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          message(status),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Wachttijd-stopwatch: zichtbaar bij aankomst-wacht én bij
              // een tussenstop tijdens de rit
              if (isWaiting && status != 'completed' && status != 'cancelled')
                Positioned(
                  top: 76,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.timer_outlined,
                                size: 18, color: Colors.orange),
                            const SizedBox(width: 6),
                            Text(
                              _formatDuration(
                                Duration(seconds: liveWaitSeconds.round()),
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          liveWaitCost > 0
                              ? "Wachtgeld: srd ${liveWaitCost.toStringAsFixed(2)}"
                              : "Gratis wachttijd",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: liveWaitCost > 0
                                ? Colors.orange.shade800
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Live meter tijdens de rit
              if (status == 'started' && liveDistanceKm != null)
                Positioned(
                  top: isWaiting ? 132 : 76,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 6),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "${liveDistanceKm.toStringAsFixed(2)} km",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (liveFare != null)
                          Text(
                            "srd ${liveFare.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

              // Chauffeur-info onderaan
              if (driverId != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(driverId)
                        .snapshots(),
                    builder: (context, driverSnap) {
                      if (!driverSnap.hasData || !driverSnap.data!.exists) {
                        return const SizedBox.shrink();
                      }

                      final driver =
                          driverSnap.data!.data() as Map<String, dynamic>;
                      final ratingCount = driver['ratingCount'] ?? 0;
                      final ratingSum = driver['ratingSum'] ?? 0;
                      final avgRating = ratingCount > 0
                          ? (ratingSum / ratingCount)
                          : null;

                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              child: Icon(Icons.person),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driver['name'] ?? 'Chauffeur',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (avgRating != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.star,
                                            size: 14, color: Colors.amber),
                                        const SizedBox(width: 2),
                                        Text(
                                          "${avgRating.toStringAsFixed(1)} ($ratingCount)",
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ),
                                  Text(
                                    "${driver['vehicle'] ?? ''}"
                                    "${driver['plateNumber'] != null ? ' • ${driver['plateNumber']}' : ''}",
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (driver['phone'] != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Icon(Icons.phone, size: 18),
                                  Text(
                                    driver['phone'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}