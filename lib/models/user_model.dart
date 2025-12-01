import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String fullName;
  final DateTime birthDate;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.fullName,
    required this.birthDate,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'fullName': fullName,
      'birthDate': Timestamp.fromDate(birthDate),
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      fullName: map['fullName'] ?? '',
      birthDate: (map['birthDate'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
