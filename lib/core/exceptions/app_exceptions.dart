class CommunicationBlockedException implements Exception {
  final String message;

  const CommunicationBlockedException([
    this.message = 'Communication is blocked',
  ]);

  @override
  String toString() => message;
}
