import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class PendingApprovalScreen extends StatelessWidget {
  final String status; // 'pending' or 'rejected'

  const PendingApprovalScreen({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final rejected = status == 'rejected';

    return Scaffold(
      appBar: AppBar(title: const Text("Account status")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              rejected ? Icons.cancel_outlined : Icons.hourglass_top,
              size: 64,
              color: rejected ? Colors.red : Colors.orange,
            ),
            const SizedBox(height: 20),
            Text(
              rejected
                  ? "Je aanmelding is afgewezen"
                  : "Je account wordt beoordeeld",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              rejected
                  ? "Neem contact op met het platform voor meer informatie."
                  : "Zodra een beheerder je gegevens heeft gecontroleerd, "
                      "krijg je toegang tot het chauffeursdashboard. "
                      "Dit kan even duren.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: () => AuthService().logout(),
              child: const Text("Uitloggen"),
            ),
          ],
        ),
      ),
    );
  }
}
