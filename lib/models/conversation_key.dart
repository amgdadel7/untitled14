class ConversationKey {
  final String address;
  final String ownPrivateKey;
  final String ownPublicKey;
  final String? theirPublicKey;
  final String? sharedSecret;

  ConversationKey({
    required this.address,
    required this.ownPrivateKey,
    required this.ownPublicKey,
    this.theirPublicKey,
    this.sharedSecret,
  });

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'own_private_key': ownPrivateKey,
      'own_public_key': ownPublicKey,
      'their_public_key': theirPublicKey,
      'shared_secret': sharedSecret,
    };
  }

  factory ConversationKey.fromMap(Map<String, dynamic> map) {
    return ConversationKey(
      address: map['address'],
      ownPrivateKey: map['own_private_key'],
      ownPublicKey: map['own_public_key'],
      theirPublicKey: map['their_public_key'],
      sharedSecret: map['shared_secret'],
    );
  }

  ConversationKey copyWith({
    String? theirPublicKey,
    String? sharedSecret,
  }) {
    return ConversationKey(
      address: address,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
      theirPublicKey: theirPublicKey ?? this.theirPublicKey,
      sharedSecret: sharedSecret ?? this.sharedSecret,
    );
  }
}