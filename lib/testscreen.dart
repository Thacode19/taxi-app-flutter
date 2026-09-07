import 'package:flutter/material.dart';
import './services/auth_service.dart';

class TestAuthScreen extends StatelessWidget {
  TestAuthScreen({super.key});

  final AuthService auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Test Auth")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final result = await auth.registerPassenger(
                  name: "Raydel",
                  phone: "+5977406371",
                  email: "Raydell@test.com",
                  password: "123456",
                );

                print(result ?? "Register Success");
              },
              child: const Text("Register"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () async {
                final result = await auth.login(
                  email: "Raydell@test.com",
                  password: "123456",
                );

                if (result == null) {
  print("✅ Login Success");
} else {
  print("❌ Error: $result");
}

                print(result ?? "Login Success");
              },
              child: const Text("Login"),
            ),
          ],
        ),
      ),
    );
  }
}