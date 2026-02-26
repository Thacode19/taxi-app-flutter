import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final rides = FirebaseFirestore.instance.collection('rides');

  Future<void> createUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<AppUser?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.id,doc.data()!);
  }

  
  Future<String>createRit({required String passengerId,
    required String pickup,
    required String destination, 
    }) async {
      DocumentReference doc = await rides.add({
      'passengerId': passengerId,
      'pickup': pickup,
      'destination': destination,
      'status': 'waiting',

      // tijdelijk
      'driverLat': 5.8520,
      'driverLng': -55.2038,
    });

    return doc.id;
    }

  Future<void> createRide({
  required String passengerId,
  required String pickup,
  required String destination,

}) async {

double baseFare = 3;
double perKm = 2;

// Tijdelijke fake distance (later vervangen met echte berekening)
double fakeDistanceKm = 5;

double price = baseFare + (perKm * fakeDistanceKm);

if (price < 5) {
  price = 5;
}
  await _db.collection('rides').add({

    
    'price' : price,
    'passengerId': passengerId,
    'pickupText': pickup,
    'destinationText': destination,
    'status': 'requested',
    'createdAt': FieldValue.serverTimestamp(),
  });
}


Stream<QuerySnapshot> getAvailableRides() {
  return _db
      .collection('rides')
      .where('status', isEqualTo: 'requested')
      .snapshots();
}



Future<void> acceptRide({
  required String rideId,
  required String driverId,
}) async {
  await _db.collection('rides').doc(rideId).update({
    'status': 'accepted',
    'driverId': driverId,
  });
}

Stream<QuerySnapshot> getDriverActiveRide(String driverId) {
  return _db
      .collection('rides')
      .where('driverId', isEqualTo: driverId)
      .where('status', whereIn: ['accepted', 'ongoing'])
      .snapshots();
}


// Future<void> updateRideStatus({
//   required String rideId,
//   required String status,
// }) async {


  
//   await _db.collection('rides').doc(rideId).update({
//     'status': status,
//   });
// }


Future<void> updateRideStatus({
  required String rideId,
  required String status,
}) async {

  final rideRef = _db.collection('rides').doc(rideId);
  final rideSnapshot = await rideRef.get();
  final rideData = rideSnapshot.data();

  await rideRef.update({
    'status': status,
  });

  // 🔥 ALS RIT COMPLETED → driver earnings verhogen
  if (status == 'completed' && rideData != null) {
    final driverId = rideData['driverId'];
    final price = rideData['price'];

    final driverRef = _db.collection('users').doc(driverId);

    await driverRef.update({
      'earnings': FieldValue.increment(price),
    });
  }
}


}
