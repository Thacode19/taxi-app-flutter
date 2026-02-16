import 'package:flutter/material.dart';
//for the timebeing
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      //for the time being 
      body: ElevatedButton(
  onPressed: () async {
    await FirebaseAuth.instance.signInAnonymously();
  },
  child: const Text('Login (test)'),
),
      // body: Center(child: Text('Login screen (phone auth komt hier)')),
    );
  }
}
