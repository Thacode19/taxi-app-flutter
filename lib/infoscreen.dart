import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  User? user = FirebaseAuth.instance.currentUser;
  Map<String, dynamic>? userData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }

  Future<void> fetchUserData() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();

    if (doc.exists) {
      setState(() {
        userData = doc.data();
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    // eventueel redirect naar login
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("Niet ingelogd")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Test Screen"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : userData == null
              ? const Center(child: Text("Geen user data gevonden"))
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("UID: ${user!.uid}"),
                      const SizedBox(height: 10),
                      Text("Email: ${userData!['email']}"),
                      Text("Naam: ${userData!['name']}"),
                      Text("Telefoon: ${userData!['phone']}"),
                      Text("Role: ${userData!['role']}"),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: logout,
                        child: const Text("Logout"),
                      ),
                    ],
                  ),
                ),
    );
  }
}