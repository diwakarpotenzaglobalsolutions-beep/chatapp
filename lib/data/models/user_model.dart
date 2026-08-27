import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.fullName,
    required super.username,
    required super.email,
    required super.phoneNumber,
    required super.bio,
    required super.profilePicture,
    required super.dateOfBirth,
    required super.gender,
    required super.country,
    required super.city,
    required super.onlineStatus,
    required super.lastSeen,
    required super.createdAt,
    required super.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      uid: uid,
      fullName: json['fullName'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      profilePicture: json['profilePicture'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String? ?? '',
      gender: json['gender'] as String? ?? '',
      country: json['country'] as String? ?? '',
      city: json['city'] as String? ?? '',
      onlineStatus: json['onlineStatus'] as bool? ?? false,
      lastSeen: _parseDateTime(json['lastSeen']) ?? DateTime.now(),
      createdAt: _parseDateTime(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(json['updatedAt']) ?? DateTime.now(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'username': username,
      'email': email,
      'phoneNumber': phoneNumber,
      'bio': bio,
      'profilePicture': profilePicture,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'country': country,
      'city': city,
      'onlineStatus': onlineStatus,
      'lastSeen': lastSeen.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      uid: entity.uid,
      fullName: entity.fullName,
      username: entity.username,
      email: entity.email,
      phoneNumber: entity.phoneNumber,
      bio: entity.bio,
      profilePicture: entity.profilePicture,
      dateOfBirth: entity.dateOfBirth,
      gender: entity.gender,
      country: entity.country,
      city: entity.city,
      onlineStatus: entity.onlineStatus,
      lastSeen: entity.lastSeen,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }
}
