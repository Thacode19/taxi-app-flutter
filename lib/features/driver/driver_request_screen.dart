

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../services/notification_service.dart';
import 'driver_ride_control.dart';
import 'driver_history.dart';

class DriverRequestScreen extends StatefulWidget {
  final String driverId;

  const DriverRequestScreen({super.key, required this.driverId});

  @override
  State<DriverRequestScreen> createState() => _DriverRequestScreenState();
}

class _DriverRequestScreenState extends State<DriverRequestScreen> {
  bool isAccepting = false;
  bool isCheckingRide = true;

  final Map<String, String> _addressCache = {};

  StreamSubscription<QuerySnapshot>? _newRideSub;
  bool _isFirstRideSnapshot = true;

  @override
  void initState() {
    super.initState();
    _checkActiveRide();
    _listenForNewRides();
  }

  void _listenForNewRides() {
    _newRideSub = FirebaseFirestore.instance
        .collection('rides')
        .where('status', isEqualTo: 'searching')
        .orderBy('createdAt')
        .snapshots()
        .listen((snap) {
      // De allereerste snapshot bevat altijd alle al-bestaande ritten
      // als 'added' — die willen we niet als nieuw melden.
      if (_isFirstRideSnapshot) {
        _isFirstRideSnapshot = false;
        return;
      }

      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          NotificationService().show(
            title: "Nieuwe rit beschikbaar!",
            body: "Er staat een rit klaar om te accepteren.",
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _newRideSub?.cancel();
    super.dispose();
  }

  Future<String> getAddress(double lat, double lng) async {
    final key = '$lat,$lng';

    if (_addressCache.containsKey(key)) {
      return _addressCache[key]!;
    }

    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '$lat',
        'lon': '$lng',
        'format': 'json',
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': 'flutter_app'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final address = data['address'];
        String readable = '';

        if (address != null) {
          final road = address['road'] ?? address['pedestrian'] ?? address['suburb'] ?? '';
          final house = address['house_number'] ?? '';
          readable = house.isNotEmpty ? '$road $house' : road;
        }

        if (readable.isEmpty) {
          readable = data['display_name'] ?? 'Onbekend adres';
          if (readable.length > 50) {
            readable = '${readable.substring(0, 50)}...';
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

  Future<void> setOnline(bool value) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.driverId)
        .update({
          'isOnline': value,
          'lastActive': FieldValue.serverTimestamp(),
        });
  }

  Future<void> logout(BuildContext context) async {
    await setOnline(false);
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<bool> acceptRide(String rideId) async {
    final rideRef = FirebaseFirestore.instance.collection('rides').doc(rideId);

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

      return true;
    } catch (e) {
      debugPrint("Accept error: $e");
      return false;
    }
  }

  Future<void> handleAccept(BuildContext context, String rideId) async {
    if (isAccepting) return;
    setState(() => isAccepting = true);

    final success = await acceptRide(rideId);

    if (!mounted) return;

    if (!success) {
      setState(() => isAccepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Rit is al door iemand anders gepakt")),
      );
      return;
    }

    // isAccepting blijft bewust 'true' tot aan de navigatie, zodat het
    // scherm niet even terugflitst naar de normale dashboard-staat
    // voordat we naar het rit-scherm gaan.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DriverRideControlScreen(rideId: rideId,driverId: widget.driverId)),
    );
  }

  Future<void> _checkActiveRide() async {
    final rides = await FirebaseFirestore.instance
        .collection('rides')
        .where('driverId', isEqualTo: widget.driverId)
        .where('status', whereIn: ['accepted', 'arrived', 'started'])
        .limit(1)
        .get();

    if (rides.docs.isNotEmpty && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DriverRideControlScreen(rideId: rides.docs.first.id,
           driverId: widget.driverId),
        ),
      );
      return;
    }

    if (mounted) setState(() => isCheckingRide = false);
  }

  @override
  Widget build(BuildContext context) {
    if (isCheckingRide) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.driverId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Dashboard"),
        actions: [
          IconButton(
            tooltip: "Verdiensten & ritten",
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DriverHistoryScreen(),
                ),
              );
            },
          ),
          IconButton(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDoc.snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnap.data!.data() as Map<String, dynamic>;
          final isOnline = userData['isOnline'] ?? false;

          return Column(
            children: [
              SwitchListTile(
                title: Text(
                  isOnline ? "🟢 Online" : "🔴 Offline",
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                value: isOnline,
                onChanged: (v) => setOnline(v),
              ),
              const Divider(),
              Expanded(
                child: !isOnline
                    ? const Center(
                        child: Text(
                          "Ga online om ritten te ontvangen",
                          style: TextStyle(fontSize: 18),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('rides')
                            .where('status', isEqualTo: 'searching')
                            .orderBy('createdAt')
                            .snapshots(),
                        builder: (context, snap) {
                          if (!snap.hasData) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final docs = snap.data!.docs;

                          if (docs.isEmpty) {
                            return const Center(
                              child: Text(
                                "Geen ritten beschikbaar",
                                style: TextStyle(fontSize: 18),
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, i) {
                              final ride = docs[i];
                              final data = ride.data() as Map<String, dynamic>;

                              final km = ((data['distanceKm'] ?? 0) as num)
                                  .toDouble()
                                  .toStringAsFixed(2);

                              final pickup = data['pickup'] as GeoPoint?;
                              final destination = data['destination'] as GeoPoint?;

                              return Card(
                                margin: const EdgeInsets.all(10),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Rit ${i + 1}  •  $km km",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          ElevatedButton(
                                            onPressed: isAccepting
                                                ? null
                                                : () => handleAccept(context, ride.id),
                                            child: isAccepting
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Text("Pak Rit"),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),

                                      if (pickup != null)
                                        FutureBuilder<String>(
                                          future: getAddress(pickup.latitude, pickup.longitude),
                                          builder: (context, snap) {
                                            final address = snap.data ?? 'Adres laden...';
                                            return Row(
                                              children: [
                                                const Icon(Icons.person_pin_circle,
                                                    color: Colors.blue, size: 18),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    address,
                                                    style: const TextStyle(fontSize: 13),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),

                                      const SizedBox(height: 4),

                                      if (destination != null)
                                        FutureBuilder<String>(
                                          future: getAddress(destination.latitude, destination.longitude),
                                          builder: (context, snap) {
                                            final address = snap.data ?? 'Adres laden...';
                                            return Row(
                                              children: [
                                                const Icon(Icons.location_on,
                                                    color: Colors.red, size: 18),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    address,
                                                    style: const TextStyle(fontSize: 13),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
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