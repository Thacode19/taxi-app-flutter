import 'package:firebase_auth/firebase_auth.dart';
//import '../models/user.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';



class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithPhone(String phoneNumber) async {
    // Hier komt de phone auth logica, voorlopig dummy return:
    return _auth.currentUser;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

Future<void> createRide({
  required String passengerId,
  required String pickup,
  required String destination,
}) async {
  await _db.collection('rides').add({
    'passengerId': passengerId,
    'pickupText': pickup,
    'destinationText': destination,
    'status': 'requested',
    'createdAt': FieldValue.serverTimestamp(),
  });
}



}
