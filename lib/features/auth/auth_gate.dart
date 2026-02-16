// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// //import '../auth/login_screen.dart';
// import '../passenger/home_passenger.dart';

// class AuthGate extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         // if (!snapshot.hasData) {
//         //   return LoginScreen();
//         // }
//         if (snapshot.connectionState == ConnectionState.waiting) {
//   return const Scaffold(
//     body: Center(child: CircularProgressIndicator()),
//   );
// }

//         return PassengerHome();
//       },
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import '../passenger/home_passenger.dart';
import '../driver/home_driver.dart';
import '../admin/dashboard_stub.dart';


class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      // builder: (context, snapshot) {

      //   // 1️⃣ Firebase is nog bezig
      //   if (snapshot.connectionState == ConnectionState.waiting) {
      //     return const Scaffold(
      //       body: Center(child: CircularProgressIndicator()),
      //     );
      //   }

      //   // 2️⃣ NIET ingelogd → login scherm
      //   if (!snapshot.hasData) {
      //     return const LoginScreen();
      //   }

      //   // 3️⃣ WEL ingelogd → user opslaan + home
      //   final user = snapshot.data!;

      //   FirebaseFirestore.instance
      //       .collection('users')
      //       .doc(user.uid)
      //       .set({
      //     'phone': user.phoneNumber ?? 'anonymous',
      //     'role': 'passenger',
      //     'isActive': true,
      //     'createdAt': FieldValue.serverTimestamp(),
      //   }, SetOptions(merge: true));

      //   return const PassengerHome();
      // },
      builder: (context, snapshot) {

  // 1️⃣ Firebase auth laadt
  if (snapshot.connectionState == ConnectionState.waiting) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  // 2️⃣ Niet ingelogd
  if (!snapshot.hasData) {
    return const LoginScreen();
  }

  final user = snapshot.data!;

  // 3️⃣ Firestore user ophalen (role)
  return FutureBuilder(
    future: FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get(),
    builder: (context, userSnap) {

      if (userSnap.connectionState == ConnectionState.waiting) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (!userSnap.hasData || !userSnap.data!.exists) {
        return const Scaffold(
          body: Center(child: Text('User not found')),
        );
      }

//       if (!userSnap.hasData || !userSnap.data!.exists) {
//   Future.microtask(() async {
//     await FirebaseFirestore.instance
//         .collection('users')
//         .doc(user.uid)
//         .set({
//           'role': 'passenger', // tijdelijk default
//           'createdAt': FieldValue.serverTimestamp(),
//         });
//   });

//   return const Scaffold(
//     body: Center(child: CircularProgressIndicator()),
//   );
// }

      final data = userSnap.data!.data()!;
      final role = data['role'];

      // 4️⃣ Routing op role
      if (role == 'driver') {
        return const DriverHome();
      }

      if (role == 'admin') {
        return const AdminDashboard();
      }

      return const PassengerHome();
    },
  );
},

    );
  }
}
