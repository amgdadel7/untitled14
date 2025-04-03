import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:telephony/telephony.dart';

import '../models/message_model.dart';
import '../models/conversation_key.dart';
import '../utils/encryption.dart';
import '../services/key_exchange_service.dart';

class MessageController with ChangeNotifier {
  final Telephony _telephony = Telephony.instance;

  Database? _messagesDb;
  Database? _keysDb;

  final KeyExchangeService _keyExchangeService = KeyExchangeService();

  MessageController() {
    initDatabases();
  }

  Future<void> initDatabases() async {
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
      version: 2, // زيادة رقم الإصدار
      onCreate: (db, version) {
        db.execute('''
          CREATE TABLE conversation_keys(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            address TEXT,
            sender_id TEXT,
            own_private_key TEXT,
            own_public_key TEXT,
            their_public_key TEXT,
            shared_secret TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          db.execute('ALTER TABLE conversation_keys ADD COLUMN sender_id TEXT');
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    if (_messagesDb != null) {
      List<Map<String, dynamic>> messages = await _messagesDb!.query('messages');
      print("messages______${messages}");
      return messages;
    } else {
      throw Exception('قاعدة البيانات غير مهيأة.');
    }
  }

  void printMessages() async {
    try {
      List<Map<String, dynamic>> messages = await getMessages();
      for (var message in messages) {
        print('ID: ${message['id']}, Sender: ${message['sender']}, Content: ${message['content']}, Timestamp: ${message['timestamp']}, IsMe: ${message['isMe']}, IsEncrypted: ${message['isEncrypted']}');
      }
    } catch (e) {
      print('حدث خطأ أثناء جلب البيانات: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getConversationKeys() async {
    if (_keysDb != null) {
      List<Map<String, dynamic>> keys = await _keysDb!.query('conversation_keys');
      print("keys______${keys}");
      return keys;
    } else {
      throw Exception('قاعدة البيانات غير مهيأة.');
    }
  }

  void printConversationKeys() async {
    try {
      List<Map<String, dynamic>> keys = await getConversationKeys();
      for (var key in keys) {
        print('ID: ${key['id']}, Address: ${key['address']}, Sender ID: ${key['sender_id']}, Own Private Key: ${key['own_private_key']}, Own Public Key: ${key['own_public_key']}, Their Public Key: ${key['their_public_key']}, Shared Secret: ${key['shared_secret']}');
      }
    } catch (e) {
      print('حدث خطأ أثناء جلب البيانات: $e');
    }
  }

  Future<List<SmsMessage>> getAllMessages() async {
    if (await Permission.sms.status.isGranted) {
      List<SmsMessage> inbox = await _telephony.getInboxSms();
      List<SmsMessage> sent = await _telephony.getSentSms();
      List<SmsMessage> allMessages = []..addAll(inbox)..addAll(sent);
      return allMessages;
    } else {
      throw "تم رفض إذن قراءة الرسائل";
    }
  }

  Future<Map<String, List<SmsMessage>>> getGroupedMessages() async {
    List<SmsMessage> allMessages = await getAllMessages();
    Map<String, List<SmsMessage>> groupedMessages = {};

    for (var message in allMessages) {
      String address = message.address ?? "Unknown";
      if (!groupedMessages.containsKey(address)) {
        groupedMessages[address] = [];
      }
      groupedMessages[address]!.add(message);
    }

    return groupedMessages;
  }

  Future<void> processIncomingSms(SmsMessage sms) async {
    String address = sms.address ?? 'Unknown';
    String content = sms.body ?? '';
    // DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0);
    DateTime timestamp = DateTime.now();
    bool isMe = false; // الرسالة مستلمة
    print("ECDH_KEY_EXCHANGE");
    // if (content.startsWith('ECDH_KEY_EXCHANGE:')) {
    //   print("ECDH_KEY_EXCHANGE");
    //   String publicKeyStr = content.substring('ECDH_KEY_EXCHANGE:'.length);
    //   await _processReceivedPublicKey(sms, publicKeyStr, timestamp); // تمرير sms كاملة
    //   return;
    // }

    ConversationKey? key = await getConversationKey(address);
    String decryptedContent = content;
    if (key != null && key.sharedSecret != null) {
      try {
        decryptedContent = DiffieHellmanHelper.decryptMessage(content, key.sharedSecret!);
        print("تم فك تشفير الرسالة من $address: $decryptedContent");
      } catch (e) {
        print('فشل في فك تشفير الرسالة: $e');
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

  Future<void> _insertMessage(Message message) async {
    await _messagesDb?.insert('messages', message.toMap());
    notifyListeners();
  }

  Future<void> _processReceivedPublicKey(SmsMessage sms, String publicKeyStr, DateTime timestamp) async {
    String address = sms.address ?? 'Unknown';
    String sender = address; // استخدام عنوان المرسل كقيمة لـ sender
    // أو استخدم: String sender = sms.sender; (إذا كان موجودًا في SmsMessage)

    print("Processing received public key from $address: $publicKeyStr");

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
      print("Sent public key to $address: $ownPublicKey");
    }  else if (existingKey.theirPublicKey == null) {
      final ecPrivate = ECPrivateKey(
        BigInt.parse(existingKey.ownPrivateKey),
        DiffieHellmanHelper.params,
      );
      final parts = publicKeyStr.split(':');
      final curve = DiffieHellmanHelper.params.curve;
      final x = BigInt.parse(parts[0]);
      final y = BigInt.parse(parts[1]);
      final point = curve.createPoint(x, y);
      final theirPublicKey = ECPublicKey(point, DiffieHellmanHelper.params);
      final sharedSecret = DiffieHellmanHelper.computeSharedSecret(ecPrivate, theirPublicKey);

      if (sharedSecret == null) {
        print("⚠️ Failed to compute shared secret.");
      } else {
        ConversationKey updatedKey = existingKey.copyWith(
          theirPublicKey: publicKeyStr,
          sharedSecret: sharedSecret.toString(),
        );
        await _insertConversationKey(updatedKey);
        print("Computed shared secret with $address: ${sharedSecret.toString()}");
      }
    }
    notifyListeners();
  }

  Future<List<Message>> getMessagesForThread(String address) async {
    if (await Permission.sms.status.isGranted) {
      List<SmsMessage> inbox = await _telephony.getInboxSms();
      List<SmsMessage> sent = await _telephony.getSentSms();

      List<Message> allMessages = [
        ...inbox.map((sms) => _convertSmsToMessage(sms, false)),
        ...sent.map((sms) => _convertSmsToMessage(sms, true)),
      ];

      List<Message> filteredMessages = allMessages
          .where((message) => message.sender == address)
          .toList();

      for (var message in filteredMessages) {
        print("ok");
        ConversationKey? key = await getConversationKey(address);
        print("124587${key?.sharedSecret}");
        if (key != null && key.sharedSecret != null) {
          try {
            message.content = DiffieHellmanHelper.decryptMessage(message.content, key.sharedSecret!);
            print("124587${message.content}");
            notifyListeners();
          } catch (e) {
            print('فشل في فك تشفير الرسالة: $e');
          }
        }
      }

      return filteredMessages;
    } else {
      throw "تم رفض إذن قراءة الرسائل";
    }
  }

  Message _convertSmsToMessage(SmsMessage sms, bool isMe) {
    return Message(
      sender: sms.address ?? "Unknown",
      content: sms.body ?? "",
      timestamp: DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0),
      isMe: isMe,
      isEncrypted: false,
    );
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
    ) ??
        [];

    if (maps.isNotEmpty) {
      return ConversationKey.fromMap(Map<String, dynamic>.from(maps.last));
    }

    // إذا لم يكن هناك مفتاح، يتم إنشاء مفاتيح جديدة
    final keyPair = DiffieHellmanHelper.generateKeyPair();
    final ecPrivate = keyPair.privateKey as ECPrivateKey;
    final ecPublic = keyPair.publicKey as ECPublicKey;
    String ownPrivateKey = ecPrivate.d!.toString();
    String ownPublicKey = '${ecPublic.Q!.x!.toBigInteger()}:${ecPublic.Q!.y!.toBigInteger()}';

    print("تم إنشاء زوج المفاتيح:");
    print("المفتاح العام: $ownPublicKey");
    print("المفتاح الخاص: $ownPrivateKey");

    ConversationKey newKey = ConversationKey(
      address: address,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
      theirPublicKey: null,
      sharedSecret: null,
    );

    await _insertConversationKey(newKey);

    // بدء تبادل المفاتيح عبر الإنترنت
    ConversationKey? exchangedKey = await _keyExchangeService.sendPublicKey(address, ownPublicKey);

    if (exchangedKey != null && exchangedKey.theirPublicKey != null && exchangedKey.sharedSecret != null) {
      final parts = exchangedKey.theirPublicKey!.split(':');
      final BigInt x = BigInt.parse(parts[0]);
      final BigInt y = BigInt.parse(parts[1]);
      final point = DiffieHellmanHelper.params.curve.createPoint(x, y);
      final theirPublicKeyConverted = ECPublicKey(point, DiffieHellmanHelper.params);

      final sharedSecret = DiffieHellmanHelper.computeSharedSecret(ecPrivate, theirPublicKeyConverted);
      print("🔒 المفتاح المشترك المحسوب: ${sharedSecret.toString()}");

      ConversationKey updatedKey = newKey.copyWith(
        theirPublicKey: exchangedKey.theirPublicKey,
        sharedSecret: sharedSecret.toString(),
      );

      await _insertConversationKey(updatedKey);

      print("✅ تم تبادل المفاتيح عبر الإنترنت مع $address");
      print("📌 المفتاح العام للطرف الآخر: ${exchangedKey.theirPublicKey}");
      print("🔒 المفتاح المشترك: ${sharedSecret.toString()}");

      return updatedKey; // ✅ إرجاع المفتاح بعد التحديث
    } else {
      print("⚠️ لم يتم تبادل المفاتيح عبر الإنترنت بعد.");
      return newKey; // ✅ إرجاع المفتاح الجديد حتى لو لم يتم التبادل
    }
  }


  Future<void> sendSMS(String message, List<String> recipients) async {
    try {
      if (await Permission.sms.request().isGranted) {
        for (String recipient in recipients) {
          String finalMessage = message;

          ConversationKey? key = await getConversationKey(recipient);
          if (key != null && key.sharedSecret != null) {
            finalMessage = DiffieHellmanHelper.encryptMessage(message, key.sharedSecret!);
            print("الرسالة المشفرة: $finalMessage");
          } else {
            print("⚠️ لم يتم تبادل المفاتيح بعد، سيتم إرسال الرسالة بدون تشفير.");
          }

          await _telephony.sendSms(
            to: recipient,
            message: finalMessage,
          );

          Message localMessage = Message(
            sender: recipient,
            content: message,
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

  Future<void> initiateKeyExchange(String recipient) async {

    ConversationKey? existingKey = await getConversationKey(recipient);
    if (existingKey != null && existingKey.sharedSecret != null) {
      print("Existing shared secret: ${existingKey.sharedSecret}");
      return;
    }

    final keyPair = DiffieHellmanHelper.generateKeyPair();
    final ecPrivate = keyPair.privateKey as ECPrivateKey;
    final ecPublic = keyPair.publicKey as ECPublicKey;
    String ownPrivateKey = ecPrivate.d!.toString();
    String ownPublicKey = '${ecPublic.Q!.x!.toBigInteger()}:${ecPublic.Q!.y!.toBigInteger()}';

    print("تم إنشاء زوج المفاتيح:");
    print("المفتاح العام: $recipient");
    print("المفتاح الخاص: $ownPrivateKey");

    ConversationKey newKey = ConversationKey(
      address: recipient,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
      theirPublicKey: null,
      sharedSecret: null,
    );
    await _insertConversationKey(newKey);

    ConversationKey? exchangedKey = await _keyExchangeService.sendPublicKey(recipient, ownPublicKey);
    if (exchangedKey != null &&
        exchangedKey.theirPublicKey != null &&
        exchangedKey.sharedSecret != null) {
      final parts = exchangedKey.theirPublicKey!.split(':');
      final BigInt x = BigInt.parse(parts[0]);
      final BigInt y = BigInt.parse(parts[1]);
      final point = DiffieHellmanHelper.params.curve.createPoint(x, y);
      final theirPublicKeyConverted = ECPublicKey(point, DiffieHellmanHelper.params);

      final sharedSecret = DiffieHellmanHelper.computeSharedSecret(ecPrivate, theirPublicKeyConverted);
      print("🔒 المفتاح المشترك المحسوب: ${sharedSecret.toString()}");

      ConversationKey updatedKey = newKey.copyWith(
        theirPublicKey: exchangedKey.theirPublicKey,
        sharedSecret: sharedSecret.toString(),
      );
      await _insertConversationKey(updatedKey);
      print("✅ تم تبادل المفاتيح عبر الإنترنت مع $recipient");
      // print("📌 المفتاح العام للطرف الآخر: ${exchangedKey.theirPublicKey}");
      print("🔒 المفتاح المشترك: ${sharedSecret.toString()}");
    } else {
      print("⚠️ لم يتم تبادل المفاتيح عبر الإنترنت بعد.");
    }
  }

  Future<Map<String, List<SmsMessage>>> getConversations() async {
    if (await Permission.sms.request().isGranted) {
      List<SmsMessage> inbox = await _telephony.getInboxSms();
      List<SmsMessage> sent = await _telephony.getSentSms();
      List<SmsMessage> allMessages = List<SmsMessage>.from(inbox)..addAll(List<SmsMessage>.from(sent));

      Map<String, List<SmsMessage>> groupedMessages = {};
      for (var message in allMessages) {
        String address = message.address ?? "Unknown";
        if (!groupedMessages.containsKey(address)) {
          groupedMessages[address] = [];
        }
        groupedMessages[address]!.add(message);
      }

      return groupedMessages;
    } else {
      throw "تم رفض إذن قراءة الرسائل";
    }
  }
}