import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PassengerHistoryScreen extends StatelessWidget {
  const PassengerHistoryScreen({super.key});

  String _statusLabel(String status) {
    switch (status) {
      case 'searching':
        return 'Op zoek naar chauffeur';
      case 'accepted':
        return 'Geaccepteerd';
      case 'arrived':
        return 'Chauffeur gearriveerd';
      case 'started':
        return 'Onderweg';
      case 'completed':
        return 'Voltooid';
      case 'cancelled':
        return 'Geannuleerd';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final passenger = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text("Mijn ritten")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .where('passengerId', isEqualTo: passenger.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final rides = snapshot.data!.docs;

          if (rides.isEmpty) {
            return const Center(child: Text("Nog geen ritten gemaakt"));
          }

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final data = rides[index].data() as Map<String, dynamic>;
              final price = data['finalPrice'] ?? data['price'] ?? 0;
              final distanceKm = data['distanceKm'];
              final status = data['status'] ?? '';
              final rating = data['rating'];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: ListTile(
                  title: Text(
                    distanceKm != null
                        ? "Rit van ${(distanceKm as num).toStringAsFixed(1)} km"
                        : "Rit",
                  ),
                  subtitle: Text(_statusLabel(status)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("srd $price"),
                      if (rating != null)
                        Row(
                          children: [
                            const Icon(Icons.star,
                                size: 14, color: Colors.amber),
                            Text(
                              "$rating",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
