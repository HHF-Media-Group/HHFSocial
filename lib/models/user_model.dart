import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String username;
  final String fullName;
  final DateTime birthDate;
  final DateTime createdAt;
  final String? profilePictureUrl;
  final String? bio;
  final String? website;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.fullName,
    required this.birthDate,
    required this.createdAt,
    this.profilePictureUrl,
    this.bio,
    this.website,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'fullName': fullName,
      'birthDate': Timestamp.fromDate(birthDate),
      'createdAt': Timestamp.fromDate(createdAt),
      'profilePictureUrl': profilePictureUrl,
      'bio': bio,
      'website': website,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    // Handle Timestamp fields that might be null
    DateTime parseBirthDate() {
      final value = map['birthDate'];
      if (value is Timestamp) return value.toDate();
      return DateTime(2000, 1, 1); // Default fallback
    }

    DateTime parseCreatedAt() {
      final value = map['createdAt'];
      if (value is Timestamp) return value.toDate();
      return DateTime.now(); // Default fallback
    }

    return UserModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      fullName: map['fullName'] ?? '',
      birthDate: parseBirthDate(),
      createdAt: parseCreatedAt(),
      profilePictureUrl: map['profilePictureUrl'],
      bio: map['bio'],
      website: map['website'],
    );
  }

  // CopyWith for immutable updates
  // Use clearProfilePicture: true to explicitly set profilePictureUrl to null
  UserModel copyWith({
    String? uid,
    String? email,
    String? username,
    String? fullName,
    DateTime? birthDate,
    DateTime? createdAt,
    String? profilePictureUrl,
    String? bio,
    String? website,
    bool clearProfilePicture = false,
    bool clearBio = false,
    bool clearWebsite = false,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      birthDate: birthDate ?? this.birthDate,
      createdAt: createdAt ?? this.createdAt,
      profilePictureUrl: clearProfilePicture ? null : (profilePictureUrl ?? this.profilePictureUrl),
      bio: clearBio ? null : (bio ?? this.bio),
      website: clearWebsite ? null : (website ?? this.website),
    );
  }
}


