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
        title: const Text("Rit Geschiedenis"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('rides')
            .where('driverId', isEqualTo: driver.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final rides = snapshot.data!.docs;

          if (rides.isEmpty) {
            return const Center(
                child: Text("Geen ritten gevonden"));
          }

          return ListView.builder(
            itemCount: rides.length,
            itemBuilder: (context, index) {
              final ride = rides[index];
              final price = ride.data().toString().contains('price')
    ? ride['price']
    : 0;

              return Card(
                margin: const EdgeInsets.all(10),
                child: ListTile(
                  title: Text(
                      "${ride['pickup']} → ${ride['destination']}"),
                  subtitle: Text(
                      "Status: ${ride['status']}"),
                  trailing: 
                  //Text("€${ride['price']}"),
                  Text("srd$price")
                  ),
              );
            },
          );
        },
      ),
    );
  }
}
