import 'dart:async';
import 'dart:convert';
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
import 'package:convert/convert.dart';
import 'package:untitled14/controllers/registration_controller.dart';
import 'package:http/http.dart' as http;
import 'package:untitled14/controllers/store_key_controler.dart';
import 'package:untitled14/models/key_info.dart';
import '../models/message_model.dart';
import '../models/conversation_key.dart';
import '../utils/encryption.dart';
import '../services/key_exchange_service.dart';

class MessageController with ChangeNotifier {
  final Telephony _telephony = Telephony.instance;

  Database? _messagesDb;
  Database? _keysDb;

  // final KeyExchangeService _keyExchangeService = KeyExchangeService();

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
    DateTime timestamp = DateTime.now();
    bool isMe = false;

    ConversationKey? key = await getConversationKey(address);
    String decryptedContent = content;
    bool isEncrypted = false;

    if (key != null && key.sharedSecret != null) {
      try {
        decryptedContent = DiffieHellmanHelper.decryptMessage(content, key.sharedSecret!);
        isEncrypted = true; // تم فك التشفير بنجاح
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
      isEncrypted: isEncrypted, // تعيين حالة التشفير الصحيحة
    );
    await _insertMessage(message);

    notifyListeners();
  }

  Future<void> _insertMessage(Message message) async {
    await _messagesDb?.insert('messages', message.toMap());
    notifyListeners();
  }
  Future<void> sendEncryptedMessage(String encryptedMessage, String plainTextMessage, String recipient) async {
    try {
      if (await Permission.sms.request().isGranted) {
        // إرسال الرسالة المشفرة
        print("encryptedMessage$encryptedMessage");
        print("encryptedMessage$plainTextMessage");
        print("encryptedMessage$recipient");
        await _telephony.sendSms(
          to: recipient,
          message: encryptedMessage,
        );
        // تخزين الرسالة الأصلية غير المشفرة محليًا
        Message localMessage = Message(
          sender: recipient,
          content: plainTextMessage, // حفظ النص الأصلي
          timestamp: DateTime.now(),
          isMe: true,
          isEncrypted: true, // الإشارة إلى أن الرسالة مرسلة مشفرة
        );
        await _insertMessage(localMessage);


        notifyListeners();
      }
    } catch (e) {
      throw "فشل في إرسال الرسالة: $e";
    }
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
  Future<dynamic> getAndPrintPhoneNumber() async {
    final LocalDatabaseService localDatabaseService = LocalDatabaseService();
    var senderNumber = await localDatabaseService.getDeviceInfo();
    if (senderNumber != null) {
      print('UUID: ${senderNumber["phone_num"]}');
      return senderNumber["phone_num"];
    } else {
      print('لا يوجد Sender Phone Number');
      return null;
    }


  }
  Future<dynamic> getAndPrintUuid() async {
    // 2. استدعاء الدالة
    final LocalDatabaseService localDatabaseService = LocalDatabaseService();
    final deviceInfo = await localDatabaseService.getDeviceInfo();

    if (deviceInfo != null) {
      final senderUUID = deviceInfo['uuid']!;
      final senderNUM = deviceInfo['phone_num']!; // جلب رقم الهاتف من الجهاز
      print('UUID: $senderUUID');
      print('Phone Number: $senderNUM');
      return deviceInfo;
    } else {
      print('لا توجد معلومات جهاز محفوظة محلياً');
    }
  }
  Future<String?> findDeviceUuid(String searchValue) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://political-thoracic-spatula.glitch.me/api/find-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'searchValue': searchValue}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String receverUUID = data['uuid'] as String;
        print('UUID2: $receverUUID');
        return receverUUID;
      } else {
        print('فشل البحث: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('خطأ في الاتصال: $e');
      return null;
    }
  }
  String getLastNineDigits(String address) {
    // إزالة أي مسافات أو أحرف غير رقمية إن لزم الأمر
    String digits = address.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }
  // Future<List<Message>> getMessagesForThread(String address) async {
  //   if (await Permission.sms.status.isGranted) {
  //     List<SmsMessage> inbox = await _telephony.getInboxSms();
  //     List<SmsMessage> sent = await _telephony.getSentSms();
  //
  //     List<Message> allMessages = [
  //       ...inbox.map((sms) => _convertSmsToMessage(sms, false)),
  //       ...sent.map((sms) => _convertSmsToMessage(sms, true)),
  //     ];
  //
  //     // 1. فصل معالجة العناوين النصية
  //     bool isTextAddress = RegExp(r'[a-zA-Z]').hasMatch(address);
  //     String lastNine="";
  //
  //     List<Message> filteredMessages = allMessages.where((message) {
  //       if (message.sender == null) return false;
  //
  //       // 2. مقارنة نصوصية مباشرة للعناوين غير الرقمية
  //       if (isTextAddress) {
  //         return message.sender == address;
  //       }
  //
  //       // 3. معالجة الأرقام فقط
  //       String getLast9(String phone) {
  //         String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
  //         return cleaned.length >= 9
  //             ? cleaned.substring(cleaned.length - 9)
  //             : cleaned;
  //       }
  //
  //       String messageLast9 = getLast9(message.sender);
  //       String inputLast9 = getLast9(address);
  //
  //       return messageLast9 == inputLast9;
  //     }).toList();
  //     lastNine = getLastNineDigits(address);
  //     bool receiverUUID1;
  //     // 4. فك التشفير فقط للعناوين الرقمية
  //     if (!isTextAddress) {
  //       final senderUUID = await getAndPrintUuid();
  //       final getreceiveruuid = DatabaseHelper();
  //
  //      String? receiverUUID = await getreceiveruuid.queryreceiverUUID(
  //         senderUUID: senderUUID,
  //         receiverNUM: lastNine,
  //       );
  //       print("okkkkkkkkkkkk$receiverUUID");
  //       if (receiverUUID == null) {
  //         receiverUUID = await findDeviceUuid(lastNine);
  //       }
  //       print("okkkkkkkkkkkk$receiverUUID");
  //
  //       if (receiverUUID != null) {
  //         final dbHelper = DatabaseHelper();
  //         final sharedSecret = await dbHelper.getSharedSecret(
  //           senderUUID: receiverUUID!,
  //           receiverUUID: senderUUID,
  //         );
  //         print("okkkkkkkkkkkk1$sharedSecret");
  //         if (sharedSecret != null) {
  //           print("okkkkkkkkkkkk1");
  //           for (var message in filteredMessages) {
  //             try {
  //               final secret = BigInt.parse(sharedSecret.toString());
  //               final text = message.content.toString();
  //               final enc = DiffieHellmanHelper.decryptMessage(text, secret.toString());
  //               message.content = enc;
  //             } catch (e) {
  //               print('فشل في فك تشفير الرسالة: $e');
  //             }
  //           }
  //         }
  //         else if (sharedSecret == null) {
  //           print("okkkkkkkkkkkk2");
  //
  //           print("okkkkkkkkkkkk2$receiverUUID");
  //
  //
  //           // try {
  //             // var receiverUUID = await findDeviceUuid(address);
  //             // String _baseUrl = 'https://political-thoracic-spatula.glitch.me';
  //             print("receiverUUID$receiverUUID");
  //             print("receiverUUID$senderUUID");
  //
  //
  //             // 1. استدعاء API للحصول على المفاتيح
  //             final response = await http.post(
  //               Uri.parse('https://political-thoracic-spatula.glitch.me/api/get-keys'),
  //               headers: {'Content-Type': 'application/json'},
  //               body: jsonEncode({
  //                 'senderUUID': receiverUUID,
  //                 'receiverUUID': senderUUID.toString(),
  //               }),
  //
  //             );
  //           print("dataa${response.statusCode}");
  //             if (response.statusCode == 200) {
  //               final data = jsonDecode(response.body);
  //               print("dataa${data}");
  //               if (data['success'] == true) {
  //                 // 2. تحويل البيانات إلى نموذج KeyInfo
  //                 final keyInfo = KeyInfo.fromJson(data['data']);
  //                 print("dataa${keyInfo.sharedSecret.toString()}");
  //                 final secret = BigInt.parse(keyInfo.sharedSecret.toString());
  //                 // 3. حفظ البيانات في الجدول المحلي
  //                 await dbHelper.storeKeysLocally(
  //                   senderUUID: receiverUUID!,
  //                   senderNUM: keyInfo.senderNUM,
  //                   receiverUUID: senderUUID,
  //                   receiverNUM: keyInfo.receiverNUM,
  //                   sharedSecret: secret,
  //                 );
  //                 final sharedSecret = await dbHelper.getSharedSecret(
  //                   senderUUID: receiverUUID!,
  //                   receiverUUID: senderUUID!,
  //                 );
  //                 if (sharedSecret != null) {
  //                   for (var message in filteredMessages) {
  //                     // try {
  //                       final secret = BigInt.parse(sharedSecret.toString());
  //                       final text = message.content.toString();
  //                       print("dataa ${text}");
  //                       final enc = DiffieHellmanHelper.decryptMessage(text, secret.toString());
  //                       print("dataa ${enc}");
  //                       message.content = enc; // عند نجاح فك التشفير نستخدم النص المفكوك
  //                       // print("dataa ${message.content.toString()}");
  //                     // }
  //                     // catch (e) {
  //                     //   print('فشل في فك تشفير الرسالة: $e');
  //                     //   message.content = "enc"; // عند حدوث خطأ، نعين النص "enc" كما هو
  //                     // }
  //                   }
  //                 }
  //                 // 4. إعادة تحميل الرسائل بعد التخزين
  //                 // return getMessagesForThread(address);
  //               }
  //             }
  //
  //             throw Exception('فشل في الحصول على المفاتيح: ${response.statusCode}');
  //
  //           // } on http.ClientException catch (e) {
  //           //   throw Exception('فشل الاتصال: ${e.message}');
  //           // } on TimeoutException {
  //           //   throw Exception('انتهى وقت الانتظار');
  //           // } catch (e) {
  //           //   throw Exception('خطأ غير متوقع: $e');
  //           // }
  //         }
  //       }
  //       else{
  //         String? receiverUUID = findDeviceUuid(
  //           lastNine) as String?;
  //         print("okkkkkkkkkkkk$receiverUUID");
  //         final dbHelper = DatabaseHelper();
  //         if (receiverUUID != null) {
  //           final dbHelper = DatabaseHelper();
  //           final sharedSecret = await dbHelper.getSharedSecret(
  //             senderUUID: receiverUUID!,
  //             receiverUUID: senderUUID,
  //           );
  //           print("okkkkkkkkkkkk1$sharedSecret");
  //           if (sharedSecret != null) {
  //             print("okkkkkkkkkkkk1");
  //             for (var message in filteredMessages) {
  //               try {
  //                 final secret = BigInt.parse(sharedSecret.toString());
  //                 final text = message.content.toString();
  //                 final enc = DiffieHellmanHelper.decryptMessage(
  //                     text, secret.toString());
  //                 message.content = enc;
  //               } catch (e) {
  //                 print('فشل في فك تشفير الرسالة: $e');
  //               }
  //             }
  //           }
  //
  //         }
  //         else {
  //           print("okkkkkkkkkkkk2");
  //           String? receiverUUID = await findDeviceUuid(address);
  //           print("okkkkkkkkkkkk2$receiverUUID");
  //           final String _baseUrl = 'https://political-thoracic-spatula.glitch.me';
  //
  //           try {
  //             // var receiverUUID = await findDeviceUuid(address);
  //             print("receiverUUID$receiverUUID");
  //
  //
  //             // 1. استدعاء API للحصول على المفاتيح
  //             final response = await http.get(
  //               Uri.parse('$_baseUrl/api/get-keys').replace(queryParameters: {
  //                 'senderUUID': senderUUID,
  //                 'receiverUUID': receiverUUID,
  //               }),
  //               headers: {'Accept': 'application/json'},
  //             ).timeout(const Duration(seconds: 15));
  //
  //             if (response.statusCode == 200) {
  //               final data = jsonDecode(response.body);
  //               if (data['success'] == true) {
  //                 // 2. تحويل البيانات إلى نموذج KeyInfo
  //                 final keyInfo = KeyInfo.fromJson(data['data']);
  //                 final secret = BigInt.parse(
  //                     keyInfo.sharedSecret.toString());
  //                 // 3. حفظ البيانات في الجدول المحلي
  //                 await dbHelper.storeKeysLocally(
  //                   senderUUID: senderUUID!,
  //                   senderNUM: keyInfo.senderNUM,
  //                   receiverUUID: receiverUUID,
  //                   receiverNUM: keyInfo.receiverNUM,
  //                   sharedSecret: secret,
  //                 );
  //                 final sharedSecret = await dbHelper.getSharedSecret(
  //                   senderUUID: receiverUUID!,
  //                   receiverUUID: senderUUID,
  //                 );
  //
  //                 if (sharedSecret != null) {
  //                   for (var message in filteredMessages) {
  //                     try {
  //                       final secret = BigInt.parse(sharedSecret.toString());
  //                       final text = message.content.toString();
  //                       final enc = DiffieHellmanHelper.decryptMessage(
  //                           text, secret.toString());
  //
  //                       message.content = enc;
  //                     } catch (e) {
  //                       print('فشل في فك تشفير الرسالة: $e');
  //                     }
  //                   }
  //                 }
  //                 // 4. إعادة تحميل الرسائل بعد التخزين
  //                 // return getMessagesForThread(address);
  //               }
  //             }
  //
  //             throw Exception(
  //                 'فشل في الحصول على المفاتيح: ${response.statusCode}');
  //           } on http.ClientException catch (e) {
  //             throw Exception('فشل الاتصال: ${e.message}');
  //           } on TimeoutException {
  //             throw Exception('انتهى وقت الانتظار');
  //           } catch (e) {
  //             throw Exception('خطأ غير متوقع: $e');
  //           }
  //         }
  //       }
  //     }
  //
  //     return filteredMessages;
  //   } else {
  //     throw "تم رفض إذن قراءة الرسائل";
  //   }
  // }

  Future<List<Message>> getMessagesForThread(String address) async {
    // التأكد من صلاحية قراءة الرسائل
    if (!await Permission.sms.status.isGranted) {
      throw Exception("تم رفض إذن قراءة الرسائل");
    }
    print("filteredMessages${address}");
    // 1. الحصول على كل الرسائل من الوارد والصادر
    List<Message> allMessages = await _getAllMessages();
    print("filteredMessages");
    // 2. تحديد نوع العنوان: نصي أم رقمي
    bool isTextAddress = RegExp(r'[a-zA-Z]').hasMatch(address);
    print("filteredMessages");
    // 3. تصفية الرسائل بناءً على العنوان
    List<Message> filteredMessages = _filterMessagesByAddress(allMessages, address, isTextAddress);
    print("filteredMessages");
    // 4. في حالة كون العنوان رقمي يتم محاولة فك تشفير الرسائل
    if (!isTextAddress) {
      print("filteredMessages");
      filteredMessages = await _processNumericDecryption(filteredMessages, address);
      print("filteredMessages");
    }
    print("filteredMessages${filteredMessages}");
    return filteredMessages;
  }

  /// دالة لاسترجاع كل الرسائل من صندوق الوارد والصادر وتحويلها إلى نموذج Message
  Future<List<Message>> _getAllMessages() async {
    List<SmsMessage> inbox = await _telephony.getInboxSms();
    List<SmsMessage> sent = await _telephony.getSentSms();

    return [
      ...inbox.map((sms) => _convertSmsToMessage(sms, false)),
      ...sent.map((sms) => _convertSmsToMessage(sms, true)),
    ];
  }

  /// دالة لتصفية الرسائل بناءً على العنوان (نصي أو رقمي)
  List<Message> _filterMessagesByAddress(List<Message> messages, String address, bool isTextAddress) {
    return messages.where((message) {
      if (message.sender == null) return false;

      if (isTextAddress) {
        // مقارنة نصية مباشرة للعناوين النصية
        return message.sender == address;
      } else {
        // مقارنة تعتمد على آخر 9 أرقام للأرقام فقط
        String messageDigits = _getLastNDigits(message.sender!, 9);
        String addressDigits = _getLastNDigits(address, 9);
        return messageDigits == addressDigits;
      }
    }).toList();
  }

  /// دالة لاستخراج آخر [count] من الأرقام من السلسلة المُعطاة
  String _getLastNDigits(String phone, int count) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= count ? cleaned.substring(cleaned.length - count) : cleaned;
  }

  /// دالة لمعالجة فك التشفير للرسائل الخاصة بالعناوين الرقمية
  Future<List<Message>> _processNumericDecryption(List<Message> messages, String address) async {
    // الحصول على senderUUID للجهاز الحالي
    final senderUUID = await getAndPrintUuid();
    final senderNum = await getAndPrintPhoneNumber();
    // استخراج آخر 9 أرقام من العنوان المُدخل
    String lastNine = _getLastNDigits(address, 9);

    final dbHelper = DatabaseHelper();

    // محاولة استرجاع receiverUUID من قاعدة البيانات
    String? receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
      senderNUM: senderNum,
      receiverNUM: lastNine,
    );
    print("filteredMessages1");
    if (receiverUUID == null) {
      // إذا لم يكن موجوداً في قاعدة البيانات، البحث عنه بواسطة دالة findDeviceUuid
      receiverUUID = await findDeviceUuid(lastNine);
      print("filteredMessages11");
    }

    // حال وجود receiverUUID نتابع عملية فك التشفير أو جلب المفاتيح عبر API
    if (receiverUUID != null) {
      print("filteredMessages111${senderUUID['uuid']}");
      print("filteredMessages111$receiverUUID");
      // محاولة الحصول على المفتاح المشترك من قاعدة البيانات
      final sharedSecret = await dbHelper.getSharedSecret(
        senderUUID: senderUUID['uuid'],
        receiverUUID: receiverUUID,
      );

      print("filteredMessages1111");
      print("filteredMessages111111");
      if (sharedSecret != null) {
        print("filteredMessages1111111");
        _decryptMessages(messages, sharedSecret);
        print("filteredMessages11111111");
      } else {
        // إذا لم يكن المفتاح موجودًا محليًا، نحاول جلبه من API ونخزنه محليًا
        final sharedSecret = await _fetchSharedSecretFromApi(senderUUID, receiverUUID, dbHelper);
        print("filteredMessages11111111$sharedSecret");
        if (sharedSecret != null) {
          _decryptMessages(messages, sharedSecret);
        }

      }
    } else {
      // في حالة عدم العثور على receiverUUID بالمنهج الأول،
      // نقوم بمحاولة بحث بديل باستخدام العنوان الأصلي
      receiverUUID = await findDeviceUuid(address);
      if (receiverUUID != null) {
        var sharedSecret = await dbHelper.getSharedSecret(
          senderUUID: receiverUUID,
          receiverUUID: senderUUID,
        );
        if (sharedSecret != null) {
          _decryptMessages(messages, sharedSecret);
        } else {
          // محاولة جلب المفاتيح عبر API باستخدام GET مع مهلة زمنية
          sharedSecret = await _fetchSharedSecretFromApi(senderUUID, receiverUUID, dbHelper);
          if (sharedSecret != null) {
            _decryptMessages(messages, sharedSecret);
          }
        }
      } else {
        print("لم يتم العثور على receiverUUID باستخدام البدائل المتوفرة.");
      }
    }

    return messages;
  }

  /// دالة لفك تشفير الرسائل باستخدام المفتاح المشترك
  void _decryptMessages(List<Message> messages, dynamic sharedSecret) {
    for (var message in messages) {
      try {
        final secretValue = BigInt.parse(sharedSecret.toString());
        final text = message.content.toString();
        final decryptedText = DiffieHellmanHelper.decryptMessage(text, secretValue.toString());
        message.content = decryptedText;
      } catch (e) {
        print('فشل في فك تشفير الرسالة: $e');
      }
    }
  }

  /// دالة لاستدعاء API لجلب المفاتيح وتخزينها محليًا، مع امكانية اختيار GET أو POST
  Future<dynamic> _fetchSharedSecretFromApi(
      String senderUUID,
      String receiverUUID,
      DatabaseHelper dbHelper) async {
    final String baseUrl = 'https://political-thoracic-spatula.glitch.me';
    try {
      http.Response response;

      // المحاولة الأولى: باستخدام payload الأصلية
      response = await http.post(
        Uri.parse('$baseUrl/api/get-keys'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderUUID': receiverUUID,
          'receiverUUID': senderUUID.toString(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // التحقق مما إذا كانت البيانات موجودة وغير فارغة
        if (data['success'] == true &&
            data['data'] != null &&
            data['data'].toString().isNotEmpty) {
          final keyInfo = KeyInfo.fromJson(data['data']);
          final secret = BigInt.parse(keyInfo.sharedSecret.toString());

          // تخزين المفتاح محلياً
          await dbHelper.storeKeysLocally(
            senderUUID: receiverUUID,
            senderNUM: keyInfo.senderNUM,
            receiverUUID: senderUUID,
            receiverNUM: keyInfo.receiverNUM,
            sharedSecret: secret,
          );

          // إعادة المفتاح المخزن من قاعدة البيانات
          return await dbHelper.getSharedSecret(
            senderUUID: receiverUUID,
            receiverUUID: senderUUID,
          );
        } else {
          // إذا كانت البيانات فارغة، نقوم بعكس القيم وإعادة المحاولة
          print("البيانات فارغة، إعادة المحاولة بعكس القيم...");
          response = await http.post(
            Uri.parse('$baseUrl/api/get-keys'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'senderUUID': senderUUID,
              'receiverUUID': receiverUUID,
            }),
          );

          if (response.statusCode == 200) {
            final reversedData = jsonDecode(response.body);
            if (reversedData['success'] == true &&
                reversedData['data'] != null &&
                reversedData['data'].toString().isNotEmpty) {
              final keyInfo = KeyInfo.fromJson(reversedData['data']);
              final secret = BigInt.parse(keyInfo.sharedSecret.toString());
              await dbHelper.storeKeysLocally(
                senderUUID: senderUUID,
                senderNUM: keyInfo.senderNUM,
                receiverUUID: receiverUUID,
                receiverNUM: keyInfo.receiverNUM,
                sharedSecret: secret,
              );
              return await dbHelper.getSharedSecret(
                senderUUID: senderUUID,
                receiverUUID: receiverUUID,
              );
            } else {
              throw Exception(
                  'فشل في الحصول على المفاتيح بعد عكس البيانات: استجابة API غير ناجحة');
            }
          }
          throw Exception(
              'فشل في الحصول على المفاتيح بعد عكس البيانات: ${response.statusCode}');
        }
      }
      throw Exception('فشل في الحصول على المفاتيح: ${response.statusCode}');
    } on http.ClientException catch (e) {
      throw Exception('فشل الاتصال: ${e.message}');
    } on TimeoutException {
      throw Exception('انتهى وقت الانتظار');
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }

  // Future<dynamic> _fetchSharedSecretFromApi(
  //     String senderUUID,
  //     String receiverUUID,
  //     DatabaseHelper dbHelper) async {
  //   final String baseUrl = 'https://political-thoracic-spatula.glitch.me';
  //   try {
  //     http.Response response;
  //     // if (!isGetMethod) {
  //       response = await http.post(
  //         Uri.parse('$baseUrl/api/get-keys'),
  //         headers: {'Content-Type': 'application/json'},
  //         body: jsonEncode({
  //           'senderUUID': receiverUUID,
  //           'receiverUUID': senderUUID.toString(),
  //         }),
  //       );
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //       if (data['success'] == true) {
  //         final keyInfo = KeyInfo.fromJson(data['data']);
  //         final secret = BigInt.parse(keyInfo.sharedSecret.toString());
  //
  //         // تخزين المفتاح مشترك في قاعدة البيانات المحلية
  //         await dbHelper.storeKeysLocally(
  //           senderUUID: receiverUUID,
  //           senderNUM: keyInfo.senderNUM,
  //           receiverUUID: senderUUID,
  //           receiverNUM: keyInfo.receiverNUM,
  //           sharedSecret: secret,
  //         );
  //
  //         // استرجاع المفتاح من قاعدة البيانات بعد التخزين للتأكد من نجاح العملية
  //         return await dbHelper.getSharedSecret(
  //           senderUUID: receiverUUID,
  //           receiverUUID: senderUUID,
  //         );
  //       } else {
  //         throw Exception('فشل في الحصول على المفاتيح: استجابة API غير ناجحة');
  //       }
  //     }
  //     throw Exception('فشل في الحصول على المفاتيح: ${response.statusCode}');
  //   } on http.ClientException catch (e) {
  //     throw Exception('فشل الاتصال: ${e.message}');
  //   } on TimeoutException {
  //     throw Exception('انتهى وقت الانتظار');
  //   } catch (e) {
  //     throw Exception('خطأ غير متوقع: $e');
  //   }
  // }
      // } else {
      //   response = await http
      //       .get(
      //     Uri.parse('$baseUrl/api/get-keys').replace(queryParameters: {
      //       'senderUUID': senderUUID,
      //       'receiverUUID': receiverUUID,
      //     }),
      //     headers: {'Accept': 'application/json'},
      //   )
      //       .timeout(const Duration(seconds: 15));
      // }



  void testEncryption() {
    final secret = BigInt.parse("12180405234572538334142064092397094097325919202980286090984606964261040322933");
    final message = "AAAAAAAAAAAAAAAAAAAAAA==:bAcDG3yR0iRJblNsBWjhxw==";

    final encrypted = DiffieHellmanHelper.encryptMessage(message, secret);
    final decrypted = DiffieHellmanHelper.decryptMessage(encrypted, secret.toString());

    print("Original: $message");
    print("Encrypted: $encrypted");
    print("Decrypted: $decrypted");
  }
  Message _convertSmsToMessage(SmsMessage sms, bool isMe) {
    final body = sms.body ?? "";
    final isEncrypted = body.startsWith('ENC:'); // تحديد بادئة خاصة
    final content = isEncrypted ? body.substring(4) : body;

    return Message(
      sender: sms.address ?? "Unknown",
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0),
      isMe: isMe,
      isEncrypted: isEncrypted,
    );
  }

  Future<void> _insertConversationKey(ConversationKey key) async {
    await _keysDb?.insert(
      'conversation_keys',
      key.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  Future<Map<String, String>?> getKeyPair(String address) async {
    try {
      final keyPair = DiffieHellmanHelper.generateKeyPair();
      final ecPrivate = keyPair.privateKey as ECPrivateKey;
      final ecPublic = keyPair.publicKey as ECPublicKey;

      return {
        'publicKey': '${ecPublic.Q!.x!.toBigInteger()}:${ecPublic.Q!.y!.toBigInteger()}',
        'privateKey': ecPrivate.d!.toString(),
      };
    } catch (e) {
      print('فشل في توليد المفاتيح: $e');
      return null;
    }
  }

  Future<ConversationKey?> getConversationKey(String address) async {
    final keyPair = DiffieHellmanHelper.generateKeyPair();
    final ecPrivate = keyPair.privateKey as ECPrivateKey;
    final ecPublic = keyPair.publicKey as ECPublicKey;

    final ownPrivateKey = ecPrivate.d!.toRadixString(16); // تحويل الخاص إلى HEX
    final ownPublicKey = DiffieHellmanHelper.encodePublicKey(ecPublic);

    print("المفتاح العام المُنشأ: $ownPublicKey");
    print("طول المفتاح العام: ${ownPublicKey.length}"); // يجب أن يكون 130

    final newKey = ConversationKey(
      address: address,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
      theirPublicKey: null,
      sharedSecret: null,
    );

    await _insertConversationKey(newKey);

    // إرسال المفتاح العام بالتنسيق الجديد
    // final exchangedKey = await _keyExchangeService.sendPublicKey(address, ownPublicKey);
    //
    // if (exchangedKey?.theirPublicKey != null) {
    //   final remoteKey = exchangedKey!.theirPublicKey!;
    //
    //   // التحقق من تنسيق المفتاح الوارد
    //   if (!remoteKey.startsWith('04') || remoteKey.length != 130) {
    //     throw FormatException('تنسيق المفتاح العام المستلم غير صالح');
    //   }
    //
    //   // تحليل المفتاح العام
    //   final x = BigInt.parse(remoteKey.substring(2, 66), radix: 16);
    //   final y = BigInt.parse(remoteKey.substring(66, 130), radix: 16);
    //
    //   final publicKeyPoint = DiffieHellmanHelper.params.curve.createPoint(x, y);
    //   final theirPublicKey = ECPublicKey(publicKeyPoint, DiffieHellmanHelper.params);
    //
    //   final sharedSecret = DiffieHellmanHelper.computeSharedSecret(ecPrivate, theirPublicKey);
    //
    //   return newKey.copyWith(
    //     theirPublicKey: remoteKey,
    //     sharedSecret: sharedSecret.toString(),
    //   );
    // }

    return newKey;
  }

  // Future<void> sendSMS(String message, List<String> recipients) async {
  //   try {
  //     if (await Permission.sms.request().isGranted) {
  //       for (String recipient in recipients) {
  //         String finalMessage = message;
  //
  //         ConversationKey? key = await getConversationKey(recipient);
  //         if (key != null && key.sharedSecret != null) {
  //           finalMessage = DiffieHellmanHelper.encryptMessage(message, key.sharedSecret!);
  //           print("الرسالة المشفرة: $finalMessage");
  //         } else {
  //           print("⚠️ لم يتم تبادل المفاتيح بعد، سيتم إرسال الرسالة بدون تشفير.");
  //         }
  //
  //         await _telephony.sendSms(
  //           to: recipient,
  //           message: finalMessage,
  //         );
  //
  //         Message localMessage = Message(
  //           sender: recipient,
  //           content: message,
  //           timestamp: DateTime.now(),
  //           isMe: true,
  //           isEncrypted: key != null && key.sharedSecret != null,
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

    // ConversationKey? exchangedKey = await _keyExchangeService.sendPublicKey(recipient, ownPublicKey);
    // if (exchangedKey != null &&
    //     exchangedKey.theirPublicKey != null &&
    //     exchangedKey.sharedSecret != null) {
    //   final parts = exchangedKey.theirPublicKey!.split(':');
    //   final BigInt x = BigInt.parse(parts[0]);
    //   final BigInt y = BigInt.parse(parts[1]);
    //   final point = DiffieHellmanHelper.params.curve.createPoint(x, y);
    //   final theirPublicKeyConverted = ECPublicKey(point, DiffieHellmanHelper.params);
    //
    //   final sharedSecret = DiffieHellmanHelper.computeSharedSecret(ecPrivate, theirPublicKeyConverted);
    //   print("🔒 المفتاح المشترك المحسوب: ${sharedSecret.toString()}");
    //
    //   ConversationKey updatedKey = newKey.copyWith(
    //     theirPublicKey: exchangedKey.theirPublicKey,
    //     sharedSecret: sharedSecret.toString(),
    //   );
    //   await _insertConversationKey(updatedKey);
    //   print("✅ تم تبادل المفاتيح عبر الإنترنت مع $recipient");
    //   // print("📌 المفتاح العام للطرف الآخر: ${exchangedKey.theirPublicKey}");
    //   print("🔒 المفتاح المشترك: ${sharedSecret.toString()}");
    // } else {
    //   print("⚠️ لم يتم تبادل المفاتيح عبر الإنترنت بعد.");
    // }
  }
  String normalizePhoneNumber(String phoneNumber) {
    if (RegExp(r'[^0-9+]').hasMatch(phoneNumber)) {
      return phoneNumber;
    }

    // إذا كان النص رقمًا، قم بتطبيعه
    String normalized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    if (normalized.startsWith('+')) {
      return normalized.length >= 9
          ? normalized.substring(normalized.length - 9)
          : normalized;
    }

    if (normalized.length >= 9) {
      return normalized.substring(normalized.length - 9);
    }

    return normalized;
  }



  Map<String, List<SmsMessage>> _cachedConversations = {};

  Future<Map<String, List<SmsMessage>>> getConversations({bool forceRefresh = false}) async {
    if (!await Permission.sms.request().isGranted) {
      throw "تم رفض إذن قراءة الرسائل";
    }

    if (forceRefresh || _cachedConversations.isEmpty) {
      final List<SmsMessage> inbox = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.READ],
      );
      final List<SmsMessage> sent = await _telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );

      Map<String, List<SmsMessage>> groupedMessages = {};

      // دالة معالجة الرسائل المشفرة
      Future<void> processEncryptedMessages(String address, List<SmsMessage> messages) async {
        final isNumericAddress = !RegExp(r'[a-zA-Z]').hasMatch(address);

        if (isNumericAddress) {
          final senderUUID = await getAndPrintUuid();
          final dbHelper = DatabaseHelper();

          final receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
            senderNUM: senderUUID['phone_num'],
            receiverNUM: address,
          );
          if(receiverUUID == null){
            final receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
              senderNUM: address ,
              receiverNUM: senderUUID['phone_num'],
            );
            if (receiverUUID != null) {
              print("receiverUUID");
              final sharedSecret = await dbHelper.getSharedSecret(
                senderUUID: senderUUID['uuid']!,
                receiverUUID: receiverUUID,
              );
              if (sharedSecret == null) {
                final sharedSecret = await dbHelper.getSharedSecret(
                  senderUUID: receiverUUID!,
                  receiverUUID:senderUUID['uuid'] ,
                );
              if (sharedSecret != null) {
                for (var message in messages) {
                  try {
                    final secret = BigInt.parse(sharedSecret.toString());
                    final decrypted = DiffieHellmanHelper.decryptMessage(
                        message.body ?? "",
                        secret.toString()
                    );
                    message.body = decrypted;
                  } catch (e) {
                    print('فشل فك تشفير الرسالة: $e');
                  }
                }
              }
              }

            }
          }


        }
      }

      void groupMessages(SmsMessage message) {
        String? rawAddress = message.address;
        if (rawAddress == null) return;

        final isTextAddress = RegExp(r'[a-zA-Z]').hasMatch(rawAddress);
        final normalizedAddress = isTextAddress
            ? rawAddress
            : normalizePhoneNumber(rawAddress);

        groupedMessages.putIfAbsent(normalizedAddress, () => []);
        groupedMessages[normalizedAddress]!.add(message);
      }

      // تجميع الرسائل
      for (var message in [...inbox, ...sent]) {
        groupMessages(message);
      }

      // فك تشفير الرسائل لكل محادثة
      await Future.wait(
          groupedMessages.entries.map((entry) async {
            await processEncryptedMessages(entry.key, entry.value);
          })
      );

      _cachedConversations = groupedMessages;
    }

    return _cachedConversations..removeWhere((key, value) => value.isEmpty);
  }

}