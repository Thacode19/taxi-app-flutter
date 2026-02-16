import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import 'driver_history.dart';


class DriverHome extends StatelessWidget {
  const DriverHome({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final driver = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: 
      //AppBar(title: const Text("Driver Home")),
      AppBar(
  title: const Text("Driver Home"),
  actions: [
    IconButton(
      icon: const Icon(Icons.history),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const DriverHistoryScreen(),
          ),
        );
      },
    ),
  ],
),
      body: Column(
  children: [

    // 💰 Earnings header
    StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(driver.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final userData =
            snapshot.data!.data() as Map<String, dynamic>;
        final earnings = userData['earnings'] ?? 0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            "Totale earnings: srd$earnings",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    ),

    // 🔽 Hier komt je bestaande StreamBuilder
    Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: firestore.getDriverActiveRide(driver.uid),
        builder: (context, activeSnapshot) {
          if (!activeSnapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator());
          }

          final activeRides = activeSnapshot.data!.docs;

          if (activeRides.isNotEmpty) {
            final ride = activeRides.first;
            return _buildActiveRideUI(
                context, ride, firestore);
          }

          return _buildAvailableRidesUI(
              firestore, driver.uid);
        },
      ),
    ),
  ],
),

// StreamBuilder<QuerySnapshot>(
//         stream: firestore.getDriverActiveRide(driver.uid),
//   builder: (context, activeSnapshot) {
//     if (!activeSnapshot.hasData) {
//       return const Center(child: CircularProgressIndicator());
//     }

//     final activeRides = activeSnapshot.data!.docs;

//     // 🔵 DRIVER HEEFT ACTIEVE RIT
//     if (activeRides.isNotEmpty) {
//       final ride = activeRides.first;

//       return _buildActiveRideUI(context, ride, firestore);
//     }

//     // 🟢 GEEN ACTIEVE RIT → toon beschikbare ritten
//     return _buildAvailableRidesUI(firestore, driver.uid);
//   },
//       ),

    );

  }

Widget _buildAvailableRidesUI(
    FirestoreService firestore, String driverId) {
  return StreamBuilder<QuerySnapshot>(
    stream: firestore.getAvailableRides(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final rides = snapshot.data!.docs;

      if (rides.isEmpty) {
        return const Center(child: Text("Geen beschikbare ritten"));
      }

      return ListView.builder(
        itemCount: rides.length,
        itemBuilder: (context, index) {
          final ride = rides[index];

          return ListTile(
            title: Text(ride['pickupText']),
            subtitle: Text("Naar ${ride['destinationText']}"),
            trailing: ElevatedButton(
              child: const Text("Accepteer"),
              onPressed: () async {
                await firestore.acceptRide(
                  rideId: ride.id,
                  driverId: driverId,
                );
              },
            ),
          );
        },
      );
    },
  );
}


Widget _buildActiveRideUI(
    BuildContext context,
    QueryDocumentSnapshot ride,
    FirestoreService firestore) {

  final status = ride['status'];

  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Pickup: ${ride['pickupText']}"),
        Text("Bestemming: ${ride['destinationText']}"),
        const SizedBox(height: 20),

        if (status == 'accepted')
          ElevatedButton(
            child: const Text("Start rit"),
            onPressed: () async {
              await firestore.updateRideStatus(
                rideId: ride.id,
                status: 'ongoing',
              );
            },
          ),

        if (status == 'ongoing')
          ElevatedButton(
            child: const Text("Beëindig rit"),
            onPressed: () async {
              await firestore.updateRideStatus(
                rideId: ride.id,
                status: 'completed',
              );
            },
          ),
      ],
    ),
  );
}


}
