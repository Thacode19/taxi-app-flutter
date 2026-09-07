// import 'package:firebase_auth/firebase_auth.dart';
// //import '../models/user.dart';
// //import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';



// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _db = FirebaseFirestore.instance;

//   Stream<User?> get authStateChanges => _auth.authStateChanges();

//   Future<User?> signInWithPhone(String phoneNumber) async {
//     // Hier komt de phone auth logica, voorlopig dummy return:
//     return _auth.currentUser;
//   }

//   Future<void> signOut() async {
//     await _auth.signOut();
//   }

// Future<void> createRide({
//   required String passengerId,
//   required String pickup,
//   required String destination,
// }) async {
//   await _db.collection('rides').add({
//     'passengerId': passengerId,
//     'pickupText': pickup,
//     'destinationText': destination,
//     'status': 'requested',
//     'createdAt': FieldValue.serverTimestamp(),
//   });
// }



// }


import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =========================
  // Current User
  // =========================
  User? get currentUser => _auth.currentUser;

  // =========================
  // Register Passenger
  // =========================
  Future<String?> registerPassenger({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final uid = credential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'name': name.trim(),
        'phone': phone.trim(),
        'email': email.trim(),
        'role': 'passenger',
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

Future<String?> registerDriver({
  required String name,
  required String email,
  required String password,
  required String vehicle,
}) async {
  try {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _firestore.collection('users').doc(cred.user!.uid).set({
      'uid': cred.user!.uid,
      'name': name,
      'email': email,
      'role': 'driver',
      'vehicle': vehicle,
      'isOnline': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return null;
  } catch (e) {
    return e.toString();
  }
}

  // =========================
  // Login
  // =========================
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // =========================
  // Logout
  // =========================
  Future<void> logout() async {
    await _auth.signOut();
  }

  // =========================
  // Get User Role
  // =========================
  Future<String?> getUserRole() async {
    try {
      final uid = currentUser?.uid;
      if (uid == null) return null;

      final doc = await _firestore.collection('users').doc(uid).get();

      if (!doc.exists) return null;

      return doc['role'];
    } catch (e) {
      return null;
    }
  }
}