import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String phone;
  final String role;
  final bool isActive;

  AppUser({
    required this.uid,
    required this.phone,
    required this.role,
    required this.isActive,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      phone: data['phone'] ?? '',
      role: data['role'] ?? 'passenger',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'role': role,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
