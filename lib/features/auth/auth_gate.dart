import 'package:taxi_passenger/map_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../driver/driver_request_screen.dart';
import '../driver/pending_approval_screen.dart';
import '../admin/dashboard_stub.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (!authSnap.hasData) {
          return const LoginScreen();
        }

        final uid = authSnap.data!.uid;

        // Listen live so a driver's screen updates automatically the
        // moment an admin approves/rejects them, without needing to
        // restart the app.
        return StreamBuilder<DocumentSnapshot>(
          stream:
              FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData || !userSnap.data!.exists) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = userSnap.data!.data() as Map<String, dynamic>;
            final role = data['role'];

            if (role == 'admin') {
              return const AdminDashboard();
            }

            if (role == 'driver') {
              final status = data['verificationStatus'] ?? 'pending';
              if (status != 'approved') {
                return PendingApprovalScreen(status: status);
              }
              return DriverRequestScreen(driverId: uid);
            }

            return const MapScreen();
          },
        );
      },
    );
  }
}
