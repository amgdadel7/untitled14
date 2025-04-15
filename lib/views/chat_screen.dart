import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointycastle/ecc/api.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import 'package:telephony/telephony.dart';
import 'package:untitled14/controllers/registration_controller.dart';
import 'package:untitled14/controllers/store_key_controler.dart';
import 'package:untitled14/utils/encryption.dart';
import '../controllers/message_controller.dart';
import '../models/message_model.dart';
import 'package:http/http.dart' as http;
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class GoogleMessagesColors {
  static const primary = Color(0xFF00897B);      // Teal 600
  static const primaryDark = Color(0xFF00796B);    // Teal 700
  static const accent = Color(0xFF80CBC4);         // Teal 200
  static const background = Color(0xFFEEEEEE);     // Grey 200
  static const sentMessage = Color(0xFFDCF8C6);      // Light Green
  static const receivedMessage = Colors.white;
  static const textDark = Color(0xFF212121);         // Grey 900
  static const textLight = Color(0xFF757575);        // Grey 600
  static const timeStamp = Color(0xFF9E9E9E);        // Grey 500
  static const appBar = Colors.white;
  static const divider = Color(0xFFE0E0E0);          // Grey 300
  static const unreadIndicator = Color(0xFF4CAF50);    // Green 500
}

/// دالة تستدعي عند استقبال رسالة في الخلفية
onBackgroundMessage(SmsMessage message) {
  debugPrint("onBackgroundMessage called");
}

class ChatScreen extends StatefulWidget {
  final String address;
  final String recipient;
  final String? recipientImageUrl;
  final String? searchQuery; // إضافة معلمة جديدة

  const ChatScreen({
    Key? key,
    required this.address,
    required this.recipient,
    this.recipientImageUrl,
    this.searchQuery, // تهيئة المعلمة
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MessageController mess = MessageController();
  List<Message> _messages = [];
  String _message = "";
  final telephony = Telephony.instance;
  bool _isSelectionMode = false;
  Set<int> _selectedMessageIndices = {};
  // متغيرات البحث
  bool _isSearchMode = false;
  String _searchQuery = '';
  List<int> _searchResults = [];
  int _currentSearchIndex = -1;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  bool _loadingMessages = true;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    initPlatformState();
    // تهيئة قاعدة البيانات عند تحميل الواجهة
    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      final messageController = Provider.of<MessageController>(context, listen: false);
      await messageController.initDatabases(); // تهيئة قاعدة البيانات
      messageController.printMessages();
      messageController.printConversationKeys();
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        _isSearchMode = true;
        _searchController.text = widget.searchQuery!;
      }
    });

    // إذا كانت القائمة جاهزة لنقل المؤشر إلى آخر الرسائل.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  onBackgroundMessage(SmsMessage message) {
    debugPrint("onBackgroundMessage called");
  }

  String _senderNumber = ""; // متغير لحفظ رقم المرسل

  onMessage(SmsMessage message) async {
    setState(() {
      _senderNumber = message.address ?? "Unknown";
      _message = message.body ?? "";
      print("🚀 تم استلام رسالة من $_senderNumber: $_message");
      _loadMessages();
      mess.processIncomingSms(message);
    });
  }

  void _performSearch(String query) {
    final lowerQuery = query.toLowerCase();
    List<int> results = [];
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].content.toLowerCase().contains(lowerQuery)) {
        results.add(i);
      }
    }
    setState(() {
      _searchQuery = query;
      _searchResults = results;
      _currentSearchIndex = results.isNotEmpty ? 0 : -1;
    });
    if (results.isNotEmpty) {
      _jumpToResult(_currentSearchIndex);
    }
  }

  void _jumpToResult(int index) {
    if (index >= 0 && index < _searchResults.length) {
      setState(() => _currentSearchIndex = index);
      final messageIndex = _searchResults[index];
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent *
                (messageIndex / _messages.length),
          );
        }
      });
    }
  }

  void _jumpToPreviousResult() {
    if (_currentSearchIndex > 0) {
      _jumpToResult(_currentSearchIndex - 1);
    }
  }

  void _jumpToNextResult() {
    if (_currentSearchIndex < _searchResults.length - 1) {
      _jumpToResult(_currentSearchIndex + 1);
    }
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _searchQuery = '';
        _searchResults.clear();
        _currentSearchIndex = -1;
      }
    });
  }

  /// طلب صلاحيات الهاتف والرسائل والاستماع للرسائل الواردة
  Future<void> initPlatformState() async {
    bool? result = await telephony.requestPhoneAndSmsPermissions;
    if (result != null && result) {
      telephony.listenIncomingSms(
        onNewMessage: onMessage,
        onBackgroundMessage: onBackgroundMessage,
        listenInBackground: true, // تمكين الاستماع في الخلفية
      );
    }

    if (!mounted) return;
  }

  Future<void> _loadMessages() async {
    final messageController = Provider.of<MessageController>(context, listen: false);
    List<Message> msgs = await messageController.getMessagesForThread(widget.address);
    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    setState(() {
      _messages = msgs;
      _loadingMessages = false;
    });
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
      // تفعيل البحث إذا كان هناك استعلام
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        _isSearchMode = true;
        _searchQuery = widget.searchQuery!;
        _searchController.text = _searchQuery;
        _performSearch(_searchQuery);
      }
    });
  }

  /// تفعيل وضع التحديد عند الضغط المطول على رسالة
  void _onLongPressMessage(int index) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIndices.add(index);
    });
  }

  /// عند النقر على الرسالة في وضع التحديد، يتم تبديل اختيارها
  void _onTapMessage(int index) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedMessageIndices.contains(index)) {
          _selectedMessageIndices.remove(index);
          if (_selectedMessageIndices.isEmpty) {
            _isSelectionMode = false;
          }
        } else {
          _selectedMessageIndices.add(index);
        }
      });
    }
  }

  /// دالة لنسخ الرسائل المحددة
  void _copySelectedMessages() {
    String copiedText = _selectedMessageIndices
        .map((index) => _messages[index].content)
        .join("\n");
    Clipboard.setData(ClipboardData(text: copiedText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم نسخ الرسائل")),
    );
    _exitSelectionMode();
  }

  /// دالة لحذف الرسائل المحددة
  void _deleteSelectedMessages() {
    setState(() {
      // حذف الرسائل من القائمة المحلية (يمكن تعديلها لحذفها من قاعدة البيانات أيضاً)
      List<int> indices = _selectedMessageIndices.toList()..sort((a, b) => b.compareTo(a));
      for (var index in indices) {
        _messages.removeAt(index);
      }
      _exitSelectionMode();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم حذف الرسائل")),
    );
  }

  /// الخروج من وضع التحديد
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIndices.clear();
    });
  }

  Future<String?> findDeviceUuid(String searchValue) async {
    try {
      final response = await http.post(
        Uri.parse('https://political-thoracic-spatula.glitch.me/api/find-device'),
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

  Future<dynamic> getAndPrintUuid() async {
    // الحصول على معلومات الجهاز المحفوظة محليًا
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

  String getLastNineDigits(String address) {
    // إزالة أي مسافات أو أحرف غير رقمية إن لزم الأمر
    String digits = address.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }

  // Future<void> _sendMessage() async {
  //   final messageController = Provider.of<MessageController>(context, listen: false);
  //   final text = _messageController.text.trim();
  //   if (text.isEmpty) return;
  //
  //   try {
  //     String address = widget.address;
  //     String lastNine = getLastNineDigits(address);
  //
  //     // الحصول على معرّفات الأجهزة
  //     final senderUUID1 = await getAndPrintUuid();
  //     if (senderUUID1 == null || senderUUID1['uuid'] == null || senderUUID1['phone_num'] == null) {
  //       throw Exception('فشل في استرجاع UUID أو رقم الهاتف');
  //     }
  //     String senderUUID = senderUUID1['uuid']!;
  //     String senderNUM = senderUUID1['phone_num']!;
  //     String? receiverUUID = "";
  //     final getreceiveruuid = DatabaseHelper();
  //     receiverUUID = await getreceiveruuid.queryreceiverUUID(
  //       senderUUID: senderUUID,
  //       receiverNUM: lastNine,
  //     );
  //     if (receiverUUID == null) {
  //       // البحث مرة أخرى بطريقة بديلة
  //       receiverUUID = await findDeviceUuid(lastNine);
  //
  //       if (receiverUUID == null) {
  //         throw Exception('فشل العثور على UUID بعد البحث');
  //       }
  //     }
  //
  //     final getkeyexsist = DatabaseHelper();
  //     final db = await getkeyexsist.database;
  //     await getkeyexsist.onCreate(db, 2);
  //     print("asawwwaddd$lastNine");
  //     String? key = await getkeyexsist.queryKeysLocally(
  //       senderUUID: senderUUID,
  //       receiverNUM: lastNine,
  //     );
  //     print("keyskeys$key");
  //     if (key == null || key.isEmpty) {
  //       final keys = await messageController.getConversationKey(widget.address);
  //       if (keys == null || keys.ownPublicKey.isEmpty || keys.ownPrivateKey.isEmpty) {
  //         throw Exception('فشل في توليد مفاتيح التشفير');
  //       }
  //
  //       // تسجيل بيانات تبادل المفاتيح مع الخادم
  //       print('إرسال بيانات تبادل المفاتيح:');
  //       print('senderPublicKey: ${keys.ownPublicKey}');
  //       print('senderUUID: $senderUUID');
  //       print('receiverUUID: $receiverUUID');
  //
  //       final keyExchangeResponse = await http.post(
  //         Uri.parse('https://political-thoracic-spatula.glitch.me/api/exchange-keys'),
  //         headers: {'Content-Type': 'application/json'},
  //         body: jsonEncode({
  //           'senderUUID': senderUUID,
  //           'receiverUUID': receiverUUID,
  //           'senderPublicKey': keys.ownPublicKey,
  //           'targetPhone': widget.address,
  //         }),
  //       ).timeout(const Duration(seconds: 10));
  //
  //       if (keyExchangeResponse.statusCode != 200) {
  //         print('فشل تبادل المفاتيح. رمز الحالة: ${keyExchangeResponse.statusCode}');
  //         print('رد الخادم: ${keyExchangeResponse.body}');
  //         throw Exception('فشل تبادل المفاتيح مع الخادم');
  //       }
  //
  //       final exchangeData = jsonDecode(keyExchangeResponse.body);
  //       if (exchangeData['targetPublicKey'] == null) {
  //         throw Exception('لم يتم استلام المفتاح العام من الخادم');
  //       }
  //
  //       // توليد زوج المفاتيح
  //       final keyPair = DiffieHellmanHelper.generateKeyPair();
  //       final myPrivateKey = keyPair.privateKey as ECPrivateKey;
  //       final peerPublicKey = keyPair.publicKey as ECPublicKey;
  //
  //       // حساب السر المشترك باستخدام المفاتيح المناسبة
  //       final sharedSecret = DiffieHellmanHelper.computeSharedSecret(myPrivateKey, peerPublicKey);
  //       final dbHelper = DatabaseHelper();
  //       await dbHelper.storeKeysLocally(
  //         senderUUID: senderUUID,
  //         senderNUM: senderNUM,
  //         receiverUUID: receiverUUID,
  //         receiverNUM: lastNine,
  //         sharedSecret: sharedSecret,
  //       );
  //
  //       final storeResponse = await http.post(
  //         Uri.parse('https://political-thoracic-spatula.glitch.me/api/store-keys'),
  //         headers: {'Content-Type': 'application/json'},
  //         body: jsonEncode({
  //           'senderUUID': senderUUID,
  //           'senderNUM' : senderNUM,
  //           'receiverUUID': receiverUUID,
  //           'receiverNUM':lastNine,
  //           'sharedSecret': sharedSecret.toString()
  //         }),
  //       ).timeout(const Duration(seconds: 10));
  //
  //       if (storeResponse.statusCode != 200) {
  //         print('فشل حفظ المفاتيح. رمز الحالة: ${storeResponse.statusCode}');
  //         print('رد الخادم: ${storeResponse.body}');
  //         throw Exception('فشل تبادل المفاتيح مع الخادم');
  //       }
  //
  //       final storeData = jsonDecode(storeResponse.body);
  //       if (storeData['success'] != true) {
  //         throw Exception('لم يتم استلام المفتاح العام من الخادم');
  //       }
  //
  //       final secret = BigInt.parse(sharedSecret.toString());
  //       print("encryptedMessage$secret");
  //       // تشفير الرسالة باستخدام المفتاح المشترك
  //       final encryptedMessage = DiffieHellmanHelper.encryptMessage(text, secret);
  //       print("Decrypted: $secret");
  //
  //       // إرسال الرسالة المشفرة عبر SMS وتخزين النص الأصلي محلياً
  //       await messageController.sendEncryptedMessage(encryptedMessage, text, widget.address);
  //       Message newMessage = Message(
  //         sender: widget.address,
  //         content: text,
  //         timestamp: DateTime.now(),
  //         isMe: true,
  //         isEncrypted: true,
  //       );
  //
  //       setState(() {
  //         _messages.add(newMessage);
  //         _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  //       });
  //
  //       _messageController.clear();
  //       _loadMessages();
  //
  //       WidgetsBinding.instance?.addPostFrameCallback((_) {
  //         if (_scrollController.hasClients) {
  //           _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  //         }
  //       });
  //     } else {
  //       print("secret key is: $key");
  //       final secret = BigInt.parse(key.toString());
  //       print("encryptedMessage$secret");
  //       final encryptedMessage = DiffieHellmanHelper.encryptMessage(text, secret);
  //       await messageController.sendEncryptedMessage(encryptedMessage, text, widget.address);
  //
  //       Message newMessage = Message(
  //         sender: widget.address,
  //         content: text,
  //         timestamp: DateTime.now(),
  //         isMe: true,
  //         isEncrypted: true,
  //       );
  //
  //       setState(() {
  //         _messages.add(newMessage);
  //         _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  //       });
  //
  //       _messageController.clear();
  //
  //       WidgetsBinding.instance?.addPostFrameCallback((_) {
  //         if (_scrollController.hasClients) {
  //           _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  //         }
  //       });
  //     }
  //   } catch (e) {
  //     print('خطأ غير متوقع: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('حدث خطأ أثناء إرسال الرسالة: ${e.toString()}')),
  //     );
  //   }
  // }
  // Future<void> _sendMessage() async {
  //   final messageController = Provider.of<MessageController>(context, listen: false);
  //   final text = _messageController.text.trim();
  //   if (text.isEmpty) return;
  //
  //   try {
  //     final address = widget.address;
  //     final lastNine = getLastNineDigits(address);
  //
  //     // الحصول على معرّفات الجهاز: senderUUID, senderNUM, receiverUUID
  //
  //     final deviceIds = await _getDeviceIds(lastNine);
  //     final senderUUID = deviceIds['senderUUID']!;
  //     final senderNUM = deviceIds['senderNUM']!;
  //     final receiverUUID = deviceIds['receiverUUID']!;
  //
  //     // تجهيز مفتاح التشفير (shared secret)
  //     final secret = await _prepareSharedKey(senderUUID, senderNUM, receiverUUID, lastNine);
  //
  //     // تشفير الرسالة باستخدام المفتاح المشترك وإرسالها
  //     await _processAndSendMessage(
  //       text,
  //       secret,
  //       messageController,
  //       widget.address,
  //     );
  //
  //     // تحديث واجهة المستخدم (إضافة الرسالة الجديدة إلى القائمة وتحديث الـ scroll)
  //     _updateUIWithNewMessage(widget.address, text);
  //
  //     _messageController.clear();
  //     _scrollToBottom();
  //     await _loadMessages();
  //   } catch (e) {
  //     print('خطأ غير متوقع: $e');
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(content: Text('حدث خطأ أثناء إرسال الرسالة: ${e.toString()}')),
  //     );
  //   }
  // }

  /// دالة للحصول على معرّفات الجهاز (sender و receiver)
  // Future<Map<String, String>> _getDeviceIds(String lastNine) async {
  //   // الحصول على معرّف الجهاز ورقم الهاتف الخاص بالمرسل
  //   final senderData = await getAndPrintUuid();
  //   if (senderData == null ||
  //       senderData['uuid'] == null ||
  //       senderData['phone_num'] == null) {
  //     throw Exception('فشل في استرجاع UUID أو رقم الهاتف');
  //   }
  //   final senderUUID = senderData['uuid']!;
  //   final senderNUM = senderData['phone_num']!;
  //
  //   final dbHelper = DatabaseHelper();
  //
  //   // استدعاء دالة الاستعلام
  //   var receiverData = await dbHelper.queryreceiverUUID_by_serderUUID(
  //     senderNUM: senderNUM,
  //     receiverNUM: lastNine,
  //   );
  //
  //   String? receiverUUID;
  //   // إذا كانت النتيجة Map نتحقق ونستخرج القيمة، وإذا كانت String فنستخدمها مباشرة
  //   if (receiverData != null) {
  //     if (receiverData is Map) {
  //       receiverUUID = receiverData;
  //     } else if (receiverData is String) {
  //       receiverUUID = receiverData;
  //     }
  //   }
  //
  //   // إذا لم نحصل على البيانات من أول استعلام نحاول معايير بديلة
  //   if (receiverUUID == null) {
  //     var altReceiverData = await dbHelper.queryreceiverUUID_by_serderUUID(
  //       senderNUM: lastNine,
  //       receiverNUM: senderNUM,
  //     );
  //     if (altReceiverData != null) {
  //       if (altReceiverData is Map) {
  //         receiverUUID = altReceiverData;
  //       } else if (altReceiverData is String) {
  //         receiverUUID = altReceiverData;
  //       }
  //     }
  //     // محاولة البحث بطريقة بديلة إذا ظل المتغير فارغاً
  //     if (receiverUUID == null) {
  //       var alternative = await findDeviceUuid(lastNine);
  //       if (alternative != null) {
  //         // إذا كانت النتيجة Map نقوم باستخراج المفتاح "uuid" إن وجد
  //         if (alternative is Map) {
  //           receiverUUID = alternative;
  //         } else if (alternative is String) {
  //           receiverUUID = alternative;
  //         }
  //       }
  //     }
  //     if (receiverUUID == null) {
  //       throw Exception('فشل العثور على UUID بعد البحث');
  //     }
  //     // في حالة عدم وجود البيانات باستخدام الاستعلام الأصلي نعتبرها معكوسة:
  //     return {
  //       'senderUUID': receiverUUID, // هنا نعتبر القيمة المُستخرجة معكوسة
  //       'senderNUM': senderNUM,
  //       'receiverUUID': senderUUID,
  //     };
  //   }
  //
  //   return {
  //     'senderUUID': senderUUID,
  //     'senderNUM': senderNUM,
  //     'receiverUUID': receiverUUID,
  //   };
  // }
//   Future<Map<String, String>> _getDeviceIds(String lastNine) async {
//     final senderData = await getAndPrintUuid();
//     final senderUUID = senderData?['uuid']?.toString();
//     final senderNUM = senderData?['phone_num']?.toString();
//
//     if (senderUUID == null || senderNUM == null) {
//       throw Exception('فشل في استرجاع بيانات المرسل');
//     }
// print("okkkkkkkkkkkkkkkk")
//     final dbHelper = DatabaseHelper();
//
//     // البحث الأساسي
//     String? receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
//       senderNUM: senderNUM,
//       receiverNUM: lastNine,
//     );
//
//     // البحث الثانوي إذا لم يتم العثور
//     if (receiverUUID == null) {
//       receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
//         senderNUM: lastNine,
//         receiverNUM: senderNUM,
//       );
//     }
//
//     // البحث البديل
//     if (receiverUUID == null) {
//       receiverUUID = await findDeviceUuid(lastNine);
//     }
//
//     if (receiverUUID == null) {
//       throw Exception('فشل العثور على UUID المستقبل');
//     }
//
//     return {
//       'senderUUID': senderUUID,
//       'senderNUM': senderNUM,
//       'receiverUUID': receiverUUID,
//     };
//   }
//
//
//
//   /// دالة لإعداد مفتاح التشفير (المفتاح المشترك) سواء عبر الاستعلام المحلي أو عبر تبادل المفاتيح مع الخادم
//   Future<BigInt> _prepareSharedKey(
//       String senderUUID,
//       String senderNUM,
//       String receiverUUID,
//       String lastNine,
//       ) async {
//     final dbHelper = DatabaseHelper();
//
//     // محاولة الحصول على المفتاح المشترك محلياً
//     String? key = await dbHelper.queryKeysLocally(
//       senderUUID: senderUUID,
//       receiverNUM: lastNine,
//     );
//
//     // في حالة عدم وجود المفتاح، نقوم بتبادل المفاتيح مع الخادم وإنشاء الزوج اللازم
//     if (key == null || key.isEmpty) {
//       String? key = await dbHelper.queryKeysLocally1(
//         senderNUM: lastNine ,
//         receiverNUM: senderNUM,
//       );
//       if (key == null || key.isEmpty) {
//         final messageController =
//         Provider.of<MessageController>(context, listen: false);
//         final keys = await messageController.getConversationKey(widget.address);
//         if (keys == null ||
//             keys.ownPublicKey.isEmpty ||
//             keys.ownPrivateKey.isEmpty) {
//           throw Exception('فشل في توليد مفاتيح التشفير');
//         }
//
//         // تبادل المفاتيح مع الخادم
//         await _exchangeKeysWithServer(senderUUID, receiverUUID, keys, widget.address);
//
//         // توليد زوج المفاتيح وحساب السر المشترك
//         final keyPair = DiffieHellmanHelper.generateKeyPair();
//         final myPrivateKey = keyPair.privateKey as ECPrivateKey;
//         final peerPublicKey = keyPair.publicKey as ECPublicKey;
//         final sharedSecret = DiffieHellmanHelper.computeSharedSecret(myPrivateKey, peerPublicKey);
//
//         // تخزين المفتاح محلياً وفي الخادم
//         await dbHelper.storeKeysLocally(
//           senderUUID: senderUUID,
//           senderNUM: senderNUM,
//           receiverUUID: receiverUUID,
//           receiverNUM: lastNine,
//           sharedSecret: sharedSecret,
//         );
//         await _storeKeysToServer(senderUUID, senderNUM, receiverUUID, lastNine, sharedSecret);
//
//         return BigInt.parse(sharedSecret.toString());
//       }
//       else{
//         return BigInt.parse(key);
//       }
//     } else {
//       // إذا كان المفتاح موجوداً محلياً، نقوم باستخدامه
//       return BigInt.parse(key);
//     }
//   }
//
//   /// دالة لتبادل المفاتيح مع الخادم والحصول على المفتاح العام الخاص بالجهة المستلمة
//   Future<void> _exchangeKeysWithServer(
//       String senderUUID,
//       String receiverUUID,
//       dynamic keys,
//       String targetPhone,
//       ) async {
//     final response = await http.post(
//       Uri.parse('https://political-thoracic-spatula.glitch.me/api/exchange-keys'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'senderUUID': senderUUID,
//         'receiverUUID': receiverUUID,
//         'senderPublicKey': keys.ownPublicKey,
//         'targetPhone': targetPhone,
//       }),
//     ).timeout(const Duration(seconds: 10));
//
//     if (response.statusCode != 200) {
//       print('فشل تبادل المفاتيح. رمز الحالة: ${response.statusCode}');
//       print('رد الخادم: ${response.body}');
//       throw Exception('فشل تبادل المفاتيح مع الخادم');
//     }
//
//     final exchangeData = jsonDecode(response.body);
//     if (exchangeData['targetPublicKey'] == null) {
//       throw Exception('لم يتم استلام المفتاح العام من الخادم');
//     }
//   }
//
//   /// دالة لتخزين المفاتيح على الخادم
//   Future<void> _storeKeysToServer(
//       String senderUUID,
//       String senderNUM,
//       String receiverUUID,
//       String receiverNUM,
//       dynamic sharedSecret,
//       ) async {
//     final storeResponse = await http.post(
//       Uri.parse('https://political-thoracic-spatula.glitch.me/api/store-keys'),
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({
//         'senderUUID': senderUUID,
//         'senderNUM': senderNUM,
//         'receiverUUID': receiverUUID,
//         'receiverNUM': receiverNUM,
//         'sharedSecret': sharedSecret.toString()
//       }),
//     ).timeout(const Duration(seconds: 10));
//
//     if (storeResponse.statusCode != 200) {
//       print('فشل حفظ المفاتيح. رمز الحالة: ${storeResponse.statusCode}');
//       print('رد الخادم: ${storeResponse.body}');
//       throw Exception('فشل تبادل المفاتيح مع الخادم');
//     }
//
//     final storeData = jsonDecode(storeResponse.body);
//     if (storeData['success'] != true) {
//       throw Exception('فشل في تخزين المفاتيح على الخادم');
//     }
//   }
//
//   /// دالة لتشفير الرسالة وإرسالها عبر SMS وتسجيلها
//   Future<void> _processAndSendMessage(
//       String plainText,
//       BigInt secret,
//       MessageController messageController,
//       String address,
//       ) async {
//     final encryptedMessage = DiffieHellmanHelper.encryptMessage(plainText, secret);
//     await messageController.sendEncryptedMessage(encryptedMessage, plainText, address);
//   }
//
//   /// دالة لتحديث واجهة المستخدم بإضافة الرسالة الجديدة
//   void _updateUIWithNewMessage(String address, String content) {
//     Message newMessage = Message(
//       sender: address,
//       content: content,
//       timestamp: DateTime.now(),
//       isMe: true,
//       isEncrypted: true,
//     );
//     setState(() {
//       _messages.add(newMessage);
//       _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
//     });
//   }
//
//   /// دالة لتحريك الـ Scroll إلى نهاية القائمة
//   void _scrollToBottom() {
//     WidgetsBinding.instance?.addPostFrameCallback((_) {
//       if (_scrollController.hasClients) {
//         _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
//       }
//     });
//   }
  Future<void> _sendMessage() async {
    final messageController = Provider.of<MessageController>(context, listen: false);
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final address = widget.address;
      final lastNine = getLastNineDigits(address);

      // الحصول على معرّفات الجهاز: senderUUID, senderNUM, receiverUUID
      final deviceIds = await _getDeviceIds(lastNine);
      final senderUUID = deviceIds['senderUUID']!;
      final senderNUM = deviceIds['senderNUM']!;
      final receiverUUID = deviceIds['receiverUUID']!;

      // تجهيز مفتاح التشفير (shared secret)
      // final secret = await _prepareSharedKey(senderUUID, senderNUM, receiverUUID, lastNine);
      final secret = await _prepareSharedKey(deviceIds['senderUUID']!, deviceIds['senderNUM']!, deviceIds['receiverUUID']!, lastNine);

      // تشفير الرسالة باستخدام المفتاح المشترك وإرسالها
      await _processAndSendMessage(
        text,
        secret,
        messageController,
        widget.address,
      );

      // تحديث واجهة المستخدم (إضافة الرسالة الجديدة إلى القائمة وتحديث الـ scroll)
      _updateUIWithNewMessage(widget.address, text);

      _messageController.clear();
      // _loadMessages();
      _scrollToBottom();
    } catch (e) {
      print('خطأ غير متوقع: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إرسال الرسالة: ${e.toString()}')),
      );
    }
  }

  /// دالة للحصول على معرّفات الجهاز (sender و receiver)
  Future<Map<String, String>> _getDeviceIds(String lastNine) async {
    // الحصول على معرّف الجهاز ورقم الهاتف الخاص بالمرسل
    final senderData = await getAndPrintUuid();
    if (senderData == null ||
        senderData['uuid'] == null ||
        senderData['phone_num'] == null) {
      throw Exception('فشل في استرجاع UUID أو رقم الهاتف');
    }
    // final senderUUID = senderData['uuid']!;
    // final senderNUM = senderData['phone_num']!;

    // البحث عن receiverUUID في قاعدة البيانات
    final dbHelper = DatabaseHelper();
    // String? receiverUUID = await dbHelper.queryreceiverUUID(
    //   senderUUID: senderData['uuid'],
    //   receiverNUM: lastNine,
    // );
    String? receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
      senderNUM: senderData['phone_num']!,
      receiverNUM: lastNine,
    );
    if (receiverUUID == null) {
      // محاولة البحث بطريقة بديلة
      receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
        senderNUM: lastNine,
        receiverNUM: senderData['phone_num']!,
      );

    }
    if (receiverUUID == null) {
      // محاولة البحث بطريقة بديلة
      receiverUUID = await findDeviceUuid(lastNine);
      if (receiverUUID == null) {
        throw Exception('فشل العثور على UUID بعد البحث');
      }
    }
    return {
      'senderUUID': senderData['uuid'],
      'senderNUM': senderData['phone_num'],
      'receiverUUID': receiverUUID,
    };
  }

  /// دالة لإعداد مفتاح التشفير (المفتاح المشترك) سواء عبر الاستعلام المحلي أو عبر تبادل المفاتيح مع الخادم
  Future<BigInt> _prepareSharedKey(
      String senderUUID,
      String senderNUM,
      String receiverUUID,
      String lastNine,
      ) async {
    final dbHelper = DatabaseHelper();

    // محاولة الحصول على المفتاح المشترك محلياً
    String? key = await dbHelper.queryKeysLocally(
      senderUUID: senderUUID,
      receiverNUM: lastNine,
    );

    // في حالة عدم وجود المفتاح، نقوم بتبادل المفاتيح مع الخادم وإنشاء الزوج اللازم
    if (key == null || key.isEmpty) {
      key = await dbHelper.queryKeysLocally1(
        senderNUM:lastNine,
        receiverNUM: senderNUM,
      );
    }
    if (key == null || key.isEmpty) {
        final messageController =
        Provider.of<MessageController>(context, listen: false);
        final keys = await messageController.getConversationKey(widget.address);
        if (keys == null ||
            keys.ownPublicKey.isEmpty ||
            keys.ownPrivateKey.isEmpty) {
          throw Exception('فشل في توليد مفاتيح التشفير');
        }

        // تبادل المفاتيح مع الخادم
        await _exchangeKeysWithServer(senderUUID, receiverUUID, keys, widget.address);

        // توليد زوج المفاتيح وحساب السر المشترك
        final keyPair = DiffieHellmanHelper.generateKeyPair();
        final myPrivateKey = keyPair.privateKey as ECPrivateKey;
        final peerPublicKey = keyPair.publicKey as ECPublicKey;
        final sharedSecret = DiffieHellmanHelper.computeSharedSecret(myPrivateKey, peerPublicKey);

        // تخزين المفتاح محلياً وفي الخادم
        await dbHelper.storeKeysLocally(
          senderUUID: senderUUID,
          senderNUM: senderNUM,
          receiverUUID: receiverUUID,
          receiverNUM: lastNine,
          sharedSecret: sharedSecret,
        );
        await _storeKeysToServer(senderUUID, senderNUM, receiverUUID, lastNine, sharedSecret);

        return BigInt.parse(sharedSecret.toString());
      } else {
        // إذا كان المفتاح موجوداً محلياً، نقوم باستخدامه
        return BigInt.parse(key);
      }
    }


  /// دالة لتبادل المفاتيح مع الخادم والحصول على المفتاح العام الخاص بالجهة المستلمة
  Future<void> _exchangeKeysWithServer(
      String senderUUID,
      String receiverUUID,
      dynamic keys,
      String targetPhone,
      ) async {
    final response = await http.post(
      Uri.parse('https://political-thoracic-spatula.glitch.me/api/exchange-keys'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'senderUUID': senderUUID,
        'receiverUUID': receiverUUID,
        'senderPublicKey': keys.ownPublicKey,
        'targetPhone': targetPhone,
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      print('فشل تبادل المفاتيح. رمز الحالة: ${response.statusCode}');
      print('رد الخادم: ${response.body}');
      throw Exception('فشل تبادل المفاتيح مع الخادم');
    }

    final exchangeData = jsonDecode(response.body);
    if (exchangeData['targetPublicKey'] == null) {
      throw Exception('لم يتم استلام المفتاح العام من الخادم');
    }
  }

  /// دالة لتخزين المفاتيح على الخادم
  Future<void> _storeKeysToServer(
      String senderUUID,
      String senderNUM,
      String receiverUUID,
      String receiverNUM,
      dynamic sharedSecret,
      ) async {
    final storeResponse = await http.post(
      Uri.parse('https://political-thoracic-spatula.glitch.me/api/store-keys'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'senderUUID': senderUUID,
        'senderNUM': senderNUM,
        'receiverUUID': receiverUUID,
        'receiverNUM': receiverNUM,
        'sharedSecret': sharedSecret.toString()
      }),
    ).timeout(const Duration(seconds: 10));

    if (storeResponse.statusCode != 200) {
      print('فشل حفظ المفاتيح. رمز الحالة: ${storeResponse.statusCode}');
      print('رد الخادم: ${storeResponse.body}');
      throw Exception('فشل تبادل المفاتيح مع الخادم');
    }

    final storeData = jsonDecode(storeResponse.body);
    if (storeData['success'] != true) {
      throw Exception('فشل في تخزين المفاتيح على الخادم');
    }
  }

  /// دالة لتشفير الرسالة وإرسالها عبر SMS وتسجيلها
  Future<void> _processAndSendMessage(
      String plainText,
      BigInt secret,
      MessageController messageController,
      String address,
      ) async {
    final encryptedMessage = DiffieHellmanHelper.encryptMessage(plainText, secret);
    await messageController.sendEncryptedMessage(encryptedMessage, plainText, address);
  }

  /// دالة لتحديث واجهة المستخدم بإضافة الرسالة الجديدة
  void _updateUIWithNewMessage(String address, String content) async{
    Message newMessage = Message(
      sender: address,
      content: content,
      timestamp: DateTime.now(),
      isMe: true,
      isEncrypted: true,
    );
    setState(() {
      _messages.add(newMessage);
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    });
      // await _loadMessages();
  }

  /// دالة لتحريك الـ Scroll إلى نهاية القائمة
  void _scrollToBottom() {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }


  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        throw 'تعذر فتح تطبيق الهاتف';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال: $e')),
      );
    }
  }

  // دالة مقارنة بين تاريخين للتحقق إذا كانتا في نفس اليوم
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // دالة تنسيق عنوان التاريخ والوقت (مثل: Today • 03:15 PM)
  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now();
    if (_isSameDate(dateTime, now)) {
      return "Today • ${DateFormat('hh:mm a').format(dateTime)}";
    } else if (_isSameDate(dateTime, now.subtract(Duration(days: 1)))) {
      return "Yesterday • ${DateFormat('hh:mm a').format(dateTime)}";
    } else {
      return "${DateFormat('dd MMM yyyy').format(dateTime)} • ${DateFormat('hh:mm a').format(dateTime)}";
    }
  }

  // ويدجت لبناء رأس التاريخ
  Widget _buildDateHeader(DateTime dateTime) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          _formatDateHeader(dateTime),
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GoogleMessagesColors.background,
      appBar: AppBar(
        backgroundColor: GoogleMessagesColors.appBar,
        title: _buildAppBarTitle(),
        leading: _isSelectionMode
            ? IconButton(
          icon: Icon(Icons.close, color: GoogleMessagesColors.textDark),
          onPressed: _exitSelectionMode,
        )
            : null,
        actions: _buildAppBarActions(),
        elevation: 1,
        iconTheme: IconThemeData(color: GoogleMessagesColors.textDark),
      ),
      body: Column(
        children: [
          if (_isSearchMode && _searchResults.isNotEmpty)
            _buildSearchHeader(),
          Expanded(
            child: _loadingMessages
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];

                // التحقق مما إذا كان يجب عرض رأس التاريخ
                bool showHeader = false;
                if (index == 0) {
                  showHeader = true;
                } else {
                  final prevMessage = _messages[index - 1];
                  if (!_isSameDate(message.timestamp, prevMessage.timestamp))
                    showHeader = true;
                }

                return Column(
                  children: [
                    if (showHeader) _buildDateHeader(message.timestamp),
                    _buildMessageItem(index, message),
                  ],
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildAppBarTitle() {
    if (_isSelectionMode) {
      return Text(
        "${_selectedMessageIndices.length} محادثات مختارة",
        style: TextStyle(
          color: GoogleMessagesColors.textDark,
          fontSize: 18,
        ),
      );
    }
    if (_isSearchMode) {
      return TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: "ابحث في المحادثة...",
          border: InputBorder.none,
          hintStyle: TextStyle(color: GoogleMessagesColors.textLight),
        ),
        style: TextStyle(color: GoogleMessagesColors.textDark),
        onChanged: _performSearch,
      );
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: GoogleMessagesColors.primary.withOpacity(0.1),
          backgroundImage: widget.recipientImageUrl != null
              ? NetworkImage(widget.recipientImageUrl!)
              : null,
          child: widget.recipientImageUrl == null
              ? Text(
            widget.recipient.isNotEmpty
                ? widget.recipient[0].toUpperCase()
                : '?',
            style: TextStyle(
              color: GoogleMessagesColors.primary,
              fontSize: 18,
            ),
          )
              : null,
        ),
        SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  widget.recipient,
                  style: TextStyle(
                    color: GoogleMessagesColors.textDark,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: IconButton(
                  icon: Icon(
                    Icons.call,
                    size: 24,
                    color: GoogleMessagesColors.primary,
                  ),
                  onPressed: () => _makePhoneCall(widget.address),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget>? _buildAppBarActions() {
    if (_isSearchMode) return null;

    if (_isSelectionMode) {
      return [
        IconButton(
          icon: Icon(Icons.copy, color: GoogleMessagesColors.textDark),
          onPressed: _copySelectedMessages,
        ),
        IconButton(
          icon: Icon(Icons.delete, color: GoogleMessagesColors.textDark),
          onPressed: _deleteSelectedMessages,
        ),
      ];
    }

    return [
      IconButton(
        icon: Icon(Icons.search, color: GoogleMessagesColors.textDark),
        onPressed: _toggleSearchMode,
      ),
    ];
  }

  Widget _buildSearchHeader() {
    return Container(
      color: GoogleMessagesColors.appBar,
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_upward, color: GoogleMessagesColors.primary),
            onPressed: _jumpToPreviousResult,
          ),
          Text(
            '${_currentSearchIndex + 1} من ${_searchResults.length}',
            style: TextStyle(
              color: GoogleMessagesColors.textDark,
              fontSize: 16,
            ),
            textDirection: ui.TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
          IconButton(
            icon: Icon(Icons.arrow_downward, color: GoogleMessagesColors.primary),
            onPressed: _jumpToNextResult,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(int index, Message message) {
    final bool isMe = message.isMe;
    final bool isSelected = _selectedMessageIndices.contains(index);
    final bool isSearchResult = _searchResults.contains(index) &&
        index == _searchResults[_currentSearchIndex];

    return GestureDetector(
      onLongPress: () => _onLongPressMessage(index),
      onTap: () => _onTapMessage(index),
      child: Container(
        color: isSelected
            ? GoogleMessagesColors.accent.withOpacity(0.3)
            : isSearchResult
            ? GoogleMessagesColors.primary.withOpacity(0.1)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                decoration: BoxDecoration(
                  color: isMe ? GoogleMessagesColors.sentMessage : GoogleMessagesColors.receivedMessage,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    )
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.content,
                      style: TextStyle(
                        color: GoogleMessagesColors.textDark,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          DateFormat('hh:mm a').format(message.timestamp),
                          style: TextStyle(
                            color: GoogleMessagesColors.timeStamp,
                            fontSize: 12,
                          ),
                        ),
                        if (isMe && message.isEncrypted)
                          Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.lock_outline,
                              size: 12,
                              color: GoogleMessagesColors.timeStamp,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      margin: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: "اكتب رسالة...",
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: GoogleMessagesColors.textLight,
                  ),
                ),
                style: TextStyle(
                  color: GoogleMessagesColors.textDark,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: GoogleMessagesColors.primary),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
