// // import 'package:latlong2/latlong.dart';
// // import 'dart:async';
// // import 'dart:convert';

// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:firebase_auth/firebase_auth.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter_map/flutter_map.dart';
// // import 'package:geolocator/geolocator.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:taxi_passenger/features/auth/login_screen.dart';
// // import './features/passenger/ride_tracking_screen.dart';
// // import './infoscreen.dart';

// // class MapScreen extends StatefulWidget {
// //   const MapScreen({super.key});

// //   @override
// //   State<MapScreen> createState() => _MapScreenState();
// // }

// // class SearchResult {
// //   final String displayName;
// //   final double lat;
// //   final double lon;

// //   SearchResult({
// //     required this.displayName,
// //     required this.lat,
// //     required this.lon,
// //   });

// //   factory SearchResult.fromJson(Map<String, dynamic> json) {
// //     return SearchResult(
// //       displayName: json['display_name'],
// //       lat: double.parse(json['lat']),
// //       lon: double.parse(json['lon']),
// //     );
// //   }
// // }

// // class _MapScreenState extends State<MapScreen> {
// //   LatLng? currentLocation;
// //   LatLng? searchedLocation;

// //   List<LatLng> routePoints = [];

// //   double? routeDistance; // meters
// //   double? routeDuration; // seconds

// //   final MapController mapController = MapController();
// //   final TextEditingController searchController = TextEditingController();

// //   List<SearchResult> results = [];
// //   bool isSearching = false;
// //   bool isOrdering = false;

// //   String? errorMessage;
// //   Timer? debounce;

// //   @override
// //   void initState() {
// //     super.initState();
// //     getLocation();
// //   }

// //   @override
// //   void dispose() {
// //     debounce?.cancel();
// //     searchController.dispose();
// //     super.dispose();
// //   }

// //   // ===============================
// //   // USER LOCATION
// //   // ===============================
// //   Future<void> getLocation() async {
// //     setState(() => errorMessage = null);

// //     try {
// //       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

// //       if (!serviceEnabled) {
// //         setState(() {
// //           errorMessage = 'Locatieservices zijn uitgeschakeld';
// //         });
// //         return;
// //       }

// //       LocationPermission permission = await Geolocator.checkPermission();

// //       if (permission == LocationPermission.denied) {
// //         permission = await Geolocator.requestPermission();
// //       }

// //       if (permission == LocationPermission.denied) {
// //         setState(() {
// //           errorMessage = 'Locatie geweigerd';
// //         });
// //         return;
// //       }

// //       if (permission == LocationPermission.deniedForever) {
// //         setState(() {
// //           errorMessage = 'Locatie permanent geweigerd';
// //         });
// //         return;
// //       }

// //       final position = await Geolocator.getCurrentPosition(
// //         desiredAccuracy: LocationAccuracy.bestForNavigation,
// //       );

// //       currentLocation = LatLng(position.latitude, position.longitude);

// //       if (!mounted) return;

// //       setState(() {});

// //       WidgetsBinding.instance.addPostFrameCallback((_) {
// //         mapController.move(currentLocation!, 15);
// //       });
// //     } catch (e) {
// //       setState(() {
// //         errorMessage = e.toString();
// //       });
// //     }
// //   }

// //   // ===============================
// //   // SEARCH ADDRESS met nominatim
// //   // ===============================
// //   Future<void> searchLocation(String query) async {
// //     if (query.isEmpty) {
// //       setState(() => results.clear());
// //       return;
// //     }

// //     setState(() => isSearching = true);

// //     try {
// //       // final url = Uri.parse(
// //       //   'https://nominatim.openstreetmap.org/search?q=$query Paramaribo Suriname&format=json&limit=5',
// //       // );

// //       final url = Uri.https('nominatim.openstreetmap.org', '/search', {
// //         'q': '$query Paramaribo Suriname',
// //         'format': 'json',
// //         'limit': '5',
// //       });

// //       final response = await http.get(
// //         url,
// //         headers: {'User-Agent': 'flutter_app'},
// //       );

// //       if (response.statusCode == 200) {
// //         final List data = json.decode(response.body);

// //         results = data.map((e) => SearchResult.fromJson(e)).toList();

// //         setState(() {
// //           isSearching = false;
// //         });
// //       } else {
// //         throw Exception("Zoeken mislukt");
// //       }
// //     } catch (e) {
// //       setState(() {
// //         isSearching = false;
// //         errorMessage = e.toString();
// //       });
// //     }
// //   }

// //   // ===============================
// //   // SEARCH ADDRESS met nominatim
// //   // ===============================

// //   Future<void> searchLocationGoogle(String query) async {
// //     if (query.isEmpty) {
// //       setState(() => results.clear());
// //       return;
// //     }

// //     setState(() => isSearching = true);

// //     try {
// //       final encodedQuery = Uri.encodeComponent(query);

// //       final url = Uri.parse(
// //         'https://maps.googleapis.com/maps/api/geocode/json'
// //         '?address=$encodedQuery&key=YOUR_API_KEY',
// //       );

// //       final response = await http.get(url);

// //       if (response.statusCode == 200) {
// //         final data = json.decode(response.body);

// //         final List resultsData = data['results'];

// //         results = resultsData.map((item) {
// //           final location = item['geometry']['location'];

// //           return SearchResult(
// //             displayName: item['formatted_address'],
// //             lat: location['lat'],
// //             lon: location['lng'],
// //           );
// //         }).toList();

// //         setState(() {
// //           isSearching = false;
// //         });
// //       } else {
// //         throw Exception("Google geocoding mislukt");
// //       }
// //     } catch (e) {
// //       setState(() {
// //         isSearching = false;
// //         errorMessage = e.toString();
// //       });
// //     }
// //   }

// //   // ===============================
// //   // ROUTE
// //   // ===============================
// //   Future<void> getRoute(LatLng start, LatLng end) async {
// //     try {
// //       final url = Uri.parse(
// //         'https://router.project-osrm.org/route/v1/driving/'
// //         '${start.longitude},${start.latitude};'
// //         '${end.longitude},${end.latitude}'
// //         '?overview=full&geometries=geojson',
// //       );

// //       final response = await http.get(url);

// //       if (response.statusCode == 200) {
// //         final data = json.decode(response.body);

// //         final coords =
// //             data['routes'][0]['geometry']['coordinates'] as List<dynamic>;

// //         routePoints = coords
// //             .map((e) => LatLng(e[1] as double, e[0] as double))
// //             .toList();

// //         routeDistance = data['routes'][0]['distance'];
// //         routeDuration = data['routes'][0]['duration'];

// //         setState(() {});
// //       }
// //     } catch (e) {
// //       setState(() {
// //         errorMessage = e.toString();
// //       });
// //     }
// //   }

// //   Future<void> orderTaxi() async {
// //     // ===============================
// //     // 1. CHECK BESTEMMING
// //     // ===============================
// //     if (currentLocation == null || searchedLocation == null) {
// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text("Kies eerst een bestemming")),
// //       );
// //       return;
// //     }

// //     // ===============================
// //     // 2. CHECK LOGIN
// //     // ===============================
// //     User? user = FirebaseAuth.instance.currentUser;

// //     if (user == null) {
// //       // await Navigator.push(
// //       //   context,
// //       //   MaterialPageRoute(
// //       //     builder: (_) => const LoginScreen(),
// //       //   ),
// //       // );
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(const SnackBar(content: Text("please login first")));
// //       // 🔥 REFRESH USER NA LOGIN
// //       user = FirebaseAuth.instance.currentUser;

// //       if (user == null) {
// //         return; // user heeft login geannuleerd
// //       }
// //     }

// //     // ===============================
// //     // 3. CHECK ACTIEVE RIDE
// //     // ===============================
// //     final existingRide = await FirebaseFirestore.instance
// //         .collection('rides')
// //         .where('passengerId', isEqualTo: user.uid)
// //         .where('status', whereIn: ['searching', 'accepted'])
// //         .limit(1)
// //         .get();

// //     if (existingRide.docs.isNotEmpty) {
// //       final rideId = existingRide.docs.first.id;

// //       ScaffoldMessenger.of(context).showSnackBar(
// //         const SnackBar(content: Text("Je hebt al een actieve rit")),
// //       );

// //       Navigator.push(
// //         context,
// //         MaterialPageRoute(builder: (_) => WaitingScreen(rideId: rideId)),
// //       );

// //       return; // ❗ STOP → geen nieuwe ride maken
// //     }

// //     // ===============================
// //     // 4. NIEUWE RIDE MAKEN
// //     // ===============================
// //     try {
// //       setState(() => isOrdering = true);

// //       final rideRef = await FirebaseFirestore.instance.collection('rides').add({
// //         'passengerId': user.uid,
// //         'driverId': null,
// //         'status': 'searching',
// //         'pickup': GeoPoint(
// //           currentLocation!.latitude,
// //           currentLocation!.longitude,
// //         ),
// //         'destination': GeoPoint(
// //           searchedLocation!.latitude,
// //           searchedLocation!.longitude,
// //         ),
// //         'distanceKm': (routeDistance ?? 0) / 1000,
// //         'createdAt': FieldValue.serverTimestamp(),
// //       });

// //       if (!mounted) return;

// //       Navigator.push(
// //         context,
// //         MaterialPageRoute(builder: (_) => WaitingScreen(rideId: rideRef.id)),
// //       );
// //     } catch (e) {
// //       ScaffoldMessenger.of(
// //         context,
// //       ).showSnackBar(SnackBar(content: Text(e.toString())));
// //     } finally {
// //       if (mounted) {
// //         setState(() => isOrdering = false);
// //       }
// //     }
// //   }

// //   // ===============================
// //   // UI
// //   // ===============================
// //   @override
// //   Widget build(BuildContext context) {
// //     if (errorMessage != null) {
// //       return Scaffold(body: Center(child: Text(errorMessage!)));
// //     }

// //     if (currentLocation == null) {
// //       return const Scaffold(body: Center(child: CircularProgressIndicator()));
// //     }

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text("Taxi App"),
// //         actions: [
// //           StreamBuilder<User?>(
// //             stream: FirebaseAuth.instance.authStateChanges(),
// //             builder: (context, snapshot) {
// //               final user = snapshot.data;

// //               if (user == null) {
// //                 return IconButton(
// //                   icon: const Icon(Icons.login),
// //                   onPressed: () async {
// //                     await Navigator.push(
// //                       context,
// //                       MaterialPageRoute(builder: (_) => const LoginScreen()),
// //                     );
// //                   },
// //                 );
// //               }

// //               return PopupMenuButton(
// //                 icon: const Icon(Icons.person),
// //                 itemBuilder: (context) => [
// //                   PopupMenuItem(child: Text("Email: ${user.email}")),
// //                   PopupMenuItem(
// //                     child: const Text("Logout"),
// //                     onTap: () async {
// //                       await FirebaseAuth.instance.signOut();
// //                     },
// //                   ),
// //                   PopupMenuItem(
// //                     child: const Text("user-info"),
// //                     onTap: () {
// //                       Navigator.push(
// //                         context,
// //                         MaterialPageRoute(
// //                           builder: (context) => const TestScreen(),
// //                         ),
// //                       );
// //                     },
// //                   ),
// //                 ],
// //               );
// //             },
// //           ),
// //         ],

// //         // 🔥 DIT LAAT JE GEWOON STAAN (jouw search!)
// //         bottom: PreferredSize(
// //           preferredSize: const Size.fromHeight(140),
// //           child: Column(
// //             children: [
// //               Padding(
// //                 padding: const EdgeInsets.all(8),
// //                 child: TextField(
// //                   controller: searchController,
// //                   decoration: InputDecoration(
// //                     hintText: "Zoek bestemming...",
// //                     filled: true,
// //                     fillColor: Colors.white,
// //                     border: OutlineInputBorder(
// //                       borderRadius: BorderRadius.circular(8),
// //                     ),
// //                     suffixIcon: searchController.text.isNotEmpty
// //                         ? IconButton(
// //                             onPressed: () {
// //                               searchController.clear();

// //                               setState(() {
// //                                 results.clear();
// //                                 searchedLocation = null;
// //                                 routePoints.clear();
// //                                 routeDistance = null;
// //                                 routeDuration = null;
// //                               });
// //                             },
// //                             icon: const Icon(Icons.clear),
// //                           )
// //                         : null,
// //                   ),
// //                   onChanged: (value) {
// //                     setState(() {});

// //                     if (debounce?.isActive ?? false) {
// //                       debounce!.cancel();
// //                     }

// //                     debounce = Timer(
// //                       const Duration(milliseconds: 500),
// //                       () => searchLocation(value),
// //                     );
// //                   },
// //                 ),
// //               ),

// //               if (isSearching) const LinearProgressIndicator(),

// //               if (results.isNotEmpty)
// //                 Container(
// //                   color: Colors.white,
// //                   height: 120,
// //                   child: ListView.builder(
// //                     itemCount: results.length,
// //                     itemBuilder: (context, index) {
// //                       final item = results[index];

// //                       return ListTile(
// //                         title: Text(
// //                           item.displayName,
// //                           maxLines: 1,
// //                           overflow: TextOverflow.ellipsis,
// //                         ),
// //                         onTap: () {
// //                           final location = LatLng(item.lat, item.lon);

// //                           searchedLocation = location;
// //                           results.clear();
// //                           searchController.clear();

// //                           if (currentLocation != null) {
// //                             getRoute(currentLocation!, location);
// //                           }

// //                           setState(() {});

// //                           WidgetsBinding.instance.addPostFrameCallback((_) {
// //                             mapController.move(location, 16);
// //                           });
// //                         },
// //                       );
// //                     },
// //                   ),
// //                 ),
// //             ],
// //           ),
// //         ),
// //       ),
// //       body: Stack(
// //         children: [
// //           FlutterMap(
// //             mapController: mapController,
// //             options: MapOptions(
// //               initialCenter: currentLocation!,
// //               initialZoom: 15,
// //             ),
// //             children: [
// //               TileLayer(
// //                 urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
// //                 userAgentPackageName: 'com.example.taxi_passenger',
// //               ),

// //               // route line
// //               PolylineLayer(
// //                 polylines: [
// //                   if (routePoints.isNotEmpty)
// //                     Polyline(
// //                       points: routePoints,
// //                       strokeWidth: 4,
// //                       color: Colors.green,
// //                     ),
// //                 ],
// //               ),

// //               // markers
// //               MarkerLayer(
// //                 markers: [
// //                   Marker(
// //                     point: currentLocation!,
// //                     width: 80,
// //                     height: 80,
// //                     child: const Icon(
// //                       Icons.person_pin_circle,
// //                       size: 40,
// //                       color: Colors.blue,
// //                     ),
// //                   ),
// //                   if (searchedLocation != null)
// //                     Marker(
// //                       point: searchedLocation!,
// //                       width: 80,
// //                       height: 80,
// //                       child: const Icon(
// //                         Icons.location_on,
// //                         size: 40,
// //                         color: Colors.red,
// //                       ),
// //                     ),
// //                 ],
// //               ),
// //             ],
// //           ),

// //           // route info
// //           if (routeDistance != null && routeDuration != null)
// //             Positioned(
// //               top: 16,
// //               left: 16,
// //               right: 16,
// //               child: Container(
// //                 padding: const EdgeInsets.all(10),
// //                 decoration: BoxDecoration(
// //                   color: Colors.white.withOpacity(0.95),
// //                   borderRadius: BorderRadius.circular(10),
// //                 ),
// //                 child: Text(
// //                   "Afstand: ${(routeDistance! / 1000).toStringAsFixed(2)} km"
// //                   " | Tijd: ${(routeDuration! / 60).toStringAsFixed(0)} min",
// //                   textAlign: TextAlign.center,
// //                   style: const TextStyle(fontWeight: FontWeight.bold),
// //                 ),
// //               ),
// //             ),

// //           // bestel taxi knop
// //           Positioned(
// //             left: 16,
// //             right: 80,
// //             bottom: 16,
// //             child: SizedBox(
// //               height: 56,
// //               child: ElevatedButton(
// //                 onPressed: isOrdering ? null : orderTaxi,
// //                 child: isOrdering
// //                     ? const CircularProgressIndicator()
// //                     : const Text("Bestel Taxi", style: TextStyle(fontSize: 18)),
// //               ),
// //             ),
// //           ),

// //           // current location button
// //           Positioned(
// //             right: 16,
// //             bottom: 16,
// //             child: FloatingActionButton(
// //               onPressed: () {
// //                 searchedLocation = null;
// //                 routePoints.clear();
// //                 routeDistance = null;
// //                 routeDuration = null;

// //                 setState(() {});

// //                 mapController.move(currentLocation!, 15);
// //               },
// //               child: const Icon(Icons.my_location),
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // class WaitingScreen extends StatelessWidget {
// //   final String rideId;

// //   const WaitingScreen({super.key, required this.rideId});

// //   @override
// //   Widget build(BuildContext context) {
// //     return PopScope(
// //       canPop: false,
// //       child: Scaffold(
// //         appBar: AppBar(title: const Text("Taxi zoeken")),
// //         body: StreamBuilder<DocumentSnapshot>(
// //           stream: FirebaseFirestore.instance
// //               .collection('rides')
// //               .doc(rideId)
// //               .snapshots(),
// //           builder: (context, snapshot) {
// //             if (!snapshot.hasData) {
// //               return const Center(child: CircularProgressIndicator());
// //             }

// //             final data = snapshot.data!.data() as Map<String, dynamic>;
// //             final status = data['status'];

// //             // accepted
// //             if (status == 'accepted') {
// //               WidgetsBinding.instance.addPostFrameCallback((_) {
// //                 Navigator.pushReplacement(
// //                   context,
// //                   MaterialPageRoute(
// //                     builder: (_) => RideTrackingScreen(rideId: rideId),
// //                   ),
// //                 );
// //               });
// //             }

// //             // cancelled
// //             if (status == 'cancelled') {
// //               return const Center(
// //                 child: Text("Rit geannuleerd", style: TextStyle(fontSize: 20)),
// //               );
// //             }

// //             // searching
// //             return Center(
// //               child: Column(
// //                 mainAxisAlignment: MainAxisAlignment.center,
// //                 children: [
// //                   const CircularProgressIndicator(),
// //                   const SizedBox(height: 20),
// //                   const Text(
// //                     "Zoeken naar beschikbare chauffeur...",
// //                     style: TextStyle(fontSize: 18),
// //                   ),
// //                   const SizedBox(height: 10),
// //                   Text("Ride ID: $rideId"),
// //                 ],
// //               ),
// //             );
// //           },
// //         ),
// //       ),
// //     );
// //   }
// // }

// import 'package:latlong2/latlong.dart';
// import 'dart:async';
// import 'dart:convert';

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:http/http.dart' as http;
// import 'package:taxi_passenger/features/auth/login_screen.dart';
// import './features/passenger/ride_tracking_screen.dart';
// import './infoscreen.dart';

// class MapScreen extends StatefulWidget {
//   const MapScreen({super.key});

//   @override
//   State<MapScreen> createState() => _MapScreenState();
// }

// class SearchResult {
//   final String displayName;
//   final double lat;
//   final double lon;

//   SearchResult({
//     required this.displayName,
//     required this.lat,
//     required this.lon,
//   });

//   factory SearchResult.fromJson(Map<String, dynamic> json) {
//     return SearchResult(
//       displayName: json['display_name'],
//       lat: double.parse(json['lat']),
//       lon: double.parse(json['lon']),
//     );
//   }
// }

// class _MapScreenState extends State<MapScreen> {
//   LatLng? currentLocation;
//   LatLng? searchedLocation;

//   List<LatLng> routePoints = [];

//   double? routeDistance;
//   double? routeDuration;

//   final MapController mapController = MapController();
//   final TextEditingController searchController = TextEditingController();

//   List<SearchResult> results = [];
//   bool isSearching = false;
//   bool isOrdering = false;

//   String? errorMessage;
//   Timer? debounce;

//   @override
//   void initState() {
//     super.initState();
//     getLocation();
//   }

//   @override
//   void dispose() {
//     debounce?.cancel();
//     searchController.dispose();
//     super.dispose();
//   }

//   // ===============================
//   // USER LOCATION
//   // ===============================
//   Future<void> getLocation() async {
//     setState(() => errorMessage = null);

//     try {
//       bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

//       if (!serviceEnabled) {
//         setState(() {
//           errorMessage = 'Locatieservices zijn uitgeschakeld';
//         });
//         return;
//       }

//       LocationPermission permission = await Geolocator.checkPermission();

//       if (permission == LocationPermission.denied) {
//         permission = await Geolocator.requestPermission();
//       }

//       if (permission == LocationPermission.denied) {
//         setState(() {
//           errorMessage = 'Locatie geweigerd';
//         });
//         return;
//       }

//       if (permission == LocationPermission.deniedForever) {
//         setState(() {
//           errorMessage = 'Locatie permanent geweigerd';
//         });
//         return;
//       }

//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.bestForNavigation,
//       );

//       currentLocation = LatLng(position.latitude, position.longitude);

//       if (!mounted) return;

//       setState(() {});

//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         mapController.move(currentLocation!, 15);
//       });
//     } catch (e) {
//       setState(() {
//         errorMessage = e.toString();
//       });
//     }
//   }

//   // ===============================
//   // SEARCH ADDRESS met nominatim
//   // ===============================
//   Future<void> searchLocation(String query) async {
//     if (query.isEmpty) {
//       setState(() => results.clear());
//       return;
//     }

//     setState(() => isSearching = true);

//     try {
//       final url = Uri.https('nominatim.openstreetmap.org', '/search', {
//         'q': '$query Paramaribo Suriname',
//         'format': 'json',
//         'limit': '5',
//       });

//       final response = await http.get(
//         url,
//         headers: {'User-Agent': 'flutter_app'},
//       );

//       if (response.statusCode == 200) {
//         final List data = json.decode(response.body);
//         results = data.map((e) => SearchResult.fromJson(e)).toList();
//         setState(() {
//           isSearching = false;
//         });
//       } else {
//         throw Exception("Zoeken mislukt");
//       }
//     } catch (e) {
//       setState(() {
//         isSearching = false;
//         errorMessage = e.toString();
//       });
//     }
//   }

//   // ===============================
//   // ROUTE
//   // ===============================
//   Future<void> getRoute(LatLng start, LatLng end) async {
//     try {
//       final url = Uri.parse(
//         'https://router.project-osrm.org/route/v1/driving/'
//         '${start.longitude},${start.latitude};'
//         '${end.longitude},${end.latitude}'
//         '?overview=full&geometries=geojson',
//       );

//       final response = await http.get(url);

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         final coords =
//             data['routes'][0]['geometry']['coordinates'] as List<dynamic>;
//         routePoints = coords
//             .map((e) => LatLng(e[1] as double, e[0] as double))
//             .toList();
//         routeDistance = data['routes'][0]['distance'];
//         routeDuration = data['routes'][0]['duration'];
//         setState(() {});
//       }
//     } catch (e) {
//       setState(() {
//         errorMessage = e.toString();
//       });
//     }
//   }

//   Future<void> orderTaxi() async {
//     // ===============================
//     // 1. CHECK BESTEMMING
//     // ===============================
//     if (currentLocation == null || searchedLocation == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Kies eerst een bestemming")),
//       );
//       return;
//     }

//     // ===============================
//     // 2. CHECK LOGIN
//     // ===============================
//     User? user = FirebaseAuth.instance.currentUser;

//     if (user == null) {
//       // FIX: navigeer naar LoginScreen en wacht tot gebruiker terugkomt
//       await Navigator.push(
//         context,
//         MaterialPageRoute(builder: (_) => const LoginScreen()),
//       );

//       if (!mounted) return;

//       // Haal de user opnieuw op na login
//       user = FirebaseAuth.instance.currentUser;

//       // Als gebruiker login heeft geannuleerd, stop dan
//       if (user == null) return;
//     }

//     // ===============================
//     // 3. CHECK ACTIEVE RIDE
//     // ===============================
//     final existingRide = await FirebaseFirestore.instance
//         .collection('rides')
//         .where('passengerId', isEqualTo: user.uid)
//         .where('status', whereIn: ['searching', 'accepted'])
//         .limit(1)
//         .get();

//     if (existingRide.docs.isNotEmpty) {
//       final rideId = existingRide.docs.first.id;

//       if (!mounted) return;

//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text("Je hebt al een actieve rit")),
//       );

//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (_) => WaitingScreen(rideId: rideId)),
//       );

//       return;
//     }

//     // ===============================
//     // 4. NIEUWE RIDE MAKEN
//     // ===============================
//     try {
//       setState(() => isOrdering = true);

//       final rideRef = await FirebaseFirestore.instance.collection('rides').add({
//         'passengerId': user.uid,
//         'driverId': null,
//         'status': 'searching',
//         'pickup': GeoPoint(
//           currentLocation!.latitude,
//           currentLocation!.longitude,
//         ),
//         'destination': GeoPoint(
//           searchedLocation!.latitude,
//           searchedLocation!.longitude,
//         ),
//         'distanceKm': (routeDistance ?? 0) / 1000,
//         'createdAt': FieldValue.serverTimestamp(),
//       });

//       if (!mounted) return;

//       Navigator.push(
//         context,
//         MaterialPageRoute(builder: (_) => WaitingScreen(rideId: rideRef.id)),
//       );
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text(e.toString())));
//     } finally {
//       if (mounted) {
//         setState(() => isOrdering = false);
//       }
//     }
//   }

//   // ===============================
//   // UI
//   // ===============================
//   @override
//   Widget build(BuildContext context) {
//     // FIX: retry knop toegevoegd bij locatie fout
//     if (errorMessage != null) {
//       return Scaffold(
//         body: Center(
//           child: Padding(
//             padding: const EdgeInsets.all(24),
//             child: Column(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 const Icon(Icons.location_off, size: 60, color: Colors.red),
//                 const SizedBox(height: 16),
//                 Text(
//                   errorMessage!,
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(fontSize: 16),
//                 ),
//                 const SizedBox(height: 24),
//                 ElevatedButton.icon(
//                   onPressed: getLocation,
//                   icon: const Icon(Icons.refresh),
//                   label: const Text("Probeer opnieuw"),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     if (currentLocation == null) {
//       return const Scaffold(body: Center(child: CircularProgressIndicator()));
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Taxi App"),
//         actions: [
//           StreamBuilder<User?>(
//             stream: FirebaseAuth.instance.authStateChanges(),
//             builder: (context, snapshot) {
//               final user = snapshot.data;

//               if (user == null) {
//                 return IconButton(
//                   icon: const Icon(Icons.login),
//                   onPressed: () async {
//                     await Navigator.push(
//                       context,
//                       MaterialPageRoute(builder: (_) => const LoginScreen()),
//                     );
//                   },
//                 );
//               }

//               return PopupMenuButton(
//                 icon: const Icon(Icons.person),
//                 itemBuilder: (context) => [
//                   PopupMenuItem(child: Text("Email: ${user.email}")),
//                   PopupMenuItem(
//                     child: const Text("Logout"),
//                     onTap: () async {
//                       await FirebaseAuth.instance.signOut();
//                     },
//                   ),
//                   PopupMenuItem(
//                     child: const Text("user-info"),
//                     onTap: () {
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(
//                           builder: (context) => const TestScreen(),
//                         ),
//                       );
//                     },
//                   ),
//                 ],
//               );
//             },
//           ),
//         ],
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(140),
//           child: Column(
//             children: [
//               Padding(
//                 padding: const EdgeInsets.all(8),
//                 child: TextField(
//                   controller: searchController,
//                   decoration: InputDecoration(
//                     hintText: "Zoek bestemming...",
//                     filled: true,
//                     fillColor: Colors.white,
//                     border: OutlineInputBorder(
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     suffixIcon: searchController.text.isNotEmpty
//                         ? IconButton(
//                             onPressed: () {
//                               searchController.clear();
//                               setState(() {
//                                 results.clear();
//                                 searchedLocation = null;
//                                 routePoints.clear();
//                                 routeDistance = null;
//                                 routeDuration = null;
//                               });
//                             },
//                             icon: const Icon(Icons.clear),
//                           )
//                         : null,
//                   ),
//                   onChanged: (value) {
//                     setState(() {});
//                     if (debounce?.isActive ?? false) {
//                       debounce!.cancel();
//                     }
//                     debounce = Timer(
//                       const Duration(milliseconds: 500),
//                       () => searchLocation(value),
//                     );
//                   },
//                 ),
//               ),
//               if (isSearching) const LinearProgressIndicator(),
//               if (results.isNotEmpty)
//                 Container(
//                   color: Colors.white,
//                   height: 120,
//                   child: ListView.builder(
//                     itemCount: results.length,
//                     itemBuilder: (context, index) {
//                       final item = results[index];
//                       return ListTile(
//                         title: Text(
//                           item.displayName,
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                         onTap: () {
//                           final location = LatLng(item.lat, item.lon);
//                           searchedLocation = location;
//                           results.clear();
//                           searchController.clear();
//                           if (currentLocation != null) {
//                             getRoute(currentLocation!, location);
//                           }
//                           setState(() {});
//                           WidgetsBinding.instance.addPostFrameCallback((_) {
//                             mapController.move(location, 16);
//                           });
//                         },
//                       );
//                     },
//                   ),
//                 ),
//             ],
//           ),
//         ),
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: mapController,
//             options: MapOptions(
//               initialCenter: currentLocation!,
//               initialZoom: 15,
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
//                 userAgentPackageName: 'com.example.taxi_passenger',
//               ),
//               PolylineLayer(
//                 polylines: [
//                   if (routePoints.isNotEmpty)
//                     Polyline(
//                       points: routePoints,
//                       strokeWidth: 4,
//                       color: Colors.green,
//                     ),
//                 ],
//               ),
//               MarkerLayer(
//                 markers: [
//                   Marker(
//                     point: currentLocation!,
//                     width: 80,
//                     height: 80,
//                     child: const Icon(
//                       Icons.person_pin_circle,
//                       size: 40,
//                       color: Colors.blue,
//                     ),
//                   ),
//                   if (searchedLocation != null)
//                     Marker(
//                       point: searchedLocation!,
//                       width: 80,
//                       height: 80,
//                       child: const Icon(
//                         Icons.location_on,
//                         size: 40,
//                         color: Colors.red,
//                       ),
//                     ),
//                 ],
//               ),
//             ],
//           ),
//           if (routeDistance != null && routeDuration != null)
//             Positioned(
//               top: 16,
//               left: 16,
//               right: 16,
//               child: Container(
//                 padding: const EdgeInsets.all(10),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.95),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: Text(
//                   "Afstand: ${(routeDistance! / 1000).toStringAsFixed(2)} km"
//                   " | Tijd: ${(routeDuration! / 60).toStringAsFixed(0)} min",
//                   textAlign: TextAlign.center,
//                   style: const TextStyle(fontWeight: FontWeight.bold),
//                 ),
//               ),
//             ),
//           Positioned(
//             left: 16,
//             right: 80,
//             bottom: 16,
//             child: SizedBox(
//               height: 56,
//               child: ElevatedButton(
//                 onPressed: isOrdering ? null : orderTaxi,
//                 child: isOrdering
//                     ? const CircularProgressIndicator()
//                     : const Text("Bestel Taxi", style: TextStyle(fontSize: 18)),
//               ),
//             ),
//           ),
//           Positioned(
//             right: 16,
//             bottom: 16,
//             child: FloatingActionButton(
//               onPressed: () {
//                 searchedLocation = null;
//                 routePoints.clear();
//                 routeDistance = null;
//                 routeDuration = null;
//                 setState(() {});
//                 mapController.move(currentLocation!, 15);
//               },
//               child: const Icon(Icons.my_location),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class WaitingScreen extends StatelessWidget {
//   final String rideId;

//   const WaitingScreen({super.key, required this.rideId});

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       canPop: false,
//       child: Scaffold(
//         appBar: AppBar(title: const Text("Taxi zoeken")),
//         body: StreamBuilder<DocumentSnapshot>(
//           stream: FirebaseFirestore.instance
//               .collection('rides')
//               .doc(rideId)
//               .snapshots(),
//           builder: (context, snapshot) {
//             if (!snapshot.hasData) {
//               return const Center(child: CircularProgressIndicator());
//             }

//             final data = snapshot.data!.data() as Map<String, dynamic>;
//             final status = data['status'];

//             if (status == 'accepted') {
//               WidgetsBinding.instance.addPostFrameCallback((_) {
//                 Navigator.pushReplacement(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => RideTrackingScreen(rideId: rideId),
//                   ),
//                 );
//               });
//             }

//             if (status == 'cancelled') {
//               return const Center(
//                 child: Text("Rit geannuleerd", style: TextStyle(fontSize: 20)),
//               );
//             }

//             return Center(
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   const CircularProgressIndicator(),
//                   const SizedBox(height: 20),
//                   const Text(
//                     "Zoeken naar beschikbare chauffeur...",
//                     style: TextStyle(fontSize: 18),
//                   ),
//                 ],
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }

import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:taxi_passenger/features/auth/login_screen.dart';
import './features/passenger/ride_tracking_screen.dart';
import './infoscreen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class SearchResult {
  final String displayName;
  final double lat;
  final double lon;

  SearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      displayName: json['display_name'],
      lat: double.parse(json['lat']),
      lon: double.parse(json['lon']),
    );
  }
}

class _MapScreenState extends State<MapScreen> {
  LatLng? currentLocation;
  LatLng? searchedLocation;

  List<LatLng> routePoints = [];

  double? routeDistance;
  double? routeDuration;

  final MapController mapController = MapController();
  final TextEditingController searchController = TextEditingController();

  List<SearchResult> results = [];
  bool isSearching = false;
  bool isOrdering = false;

  String? errorMessage;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    getLocation();
  }

  @override
  void dispose() {
    debounce?.cancel();
    searchController.dispose();
    super.dispose();
  }

  // ===============================
  // USER LOCATION
  // ===============================
  Future<void> getLocation() async {
    setState(() => errorMessage = null);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() => errorMessage = 'Locatieservices zijn uitgeschakeld');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        setState(() => errorMessage = 'Locatie geweigerd');
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => errorMessage = 'Locatie permanent geweigerd');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
      );

      currentLocation = LatLng(position.latitude, position.longitude);

      if (!mounted) return;

      setState(() {});

      WidgetsBinding.instance.addPostFrameCallback((_) {
        mapController.move(currentLocation!, 15);
      });
    } catch (e) {
      setState(() => errorMessage = e.toString());
    }
  }

  // ===============================
  // SEARCH
  // ===============================
  Future<void> searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() => results.clear());
      return;
    }

    setState(() => isSearching = true);

    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$query Paramaribo Suriname',
        'format': 'json',
        'limit': '5',
      });

      final response = await http.get(
        url,
        headers: {'User-Agent': 'flutter_app'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        results = data.map((e) => SearchResult.fromJson(e)).toList();
        setState(() => isSearching = false);
      } else {
        throw Exception("Zoeken mislukt");
      }
    } catch (e) {
      setState(() {
        isSearching = false;
        errorMessage = e.toString();
      });
    }
  }

  // ===============================
  // ROUTE
  // ===============================
  Future<void> getRoute(LatLng start, LatLng end) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${start.longitude},${start.latitude};'
        '${end.longitude},${end.latitude}'
        '?overview=full&geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coords =
            data['routes'][0]['geometry']['coordinates'] as List<dynamic>;
        routePoints =
            coords.map((e) => LatLng(e[1] as double, e[0] as double)).toList();
        routeDistance = data['routes'][0]['distance'];
        routeDuration = data['routes'][0]['duration'];
        setState(() {});
      }
    } catch (e) {
      setState(() => errorMessage = e.toString());
    }
  }

  // ===============================
  // ORDER TAXI
  // ===============================
  Future<void> orderTaxi() async {
    if (currentLocation == null || searchedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kies eerst een bestemming")),
      );
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );

      if (!mounted) return;

      user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
    }

    final existingRide = await FirebaseFirestore.instance
        .collection('rides')
        .where('passengerId', isEqualTo: user.uid)
        .where('status', whereIn: ['searching', 'accepted'])
        .limit(1)
        .get();

    if (!mounted) return;

    if (existingRide.docs.isNotEmpty) {
      final rideId = existingRide.docs.first.id;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Je hebt al een actieve rit")),
      );

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WaitingScreen(rideId: rideId)),
      );
      return;
    }

    try {
      setState(() => isOrdering = true);

      final rideRef =
          await FirebaseFirestore.instance.collection('rides').add({
        'passengerId': user.uid,
        'driverId': null,
        'status': 'searching',
        'pickup': GeoPoint(
          currentLocation!.latitude,
          currentLocation!.longitude,
        ),
        'destination': GeoPoint(
          searchedLocation!.latitude,
          searchedLocation!.longitude,
        ),
        'distanceKm': (routeDistance ?? 0) / 1000,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => WaitingScreen(rideId: rideRef.id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => isOrdering = false);
    }
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off, size: 60, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: getLocation,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Probeer opnieuw"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (currentLocation == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Taxi App"),
        actions: [
          StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              final user = snapshot.data;

              if (user == null) {
                return IconButton(
                  icon: const Icon(Icons.login),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                );
              }

              return PopupMenuButton(
                icon: const Icon(Icons.person),
                itemBuilder: (context) => [
                  PopupMenuItem(child: Text("Email: ${user.email}")),
                  PopupMenuItem(
                    child: const Text("Logout"),
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                  ),
                  PopupMenuItem(
                    child: const Text("user-info"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const TestScreen()),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(140),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: "Zoek bestemming...",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            onPressed: () {
                              searchController.clear();
                              setState(() {
                                results.clear();
                                searchedLocation = null;
                                routePoints.clear();
                                routeDistance = null;
                                routeDuration = null;
                              });
                            },
                            icon: const Icon(Icons.clear),
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {});
                    if (debounce?.isActive ?? false) debounce!.cancel();
                    debounce = Timer(
                      const Duration(milliseconds: 500),
                      () => searchLocation(value),
                    );
                  },
                ),
              ),
              if (isSearching) const LinearProgressIndicator(),
              if (results.isNotEmpty)
                Container(
                  color: Colors.white,
                  height: 120,
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final item = results[index];
                      return ListTile(
                        title: Text(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          final location = LatLng(item.lat, item.lon);
                          searchedLocation = location;
                          results.clear();
                          searchController.clear();
                          if (currentLocation != null) {
                            getRoute(currentLocation!, location);
                          }
                          setState(() {});
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            mapController.move(location, 16);
                          });
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: currentLocation!,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.taxi_passenger',
              ),
              PolylineLayer(
                polylines: [
                  if (routePoints.isNotEmpty)
                    Polyline(
                      points: routePoints,
                      strokeWidth: 4,
                      color: Colors.green,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: currentLocation!,
                    width: 80,
                    height: 80,
                    child: const Icon(
                      Icons.person_pin_circle,
                      size: 40,
                      color: Colors.blue,
                    ),
                  ),
                  if (searchedLocation != null)
                    Marker(
                      point: searchedLocation!,
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.location_on,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (routeDistance != null && routeDuration != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Afstand: ${(routeDistance! / 1000).toStringAsFixed(2)} km"
                  " | Tijd: ${(routeDuration! / 60).toStringAsFixed(0)} min",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          Positioned(
            left: 16,
            right: 80,
            bottom: 16,
            child: SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: isOrdering ? null : orderTaxi,
                child: isOrdering
                    ? const CircularProgressIndicator()
                    : const Text("Bestel Taxi",
                        style: TextStyle(fontSize: 18)),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              onPressed: () {
                searchedLocation = null;
                routePoints.clear();
                routeDistance = null;
                routeDuration = null;
                setState(() {});
                mapController.move(currentLocation!, 15);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================
// WAITING SCREEN
// ===============================
class WaitingScreen extends StatelessWidget {
  final String rideId;

  const WaitingScreen({super.key, required this.rideId});

  // Annuleer rit in Firestore en ga terug
  Future<void> _cancelRide(BuildContext context) async {
    await FirebaseFirestore.instance
        .collection('rides')
        .doc(rideId)
        .update({'status': 'cancelled'});

    if (!context.mounted) return;

    // Terug naar MapScreen
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  // Bevestigingsdialoog voor annuleren
  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Rit annuleren?"),
        content: const Text("Weet je zeker dat je de rit wilt annuleren?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Nee, wacht"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Ja, annuleer"),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _cancelRide(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(title: const Text("Taxi zoeken")),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rides')
              .doc(rideId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final status = data['status'];

            // Chauffeur heeft geaccepteerd → ga naar tracking
            if (status == 'accepted') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RideTrackingScreen(rideId: rideId),
                  ),
                );
              });
            }

            // Rit geannuleerd (bijv. door chauffeur)
            if (status == 'cancelled') {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel, size: 70, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      "Rit geannuleerd",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.popUntil(context, (route) => route.isFirst),
                      child: const Text("Terug naar Home"),
                    ),
                  ],
                ),
              );
            }

            // Zoeken naar chauffeur
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    const Text(
                      "Zoeken naar beschikbare chauffeur...",
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // NIEUW: annuleer knop
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _confirmCancel(context),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text(
                          "Annuleer rit",
                          style: TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}