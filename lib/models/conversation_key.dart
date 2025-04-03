class ConversationKey {
  final int? id;
  final String address;
  final String ownPrivateKey;
  final String ownPublicKey;
  final String? theirPublicKey;
  final String? sharedSecret;

  ConversationKey({
    this.id,
    required this.address,
    required this.ownPrivateKey,
    required this.ownPublicKey,
    this.theirPublicKey,
    this.sharedSecret,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'address': address,
      'own_private_key': ownPrivateKey,
      'own_public_key': ownPublicKey,
      'their_public_key': theirPublicKey,
      'shared_secret': sharedSecret,
    };
  }

  factory ConversationKey.fromMap(Map<String, dynamic> map) {
    return ConversationKey(
      id: map['id'],
      address: map['address'],
      ownPrivateKey: map['own_private_key'],
      ownPublicKey: map['own_public_key'],
      theirPublicKey: map['their_public_key'],
      sharedSecret: map['shared_secret'],
    );
  }

  ConversationKey copyWith({
    int? id,
    String? address,
    String? ownPrivateKey,
    String? ownPublicKey,
    String? theirPublicKey,
    String? sharedSecret,
  }) {
    return ConversationKey(
      id: id ?? this.id,
      address: address ?? this.address,
      ownPrivateKey: ownPrivateKey ?? this.ownPrivateKey,
      ownPublicKey: ownPublicKey ?? this.ownPublicKey,
      theirPublicKey: theirPublicKey ?? this.theirPublicKey,
      sharedSecret: sharedSecret ?? this.sharedSecret,
    );
  }
  @override
  String toString() {
    return 'ConversationKey(address: $address, ownPrivateKey: $ownPrivateKey, ownPublicKey: $ownPublicKey, theirPublicKey: $theirPublicKey, sharedSecret: $sharedSecret)';
  }
}