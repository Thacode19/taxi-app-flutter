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
  required String licenseNumber,
  required String plateNumber,
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
      'licenseNumber': licenseNumber,
      'plateNumber': plateNumber,
      'verificationStatus': 'pending', // pending | approved | rejected
      'isOnline': false,
      'earnings': 0,
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