import '../../domain/entities/blocked_user_entity.dart';

class BlockedUserModel extends BlockedUserEntity {
  const BlockedUserModel({
    required super.blockedUserId,
    required super.blockedUserName,
    super.blockedUserImage = '',
    required super.blockedAt,
  });

  factory BlockedUserModel.fromJson(Map<String, dynamic> json, String id) {
    return BlockedUserModel(
      blockedUserId: json['blockedUserId'] as String? ?? id,
      blockedUserName: json['blockedUserName'] as String? ?? 'Unknown',
      blockedUserImage: json['blockedUserImage'] as String? ?? '',
      blockedAt: json['blockedAt'] != null
          ? DateTime.parse(json['blockedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'blockedUserId': blockedUserId,
      'blockedUserName': blockedUserName,
      'blockedUserImage': blockedUserImage,
      'blockedAt': blockedAt.toIso8601String(),
    };
  }
}
