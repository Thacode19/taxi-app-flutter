import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriverHistoryScreen extends StatelessWidget {
  const DriverHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final driver = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Verdiensten & ritten"),
      ),
      body: Column(
        children: [
          // Totale verdiensten, live vanuit het profiel
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(driver.uid)
                .snapshots(),
            builder: (context, snap) {
              final earnings = snap.hasData && snap.data!.exists
                  ? ((snap.data!.data() as Map<String, dynamic>)['earnings'] ??
                      0)
                  : 0;
              final userData = snap.hasData && snap.data!.exists
                  ? snap.data!.data() as Map<String, dynamic>
                  : <String, dynamic>{};
              final ratingCount = userData['ratingCount'] ?? 0;
              final ratingSum = userData['ratingSum'] ?? 0;
              final avgRating =
                  ratingCount > 0 ? (ratingSum / ratingCount) : null;

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Totale verdiensten",
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "srd ${(earnings as num).toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    if (avgRating != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star,
                              size: 18, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            "${avgRating.toStringAsFixed(1)} ($ratingCount beoordelingen)",
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('rides')
                  .where('driverId', isEqualTo: driver.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rides = snapshot.data!.docs;

                if (rides.isEmpty) {
                  return const Center(child: Text("Geen ritten gevonden"));
                }

                return ListView.builder(
                  itemCount: rides.length,
                  itemBuilder: (context, index) {
                    final data =
                        rides[index].data() as Map<String, dynamic>;
                    final price = data['price'] ?? 0;
                    final distanceKm = data['distanceKm'];
                    final status = data['status'] ?? '';

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
                        subtitle: Text("Status: $status"),
                        trailing: Text("srd $price"),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
