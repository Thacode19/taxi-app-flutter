import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../../utils/fare_calculator.dart';
import 'driver_request_screen.dart';

class DriverRideControlScreen extends StatefulWidget {
  final String rideId;
  final String driverId;

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
  Timer? _tickTimer;
  bool isUpdating = false;
  bool isCancelling = false;
  bool isTogglingWait = false;

  // Bijgehouden vanuit de Firestore-stream, gebruikt door de GPS-listener
  // om te beslissen of er afstand/kosten opgeteld moeten worden.
  String _rideStatus = 'accepted';
  bool _isWaiting = false;

  Position? _lastMeterPosition;
  double _liveDistanceKm = 0;

  @override
  void initState() {
    super.initState();
    startGps();
    // Enkel voor het live bijwerken van de stopwatch-weergave (1x/sec),
    // schrijft niets naar Firestore.
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
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
      // Kilometerteller: alleen optellen als de rit 'started' is EN er
      // niet op dit moment een wachtpauze loopt (bijv. tussenstop).
      if (_rideStatus == 'started' && !_isWaiting) {
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
        // Tijdens wachten of vóór het starten: geen basispunt vasthouden,
        // zodat na hervatten geen "sprong" wordt meegeteld.
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

  void _goToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => DriverRequestScreen(driverId: widget.driverId),
      ),
      (route) => false,
    );
  }

  /// Sluit de huidige wachtperiode af (of dat nu de initiele aankomst-wacht
  /// is, of een tussenstop tijdens de rit) en telt de verstreken tijd op
  /// bij de totale wachttijd van de rit.
  Future<Map<String, dynamic>> _endCurrentWaitPeriod(
    Map<String, dynamic> rideData,
  ) async {
    final currentWaitStartedAt =
        rideData['currentWaitStartedAt'] as Timestamp?;
    final existingTotal =
        (rideData['totalWaitSeconds'] as num?)?.toDouble() ?? 0;

    double newTotal = existingTotal;
    if (currentWaitStartedAt != null) {
      final elapsed =
          DateTime.now().difference(currentWaitStartedAt.toDate());
      newTotal += elapsed.inSeconds;
    }

    final waitCost =
        FareCalculator.calculateWaitCost(Duration(seconds: newTotal.round()));

    return {
      'totalWaitSeconds': newTotal,
      'waitCost': waitCost,
      'isWaiting': false,
    };
  }

  Future<void> setStatus(String status) async {
    if (isUpdating) return;
    setState(() => isUpdating = true);

    try {
      final rideRef =
          FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
      final rideSnap = await rideRef.get();
      final rideData = rideSnap.data() as Map<String, dynamic>? ?? {};

      final update = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == 'arrived') {
        // Start meteen de wachtklok bij aankomst.
        update['arrivedAt'] = FieldValue.serverTimestamp();
        update['isWaiting'] = true;
        update['currentWaitStartedAt'] = FieldValue.serverTimestamp();
        update['totalWaitSeconds'] = 0;
      }

      if (status == 'started') {
        // Sluit de aankomst-wachtperiode af en start de kilometerteller.
        update.addAll(await _endCurrentWaitPeriod(rideData));
        update['startedAt'] = FieldValue.serverTimestamp();

        _liveDistanceKm = 0;
        _lastMeterPosition = null;
        update['liveDistanceKm'] = 0;
        update['liveFare'] = FareCalculator.liveFare(0);
      }

      _rideStatus = status;
      _isWaiting = update['isWaiting'] == true;

      await rideRef.update(update);

      if (status == 'completed') {
        final finalSnap = await rideRef.get();
        final finalData = finalSnap.data() as Map<String, dynamic>? ?? {};

        final liveFareValue = (finalData['liveFare'] as num?)?.toDouble();
        final basePrice = (finalData['price'] as num?)?.toDouble() ?? 0;
        final storedWaitCost =
            (finalData['waitCost'] as num?)?.toDouble() ?? 0;

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

  /// Chauffeur zet de rit "on hold" tijdens een tussenstop van de passagier
  /// (bijv. snel de winkel in). Kilometerteller pauzeert, wachtklok start.
  Future<void> toggleMidRideWait() async {
    if (isTogglingWait) return;
    setState(() => isTogglingWait = true);

    try {
      final rideRef =
          FirebaseFirestore.instance.collection('rides').doc(widget.rideId);
      final rideSnap = await rideRef.get();
      final rideData = rideSnap.data() as Map<String, dynamic>? ?? {};
      final currentlyWaiting = rideData['isWaiting'] == true;

      if (currentlyWaiting) {
        // Hervatten: sluit deze wachtperiode af.
        final update = await _endCurrentWaitPeriod(rideData);
        _isWaiting = false;
        _lastMeterPosition = null; // voorkom sprong bij hervatten
        await rideRef.update(update);
      } else {
        // Pauzeren: start een nieuwe wachtperiode.
        _isWaiting = true;
        await rideRef.update({
          'isWaiting': true,
          'currentWaitStartedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Wait toggle error: $e");
      _showError("Er ging iets mis. Probeer opnieuw.");
    }

    if (mounted) setState(() => isTogglingWait = false);
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
    _tickTimer?.cancel();
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

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
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

          _rideStatus = status;
          _isWaiting = data['isWaiting'] == true;

          final liveDistanceKm = (data['liveDistanceKm'] as num?)?.toDouble();
          final liveFare = (data['liveFare'] as num?)?.toDouble();
          final finalPrice = (data['finalPrice'] as num?)?.toDouble();
          final storedWaitCost = (data['waitCost'] as num?)?.toDouble() ?? 0;
          final totalWaitSeconds =
              (data['totalWaitSeconds'] as num?)?.toDouble() ?? 0;
          final currentWaitStartedAt =
              data['currentWaitStartedAt'] as Timestamp?;

          // Live stopwatch: totale wachttijd tot nu toe (al afgesloten
          // periodes + eventuele lopende periode).
          double liveWaitSeconds = totalWaitSeconds;
          if (_isWaiting && currentWaitStartedAt != null) {
            liveWaitSeconds += DateTime.now()
                .difference(currentWaitStartedAt.toDate())
                .inSeconds;
          }
          final liveWaitCost = FareCalculator.calculateWaitCost(
            Duration(seconds: liveWaitSeconds.round()),
          );

          Widget? actionBtn;
          if (status == 'accepted') {
            actionBtn = _actionButton("Ik ben gearriveerd", "arrived", Colors.blue);
          } else if (status == 'arrived') {
            actionBtn = _actionButton("Start Rit", "started", Colors.green);
          } else if (status == 'started' && !_isWaiting) {
            actionBtn = _actionButton("Voltooi Rit", "completed", Colors.green.shade700);
          }

          return SingleChildScrollView(
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

                // Live stopwatch, zichtbaar tijdens elke wachtperiode
                // (aankomst-wacht óf een tussenstop tijdens de rit).
                if (_isWaiting && !isFinished) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          "Wachttijd",
                          style: TextStyle(color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDuration(
                            Duration(seconds: liveWaitSeconds.round()),
                          ),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          liveWaitCost > 0
                              ? "Wachtgeld: srd ${liveWaitCost.toStringAsFixed(2)}"
                              : "Nog binnen gratis ${FareCalculator.freeWaitMinutes} min",
                          style: TextStyle(
                            color: liveWaitCost > 0
                                ? Colors.orange.shade800
                                : Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Live kilometerteller, zichtbaar zodra de rit gestart is
                if (status == 'started' && liveDistanceKm != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isWaiting ? Colors.grey.shade200 : Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isWaiting ? Colors.grey : Colors.green,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _isWaiting ? "Live meter (gepauzeerd)" : "Live meter",
                          style: const TextStyle(color: Colors.black54),
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
                            style: TextStyle(
                              fontSize: 20,
                              color: _isWaiting ? Colors.black45 : Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],

                if (isFinished && finalPrice != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    "Totaal: srd ${finalPrice.toStringAsFixed(2)}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (storedWaitCost > 0)
                    Text(
                      "(waarvan srd ${storedWaitCost.toStringAsFixed(2)} wachtgeld)",
                      style: const TextStyle(color: Colors.black54),
                    ),
                ],

                const SizedBox(height: 30),

                if (actionBtn != null) actionBtn,

                // Wachten/hervatten-knop — alleen tijdens een lopende rit
                if (status == 'started') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade800),
                      ),
                      onPressed: isTogglingWait ? null : toggleMidRideWait,
                      icon: Icon(_isWaiting ? Icons.play_arrow : Icons.pause),
                      label: Text(
                        _isWaiting
                            ? "Doorgaan (tussenstop klaar)"
                            : "Wachten (tussenstop passagier)",
                      ),
                    ),
                  ),
                ],

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
      ),
    );
  }
}