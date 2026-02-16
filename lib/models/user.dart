class UserModel {
  final String uid;
  final String phoneNumber;
  final String role; // 'passenger' of 'driver'

  UserModel({
    required this.uid,
    required this.phoneNumber,
    required this.role,
  });

  factory UserModel.fromMap(Map<String, dynamic> data) {
    return UserModel(
      uid: data['uid'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      role: data['role'] ?? 'passenger',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'role': role,
    };
  }
}
