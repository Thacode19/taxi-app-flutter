import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/fare_calculator.dart';
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

  // Voor de live kilometerteller: alleen actief zolang de rit 'started' is.
  String _rideStatus = 'accepted';
  Position? _lastMeterPosition;
  double _liveDistanceKm = 0;

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
      // Kilometerteller: alleen optellen zolang de rit daadwerkelijk
      // 'started' is. Bij de eerste positie na het starten leggen we
      // enkel het startpunt vast, zonder afstand toe te voegen.
      if (_rideStatus == 'started') {
        if (_lastMeterPosition != null) {
          final meters = Geolocator.distanceBetween(
            _lastMeterPosition!.latitude,
            _lastMeterPosition!.longitude,
            pos.latitude,
            pos.longitude,
          );
          _liveDistanceKm += meters / 1000;
        }
        _lastMeterPosition = pos;
      } else {
        // Nog niet gestart (of al klaar) — geen basispunt vasthouden,
        // zodat de eerste 'started'-positie altijd het echte startpunt is.
        _lastMeterPosition = null;
      }

      final now = DateTime.now();
      if (lastUpdate == null ||
          now.difference(lastUpdate!) > const Duration(seconds: 5)) {
        lastUpdate = now;
        try {
          final update = <String, dynamic>{
            'driverLocation': {'lat': pos.latitude, 'lng': pos.longitude},
            'updatedAt': FieldValue.serverTimestamp(),
          };

          if (_rideStatus == 'started') {
            update['liveDistanceKm'] = _liveDistanceKm;
            update['liveFare'] = FareCalculator.liveFare(_liveDistanceKm);
          }

          await FirebaseFirestore.instance
              .collection('rides')
              .doc(widget.rideId)
              .update(update);
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

      final update = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'arrived') {
        update['arrivedAt'] = FieldValue.serverTimestamp();
      }

      double waitCost = 0;

      if (status == 'started') {
        // Bereken wachtgeld op basis van de tijd tussen aankomst en start.
        final rideSnap = await rideRef.get();
        final rideData = rideSnap.data() as Map<String, dynamic>?;
        final arrivedAt = rideData?['arrivedAt'] as Timestamp?;

        if (arrivedAt != null) {
          final waitDuration = DateTime.now().difference(arrivedAt.toDate());
          waitCost = FareCalculator.calculateWaitCost(waitDuration);
          update['waitMinutes'] = waitDuration.inSeconds / 60.0;
          update['waitCost'] = waitCost;
        }

        update['startedAt'] = FieldValue.serverTimestamp();

        // Reset de kilometerteller voor deze rit
        _liveDistanceKm = 0;
        _lastMeterPosition = null;
        update['liveDistanceKm'] = 0;
        update['liveFare'] = FareCalculator.liveFare(0);
      }

      // Zet de lokale status VOOR de update, zodat de GPS-listener
      // direct weet dat hij (niet) moet meten.
      _rideStatus = status;

      await rideRef.update(update);

      if (status == 'completed') {
        final rideSnap = await rideRef.get();
        final rideData = rideSnap.data() as Map<String, dynamic>?;

        final liveFareValue = (rideData?['liveFare'] as num?)?.toDouble();
        final basePrice = (rideData?['price'] as num?)?.toDouble() ?? 0;
        final storedWaitCost = (rideData?['waitCost'] as num?)?.toDouble() ?? 0;

        // Eindprijs: de live-gemeten afstand als die er is (dat is de
        // daadwerkelijk gereden route), anders de vooraf geschatte prijs.
        final tripFare =
            (liveFareValue != null && liveFareValue > 0) ? liveFareValue : basePrice;
        final finalPrice = tripFare + storedWaitCost;

        await rideRef.update({'finalPrice': finalPrice});

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.driverId)
            .update({'earnings': FieldValue.increment(finalPrice)});
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

          // Houd de laatst bekende status bij voor de GPS-listener,
          // zonder een extra setState te veroorzaken.
          _rideStatus = status;

          final liveDistanceKm = (data['liveDistanceKm'] as num?)?.toDouble();
          final liveFare = (data['liveFare'] as num?)?.toDouble();
          final waitCost = (data['waitCost'] as num?)?.toDouble();
          final finalPrice = (data['finalPrice'] as num?)?.toDouble();

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

                // Live kilometerteller, zichtbaar zodra de rit gestart is
                if (status == 'started' && liveDistanceKm != null) ...[
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Live meter",
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "${liveDistanceKm.toStringAsFixed(2)} km",
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (liveFare != null)
                          Text(
                            "srd ${liveFare.toStringAsFixed(2)}",
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                if (waitCost != null && waitCost > 0 && !isFinished) ...[
                  const SizedBox(height: 12),
                  Text(
                    "Wachtgeld doorberekend: srd ${waitCost.toStringAsFixed(2)}",
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],

                if (isFinished && finalPrice != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Totaal: srd ${finalPrice.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (waitCost != null && waitCost > 0)
                    Text(
                      "(waarvan srd ${waitCost.toStringAsFixed(2)} wachtgeld)",
                      style: const TextStyle(color: Colors.black54),
                    ),
                ],

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
