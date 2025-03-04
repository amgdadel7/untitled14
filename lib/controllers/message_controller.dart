import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

import '../models/message_model.dart';
import '../models/conversation_key.dart';
import '../utils/encryption.dart';

class MessageController with ChangeNotifier {
  final Telephony _telephony = Telephony.instance;
  Database? _messagesDb;
  Database? _keysDb;

  MessageController() {
    _initDatabases();
  }

  Future<void> _initDatabases() async {
    final messagesPath = await getDatabasesPath();
    final messagesDbPath = join(messagesPath, 'messages.db');
    _messagesDb = await openDatabase(
      messagesDbPath,
      version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY,
            sender TEXT,
            content TEXT,
            timestamp TEXT,
            isMe INTEGER,
            isEncrypted INTEGER
          )
        ''');
      },
    );

    final keysPath = await getDatabasesPath();
    final keysDbPath = join(keysPath, 'keys.db');
    _keysDb = await openDatabase(
      keysDbPath,
      version: 1,
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE conversation_keys(
            address TEXT PRIMARY KEY,
            own_private_key TEXT,
            own_public_key TEXT,
            their_public_key TEXT,
            shared_secret TEXT
          )
        ''');
      },
    );

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        await processIncomingSms(message);
      },
    );
  }

  Future<void> processIncomingSms(SmsMessage sms) async {
    String address = sms.address ?? 'Unknown';
    String content = sms.body ?? '';
    DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0);
    bool isMe = false;

    if (content.startsWith('ECDH_KEY_EXCHANGE:')) {
      String publicKeyStr = content.substring('ECDH_KEY_EXCHANGE:'.length);
      await _processReceivedPublicKey(address, publicKeyStr);
      return;
    }

    ConversationKey? key = await getConversationKey(address);
    String decryptedContent = content;
    if (key != null && key.sharedSecret != null) {
      try {
        decryptedContent = DiffieHellmanHelper.decryptMessage(content, key.sharedSecret!);
      } catch (e) {
        print('Failed to decrypt message: $e');
      }
    }

    Message message = Message(
      sender: address,
      content: decryptedContent,
      timestamp: timestamp,
      isMe: isMe,
      isEncrypted: key != null,
    );
    await _insertMessage(message);
    notifyListeners();
  }

  Future<void> _processReceivedPublicKey(String address, String publicKeyStr) async {
    ConversationKey? existingKey = await getConversationKey(address);

    if (existingKey == null) {
      final keyPair = DiffieHellmanHelper.generateKeyPair();
      final ecPrivate = keyPair.privateKey as ECPrivateKey;
      final ecPublic = keyPair.publicKey as ECPublicKey;

      String ownPrivateKey = ecPrivate.d!.toString();
      String ownPublicKey = '${ecPublic.Q!.x!.toBigInteger()}:${ecPublic.Q!.y!.toBigInteger()}';

      ConversationKey newKey = ConversationKey(
        address: address,
        ownPrivateKey: ownPrivateKey,
        ownPublicKey: ownPublicKey,
        theirPublicKey: publicKeyStr,
      );
      await _insertConversationKey(newKey);

      await _telephony.sendSms(
        to: address,
        message: 'ECDH_KEY_EXCHANGE:$ownPublicKey',
      );
    } else if (existingKey.theirPublicKey == null) {
      final ecPrivate = ECPrivateKey(
        BigInt.parse(existingKey.ownPrivateKey),
        DiffieHellmanHelper.params,
      );
      final theirPublicKeyParts = publicKeyStr.split(':');
      final curve = DiffieHellmanHelper.params.curve;
      final x = BigInt.parse(theirPublicKeyParts[0]);
      final y = BigInt.parse(theirPublicKeyParts[1]);
      final point = curve.createPoint(x, y);
      final theirPublicKey = ECPublicKey(point, DiffieHellmanHelper.params);


      final sharedSecret = DiffieHellmanHelper.computeSharedSecret(
        ecPrivate,
        theirPublicKey,
      );

      ConversationKey updatedKey = existingKey.copyWith(
        theirPublicKey: publicKeyStr,
        sharedSecret: sharedSecret.toString(),
      );
      await _insertConversationKey(updatedKey);
    }

    notifyListeners();
  }

  Future<void> _insertMessage(Message message) async {
    await _messagesDb?.insert('messages', message.toMap());
  }

  Future<List<Message>> getMessagesForThread(String address) async {
    List<Map> maps = await _messagesDb?.query(
      'messages',
      where: 'sender = ?',
      whereArgs: [address],
    ) ?? [];
    return maps.map((map) => Message.fromMap(Map<String, dynamic>.from(map))).toList();

  }

  Future<void> _insertConversationKey(ConversationKey key) async {
    await _keysDb?.insert(
      'conversation_keys',
      key.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ConversationKey?> getConversationKey(String address) async {
    List<Map> maps = await _keysDb?.query(
      'conversation_keys',
      where: 'address = ?',
      whereArgs: [address],
    ) ?? [];
    if (maps.isNotEmpty) {
      return ConversationKey.fromMap(Map<String, dynamic>.from(maps.first));
    }
    return null;
  }

  // Future<void> sendSMS(String message, List<String> recipients) async {
  //   try {
  //     if (await Permission.sms.request().isGranted) {
  //       for (String recipient in recipients) {
  //         ConversationKey? key = await getConversationKey(recipient);
  //         String encryptedMessage = message;
  //         if (key == null || key.sharedSecret == null) {
  //           await _initiateKeyExchange(recipient);
  //           return;
  //         } else {
  //           encryptedMessage = DiffieHellmanHelper.encryptMessage(message, key.sharedSecret!);
  //         }
  //
  //         await _telephony.sendSms(
  //           to: recipient,
  //           message: encryptedMessage,
  //         );
  //
  //         Message localMessage = Message(
  //           sender: recipient,
  //           content: message,
  //           timestamp: DateTime.now(),
  //           isMe: true,
  //           isEncrypted: true,
  //         );
  //         await _insertMessage(localMessage);
  //       }
  //       notifyListeners();
  //     } else {
  //       throw "تم رفض إذن إرسال الرسائل";
  //     }
  //   } catch (e) {
  //     throw "فشل في إرسال الرسالة: $e";
  //   }
  // }
  Future<void> sendSMS(String message, List<String> recipients) async {
    try {
      if (await Permission.sms.request().isGranted) {
        for (String recipient in recipients) {
          String finalMessage = message; // الرسالة النهائية التي سيتم إرسالها

          // التحقق من وجود مفتاح المحادثة
          ConversationKey? key = await getConversationKey(recipient);
          if (key != null && key.sharedSecret != null) {
            // تشفير الرسالة إذا كان هناك مفتاح مشترك
            finalMessage = DiffieHellmanHelper.encryptMessage(message, key.sharedSecret!);

          } else {
            print("⚠️ لم يتم تبادل المفاتيح بعد، سيتم إرسال الرسالة بدون تشفير.");
          }

          // إرسال الرسالة (سواء كانت مشفرة أو غير مشفرة)
          await _telephony.sendSms(
            to: recipient,
            message: finalMessage,
          );

          // حفظ الرسالة في قاعدة البيانات
          Message localMessage = Message(
            sender: recipient,
            content: message, // حفظ الرسالة الأصلية (غير المشفرة)
            timestamp: DateTime.now(),
            isMe: true,
            isEncrypted: key != null && key.sharedSecret != null,
          );
          await _insertMessage(localMessage);
        }
        notifyListeners();
      } else {
        throw "تم رفض إذن إرسال الرسائل";
      }
    } catch (e) {
      throw "فشل في إرسال الرسالة: $e";
    }
  }


  Future<void> _initiateKeyExchange(String recipient) async {
    final keyPair = DiffieHellmanHelper.generateKeyPair();
    final ecPublic = keyPair.publicKey as ECPublicKey;
    String ownPublicKey = '${ecPublic.Q!.x!.toBigInteger()}:${ecPublic.Q!.y!.toBigInteger()}';
    String ownPrivateKey = (keyPair.privateKey as ECPrivateKey).d!.toString();

    ConversationKey newKey = ConversationKey(
      address: recipient,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
    );
    await _insertConversationKey(newKey);

    await _telephony.sendSms(
      to: recipient,
      message: 'ECDH_KEY_EXCHANGE:$ownPublicKey',
    );
  }
  Future<Map<String, List<SmsMessage>>> getConversations() async {
    if (await Permission.sms.request().isGranted) {
      // الحصول على الرسائل الواردة والصادرة
      List<SmsMessage> inbox = await _telephony.getInboxSms();
      List<SmsMessage> sent = await _telephony.getSentSms();

      // إنشاء نسخة قابلة للتعديل من القوائم
      List<SmsMessage> allMessages = List<SmsMessage>.from(inbox)..addAll(List<SmsMessage>.from(sent));

      // تجميع الرسائل حسب الرقم
      Map<String, List<SmsMessage>> groupedMessages = {};
      for (var message in allMessages) {
        String address = message.address ?? "Unknown";
        if (!groupedMessages.containsKey(address)) {
          groupedMessages[address] = []; // إنشاء قائمة جديدة قابلة للتعديل
        }
        groupedMessages[address]!.add(message);
      }

      return groupedMessages;
    } else {
      throw "تم رفض إذن قراءة الرسائل";
    }
  }
}
// import 'package:flutter/material.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:telephony/telephony.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'package:untitled14/models/message_model.dart';
// import 'package:untitled14/utils/encryption.dart';
// import 'package:path/path.dart';
// import 'package:flutter/foundation.dart';
//
//
// class MessageController with ChangeNotifier {
//   final Telephony _telephony = Telephony.instance;
//
//   /// إرسال رسالة نصية إلى قائمة من المستقبلين
//   Future<void> sendSMS(String message, List<String> recipients) async {
//     try {
//       if (await Permission.sms.request().isGranted) {
//         for (String recipient in recipients) {
//           await _telephony.sendSms(
//             to: recipient,
//             message: message,
//           );
//         }
//         notifyListeners(); // إعلام المستمعين بالتحديث
//       } else {
//         throw "تم رفض إذن إرسال الرسائل";
//       }
//     } catch (e) {
//       throw "فشل في إرسال الرسالة: $e";
//     }
//   }
//   Future<Map<String, List<SmsMessage>>> getConversations() async {
//     if (await Permission.sms.request().isGranted) {
//       // الحصول على الرسائل الواردة والصادرة
//       List<SmsMessage> inbox = await _telephony.getInboxSms();
//       List<SmsMessage> sent = await _telephony.getSentSms();
//
//       // دمج الرسائل في قائمة واحدة
//       List<SmsMessage> allMessages =
//       List<SmsMessage>.from(inbox)..addAll(List<SmsMessage>.from(sent));
//
//       // تجميع الرسائل حسب الرقم (address)
//       Map<String, List<SmsMessage>> groupedMessages = {};
//       for (var message in allMessages) {
//         String address = message.address ?? "Unknown";
//         if (!groupedMessages.containsKey(address)) {
//           groupedMessages[address] = [];
//         }
//         groupedMessages[address]!.add(message);
//       }
//
//       return groupedMessages;
//     } else {
//       throw "تم رفض إذن قراءة الرسائل";
//     }
//   }
//
//
//
//   // جلب رسائل المحادثة الخاصة بعنوان محدد (رسائل واردة ومرسلة)
//   Future<List<Message>> getMessagesForThread(String address) async {
//   if (await Permission.sms.request().isGranted) {
//   // جلب الرسائل الواردة التي تخص هذا العنوان
//   List<SmsMessage> inbox = await _telephony.getInboxSms(
//   filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
//   );
//   // جلب الرسائل المرسلة التي تخص هذا العنوان
//   List<SmsMessage> sent = await _telephony.getSentSms(
//   filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
//   );
//
//   List<Message> messages = [];
//
//   // تحويل رسائل الوارد إلى كائنات Message (isMe: false)
//   for (var sms in inbox) {
//   DateTime date = DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0);
//   messages.add(Message(
//   sender: address,
//   content: sms.body ?? "",
//   timestamp: date,
//   isMe: false,
//   ));
//   }
//   // تحويل رسائل الصادر إلى كائنات Message (isMe: true)
//   for (var sms in sent) {
//   DateTime date = DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0);
//   messages.add(Message(
//   sender: address,
//   content: sms.body ?? "",
//   timestamp: date,
//   isMe: true,
//   ));
//   }
//   // ترتيب الرسائل بحيث يكون الأحدث أولاً
//   messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//   return messages;
//   } else {
//   throw "تم رفض إذن قراءة الرسائل";
//   }
//   }
//
// }

//
// class MessageController with ChangeNotifier {
//   final Telephony _telephony = Telephony.instance;
//
//   // إرسال الرسالة
//   Future<void> sendSMS(String message, List<String> recipients) async {
//     try {
//       if (await Permission.sms.request().isGranted) {
//         for (String recipient in recipients) {
//           await _telephony.sendSms(
//             to: recipient,
//             message: message,
//           );
//         }
//         notifyListeners(); // إعلام المشتركين بالتحديث
//       } else {
//         throw "تم رفض إذن إرسال الرسائل";
//       }
//     } catch (e) {
//       throw "فشل في إرسال الرسالة: $e";
//     }
//   }
//
//   // الحصول على جميع المحادثات
//   Future<Map<String, List<SmsMessage>>> getConversations() async {
//     if (await Permission.sms.request().isGranted) {
//       // الحصول على الرسائل الواردة والصادرة
//       List<SmsMessage> inbox = await _telephony.getInboxSms();
//       List<SmsMessage> sent = await _telephony.getSentSms();
//
//       // إنشاء نسخة قابلة للتعديل من القوائم
//       List<SmsMessage> allMessages = List<SmsMessage>.from(inbox)..addAll(List<SmsMessage>.from(sent));
//
//       // تجميع الرسائل حسب الرقم
//       Map<String, List<SmsMessage>> groupedMessages = {};
//       for (var message in allMessages) {
//         String address = message.address ?? "Unknown";
//         if (!groupedMessages.containsKey(address)) {
//           groupedMessages[address] = []; // إنشاء قائمة جديدة قابلة للتعديل
//         }
//         groupedMessages[address]!.add(message);
//       }
//
//       return groupedMessages;
//     } else {
//       throw "تم رفض إذن قراءة الرسائل";
//     }
//   }
//
//   // الحصول على رسائل محادثة محددة
//   Future<List<SmsMessage>> getMessagesForThread(String address) async {
//     if (await Permission.sms.request().isGranted) {
//       List<SmsMessage> inbox = await _telephony.getInboxSms(
//         filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
//       );
//       List<SmsMessage> sent = await _telephony.getSentSms(
//         filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
//       );
//
//       // إنشاء نسخة قابلة للتعديل من القوائم
//       List<SmsMessage> allMessages = List<SmsMessage>.from(inbox)..addAll(List<SmsMessage>.from(sent));
//       allMessages.sort((a, b) => (b.date ?? 0).compareTo(a.date ?? 0)); // ترتيب الرسائل من الأحدث إلى الأقدم
//
//       return allMessages;
//     } else {
//       throw "تم رفض إذن قراءة الرسائل";
//     }
//   }
// }

// late Database _database;
// final List<Message> _messages = [];
//
// List<Message> get messages => _messages;
//
// Future<void> initDatabase() async {
//   _database = await openDatabase(
//     join(await getDatabasesPath(), 'messages.db'),
//     onCreate: (db, version) {
//       return db.execute(
//         "CREATE TABLE messages(id INTEGER PRIMARY KEY AUTOINCREMENT, sender TEXT, content TEXT, timestamp TEXT, isMe INTEGER)",
//       );
//     },
//     version: 1,
//   );
// }
// Future<void> sendMessage(String message, String recipient, String key) async {
//   String encryptedMessage = EncryptionUtils.encryptMessage(message, key);
//   final newMessage = Message(sender: recipient, content: encryptedMessage, timestamp: DateTime.now(), isMe: true);
//
//   _messages.insert(0, newMessage);
//   await _database.insert('messages', newMessage.toMap());
//   notifyListeners();
// }

// Future<List<Message>> getMessagesForThread(String address, String key) async {
//   final List<Map<String, dynamic>> maps =
//   await _database.query('messages', where: "sender = ?", whereArgs: [address]);
//   return List.generate(maps.length, (i) {
//     String decryptedMessage = EncryptionUtils.decryptMessage(maps[i]['content'], key);
//     return Message.fromMap(maps[i])..content = decryptedMessage;
//   });
// }

/// جلب رسائل المحادثة الخاصة بعنوان محدد (رسائل واردة ومرسلة)
// Future<List<Message>> getMessagesForThread(String address) async {
//   if (await Permission.sms.request().isGranted) {
//     // جلب الرسائل الواردة التي تخص هذا العنوان
//     List<SmsMessage> inbox = await _telephony.getInboxSms(
//       filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
//     );
//     // جلب الرسائل المرسلة التي تخص هذا العنوان
//     List<SmsMessage> sent = await _telephony.getSentSms(
//       filter: SmsFilter.where(SmsColumn.ADDRESS).equals(address),
//     );
//
//     List<Message> messages = [];
//
//     // تحويل رسائل الوارد إلى كائنات Message (isMe: false)
//     for (var sms in inbox) {
//       DateTime date = DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0);
//       messages.add(Message(
//         sender: address,
//         content: sms.body ?? "",
//         timestamp: date,
//         isMe: false,
//       ));
//     }
//     // تحويل رسائل الصادر إلى كائنات Message (isMe: true)
//     for (var sms in sent) {
//       DateTime date = DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0);
//       messages.add(Message(
//         sender: address,
//         content: sms.body ?? "",
//         timestamp: date,
//         isMe: true,
//       ));
//     }
//     // ترتيب الرسائل بحيث يكون الأحدث أولاً
//     messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
//     return messages;
//   } else {
//     throw "تم رفض إذن قراءة الرسائل";
//   }
// }