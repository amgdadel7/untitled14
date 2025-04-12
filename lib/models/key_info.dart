class KeyInfo {
  final String senderUUID;
  final String senderNUM;
  final String receiverUUID;
  final String receiverNUM;
  final String sharedSecret;
  final DateTime createdAt;

  KeyInfo({
    required this.senderUUID,
    required this.senderNUM,
    required this.receiverUUID,
    required this.receiverNUM,
    required this.sharedSecret,
    required this.createdAt,
  });

  factory KeyInfo.fromJson(Map<String, dynamic> json) {
    return KeyInfo(
      senderUUID: json['senderUUID'],
      senderNUM: json['senderNUM'],
      receiverUUID: json['receiverUUID'],
      receiverNUM: json['receiverNUM'],
      sharedSecret: json['sharedSecret'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}