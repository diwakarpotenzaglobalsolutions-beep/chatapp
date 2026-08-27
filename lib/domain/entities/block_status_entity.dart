import 'package:equatable/equatable.dart';

class BlockStatusEntity extends Equatable {
  final bool blockedByMe;
  final bool blockedByPeer;

  const BlockStatusEntity({
    this.blockedByMe = false,
    this.blockedByPeer = false,
  });

  bool get isBlockedEitherWay => blockedByMe || blockedByPeer;

  @override
  List<Object?> get props => [blockedByMe, blockedByPeer];
}
