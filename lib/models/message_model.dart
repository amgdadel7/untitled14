class Message {
  final int? id;
  final String sender;
  String content;
  final DateTime timestamp;
  final bool isMe;
  final bool isEncrypted;

  Message({
    this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.isMe,
    this.isEncrypted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender': sender,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'isMe': isMe ? 1 : 0,
      'isEncrypted': isEncrypted ? 1 : 0,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      sender: map['sender'],
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      isMe: map['isMe'] == 1,
      isEncrypted: map['isEncrypted'] == 1,
    );
  }
}
