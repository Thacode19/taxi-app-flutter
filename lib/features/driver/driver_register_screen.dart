import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class DriverRegisterScreen extends StatefulWidget {
  const DriverRegisterScreen({super.key});

  @override
  State<DriverRegisterScreen> createState() => _DriverRegisterScreenState();
}

class _DriverRegisterScreenState extends State<DriverRegisterScreen> {
  final auth = AuthService();

  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final vehicle = TextEditingController();
  final licenseNumber = TextEditingController();
  final plateNumber = TextEditingController();

  bool loading = false;

  Future<void> register() async {
    setState(() => loading = true);

    final result = await auth.registerDriver(
      name: name.text.trim(),
      email: email.text.trim(),
      password: password.text.trim(),
      vehicle: vehicle.text.trim(),
      licenseNumber: licenseNumber.text.trim(),
      plateNumber: plateNumber.text.trim(),
    );

    setState(() => loading = false);

    if (!mounted) return;

    if (result == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  Widget input(String label, TextEditingController c, {bool hide = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: hide,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Register")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            input("Naam", name),
            input("Email", email),
            input("Password", password, hide: true),
            input("Voertuig", vehicle),
            input("Rijbewijsnummer", licenseNumber),
            input("Kenteken", plateNumber),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: loading ? null : register,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Registreren"),
            ),
          ],
        ),
      ),
    );
  }
}
