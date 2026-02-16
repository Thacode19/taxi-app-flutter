 import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';


// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   //await testFirestore();
//   runApp(const MyApp());
// }

// Future<void> testFirestore() async {
//    try {
//      // 1️⃣ Data schrijven
//      await FirebaseFirestore.instance
//          .collection('test')
//          .doc('hello')
//          .set({
//        'message': 'Firebase werkt!',
//        'time': DateTime.now().toString(),
//      });

//      print('Data geschreven');

//      // 2️⃣ Data lezen
//      final doc = await FirebaseFirestore.instance
//          .collection('test')
//          .doc('hello')
//          .get();

//      print('Gelezen data: ${doc.data()}');
//    } catch (e) {
//      print('Firestore fout: $e');
//    }
//  }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return const MaterialApp(
//       title: 'Firestore Live Demo',
//       home: FirestoreLiveDemo(),
//     );
//   }
// }

 

// class FirestoreLiveDemo extends StatelessWidget {
//   const FirestoreLiveDemo({super.key});

//   Future<void> onPressed() async{
//     //print(buttonName);
//     await testFirestore();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Firestore realtime')),
//       body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//         stream: FirebaseFirestore.instance
//             .collection('test')
//             .doc('hello')
//             .snapshots(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return const Center(child: Text('Fout bij laden'));
//           }

//           if (!snapshot.hasData) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           final data = snapshot.data!.data();

//           if (data == null) {
//             return const Center(child: Text('Geen data'));
//           }

//           return Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   data['message'] ?? '',
//                   style: const TextStyle(fontSize: 24),
//                 ),
//                 const SizedBox(height: 12),
//                 Text(data['time'] ?? ''),
//                 ElevatedButton(onPressed: (){onPressed();}, child: Text('press me'))
//               ],
//             ),
//           );
//         },
//       ),
//     );
//   }
// }


 
 import 'package:flutter/material.dart';
 import 'firebase_options.dart';
 import 'app.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const MyApp());
// }


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
