import 'package:equatable/equatable.dart';

class BlockedUserEntity extends Equatable {
  final String blockedUserId;
  final String blockedUserName;
  final String blockedUserImage;
  final DateTime blockedAt;

  const BlockedUserEntity({
    required this.blockedUserId,
    required this.blockedUserName,
    this.blockedUserImage = '',
    required this.blockedAt,
  });

  @override
  List<Object?> get props => [
        blockedUserId,
        blockedUserName,
        blockedUserImage,
        blockedAt,
      ];
}
