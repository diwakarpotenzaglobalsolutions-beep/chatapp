import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String fullName;
  final String username;
  final String email;
  final String phoneNumber;
  final String bio;
  final String profilePicture;
  final String dateOfBirth;
  final String gender;
  final String country;
  final String city;
  final bool onlineStatus;
  final DateTime lastSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserEntity({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.bio,
    required this.profilePicture,
    required this.dateOfBirth,
    required this.gender,
    required this.country,
    required this.city,
    required this.onlineStatus,
    required this.lastSeen,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
        uid,
        fullName,
        username,
        email,
        phoneNumber,
        bio,
        profilePicture,
        dateOfBirth,
        gender,
        country,
        city,
        onlineStatus,
        lastSeen,
        createdAt,
        updatedAt,
      ];
}
