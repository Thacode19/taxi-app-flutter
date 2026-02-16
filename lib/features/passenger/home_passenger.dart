import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';

class PassengerHome extends StatelessWidget {
  const PassengerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final firestore = FirestoreService();
    final user = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(title: const Text('Passenger Home')),
      body: Center(
        child: ElevatedButton(
          child: const Text('Bestel taxi'),
          onPressed: () async {
            await firestore.createRide(
              passengerId: user.uid,
              pickup: 'Paramaribo centrum',
              destination: 'Zorg en Hoop',
            );

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Rit aangemaakt 🚕')),
            );
          },
        ),
      ),
    );
  }
}
