// class Message {
//   final String sender;
//   final String content;
//   final DateTime timestamp;
//   final bool isMe;
//
//   Message({
//     required this.sender,
//     required this.content,
//     required this.timestamp,
//     required this.isMe,
//   });
// }

class Message {
  final int id;
  final String sender;
  final String content;
  final DateTime timestamp;
  final bool isMe;
  final bool isEncrypted;

  Message({
    this.id = 0,
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
// class Message {
//   final String sender;
//   final String content;
//   final DateTime timestamp;
//   final bool isMe;
//
//   Message({
//     required this.sender,
//     required this.content,
//     required this.timestamp,
//     required this.isMe,
//   });
//
//   factory Message.fromMap(Map<String, dynamic> map) {
//     return Message(
//       sender: map['sender'],
//       content: map['content'],
//       timestamp: DateTime.parse(map['timestamp']),
//       isMe: map['isMe'] == 1,
//     );
//   }
//
//   Map<String, dynamic> toMap() {
//     return {
//       'sender': sender,
//       'content': content,
//       'timestamp': timestamp.toIso8601String(),
//       'isMe': isMe ? 1 : 0,
//     };
//   }
// }

// class Message {
//   final String sender;         // المرسل
//   final String content;       // محتوى الرسالة (غير مشفر)
//   final String? encryptedContent; // محتوى الرسالة المشفرة
//   final DateTime timestamp;   // وقت إرسال الرسالة
//   final bool isMe;            // هل الرسالة من المستخدم الحالي؟
//
//   Message({
//     required this.sender,
//     required this.content,
//     this.encryptedContent,
//     required this.timestamp,
//     required this.isMe,
//   });
// }
