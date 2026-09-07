import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'driver_request_screen.dart'; // ← importeer je dashboard scherm

class DriverRideControlScreen extends StatefulWidget {
  final String rideId;
  final String driverId; // ← nieuw: nodig om terug te navigeren

  const DriverRideControlScreen({
    super.key,
    required this.rideId,
    required this.driverId,
  });

  @override
  State<DriverRideControlScreen> createState() =>
      _DriverRideControlScreenState();
}

class _DriverRideControlScreenState extends State<DriverRideControlScreen> {
  StreamSubscription<Position>? liveGps;
  bool isUpdating = false;
  bool isCancelling = false;

  @override
  void initState() {
    super.initState();
    startGps();
  }

  Future<void> startGps() async {
    if (liveGps != null) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showError("Locatieservice is uitgeschakeld. Schakel het in om door te gaan.");
      return;
    }

    LocationPermission permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _showError("Locatiepermissie geweigerd. De rit kan niet worden bijgehouden.");
      return;
    }

    DateTime? lastUpdate;

    liveGps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      final now = DateTime.now();
      if (lastUpdate == null ||
          now.difference(lastUpdate!) > const Duration(seconds: 5)) {
        lastUpdate = now;
        try {
          await FirebaseFirestore.instance
              .collection('rides')
              .doc(widget.rideId)
              .update({
            'driverLocation': {'lat': pos.latitude, 'lng': pos.longitude},
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint("GPS error: $e");
        }
      }
    });
  }

  // ===============================
  // NAVIGEER TERUG NAAR DASHBOARD
  // ===============================
  void _goToDashboard() {
    // pushAndRemoveUntil vervangt de hele stack met het dashboard
    // zodat de chauffeur niet terug kan naar het rit-scherm
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => DriverRequestScreen(driverId: widget.driverId),
      ),
      (route) => false,
    );
  }

  Future<void> setStatus(String status) async {
    if (isUpdating) return;
    setState(() => isUpdating = true);

    try {
      final rideRef =
          FirebaseFirestore.instance.collection('rides').doc(widget.rideId);

      await rideRef.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (status == 'completed') {
        final rideSnap = await rideRef.get();
        final price = (rideSnap.data() as Map<String, dynamic>?)?['price'];
        if (price != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.driverId)
              .update({'earnings': FieldValue.increment(price)});
        }
      }

      if (status == 'completed' || status == 'cancelled') {
        await liveGps?.cancel();
        liveGps = null;
        if (!mounted) return;
        _goToDashboard();
        return;
      }
    } catch (e) {
      debugPrint("Status error: $e");
      _showError("Er ging iets mis. Probeer opnieuw.");
    }

    if (mounted) setState(() => isUpdating = false);
  }

  Future<void> cancelRide() async {
    if (isCancelling) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rit annuleren?"),
        content: const Text("Weet je zeker dat je de rit wilt annuleren?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Nee"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Ja, annuleer", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => isCancelling = true);

    try {
      await FirebaseFirestore.instance
          .collection('rides')
          .doc(widget.rideId)
          .update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await liveGps?.cancel();
      liveGps = null;

      if (!mounted) return;
      _goToDashboard();
    } catch (e) {
      debugPrint("Cancel error: $e");
      _showError("Annuleren mislukt. Probeer opnieuw.");
      if (mounted) setState(() => isCancelling = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    liveGps?.cancel();
    super.dispose();
  }

  Widget _actionButton(String text, String status, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: color),
        onPressed: isUpdating ? null : () => setStatus(status),
        child: isUpdating
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text, style: const TextStyle(fontSize: 18, color: Colors.white)),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted': return 'Geaccepteerd';
      case 'arrived': return 'Gearriveerd';
      case 'started': return 'Onderweg';
      case 'completed': return 'Voltooid';
      case 'cancelled': return 'Geannuleerd';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Rit Beheren"),
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .doc(widget.rideId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Rit niet gevonden"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final status = data['status'] as String? ?? 'unknown';
          final bool isFinished = status == 'completed' || status == 'cancelled';

          Widget? actionBtn;
          if (status == 'accepted') {
            actionBtn = _actionButton("Ik ben gearriveerd", "arrived", Colors.blue);
          } else if (status == 'arrived') {
            actionBtn = _actionButton("Start Rit", "started", Colors.green);
          } else if (status == 'started') {
            actionBtn = _actionButton("Voltooi Rit", "completed", Colors.green.shade700);
          }

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_taxi, size: 90),
                const SizedBox(height: 20),

                Text(
                  "Status: ${_statusLabel(status)}",
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),

                if (status == 'unknown')
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      "Onbekende ritstatus. Neem contact op met support.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),

                const SizedBox(height: 40),

                if (actionBtn != null) actionBtn,

                // Terug naar dashboard — alleen als rit klaar is
                if (isFinished) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                      onPressed: _goToDashboard,
                      icon: const Icon(Icons.dashboard, color: Colors.white),
                      label: const Text(
                        "Terug naar Dashboard",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],

                // Annuleerknop — alleen als rit nog bezig is
                if (!isFinished) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: isCancelling ? null : cancelRide,
                      child: isCancelling
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Annuleer Rit",
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}