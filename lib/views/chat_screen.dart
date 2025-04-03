import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:mobile_number/mobile_number.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
// import 'package:sms_advanced/sms_advanced.dart';
import 'package:telephony/telephony.dart';
// import 'package:telephony/telephony.dart';
import 'package:untitled14/models/conversation_key.dart';
import 'package:untitled14/utils/encryption.dart';
import '../controllers/message_controller.dart';
import '../models/message_model.dart';

import '../utils/network_checker.dart';
// import 'package:sms_advanced/sms_advanced.dart' as sms_advanced;
import 'package:telephony/telephony.dart';
import 'package:get_phone_number/get_phone_number.dart';
// import 'package:sms_advanced/sms_advanced.dart';
// void backgroundMessageHandler(SmsMessage message) {
//   log("📩 رسالة SMS جديدة في الخلفية: ${message.body}");
// }
// Future<void> backgroundMessageHandler(SmsMessage message) async {
//   print("📩 رسالة جديدة من ${message.address}: ${message.body}");
//   // يمكنك معالجة الرسالة هنا
// }
onBackgroundMessage(SmsMessage message) {
  debugPrint("onBackgroundMessage called");
}
class ChatScreen extends StatefulWidget {
  final String address;
  final String recipient;

  const ChatScreen({Key? key, required this.address, required this.recipient}) : super(key: key);

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


  bool _loadingMessages = true;
  late Timer _timer;
  // String _message = "";


  @override
  void initState() {
    super.initState();
    _loadMessages();
    _startListening();
    initPlatformState();
    // Telephony.instance.listenIncomingSms(
    //   onNewMessage: (SmsMessage message) {
    //     // طباعة الرسالة عند وصولها
    //     print("🚀 تم استلام رسالة واردة: ${message.body}");
    //
    //     // تمرير الرسالة إلى المعالج الموجود في MessageController
    //     Provider.of<MessageController>(context, listen: true)
    //         .processIncomingSms(message);
    //   },
    //   listenInBackground: false, // يمكنك ضبطها على true للاستماع في الخلفية
    // );
    // _listenForNewMessages();
    // تهيئة قاعدة البيانات أولاً
    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      final messageController = Provider.of<MessageController>(
          context, listen: false);
      await messageController.initDatabases(); // تهيئة قاعدة البيانات
      messageController.printMessages();
      messageController.printConversationKeys();
    });

    // _countSentAndReceivedMessages();
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }
  onBackgroundMessage(SmsMessage message) {
    debugPrint("onBackgroundMessage called");
  }

  onMessage(SmsMessage message) async {
    setState(() {
      _message = message.address ?? "Error reading message body.";
      print("🚀 تم استلام رسالة واردة: $_message");
      _loadMessages();
      // Provider.of<MessageController>(context, listen: true)
      //         .processIncomingSms(message);
      mess.processIncomingSms(message);

    });
  }



  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.

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
  //   if (result != null && result) {
  //     telephony.listenIncomingSms(
  //         onNewMessage: onMessage, onBackgroundMessage: onBackgroundMessage);
  //   }
  //
  //   if (!mounted) return;
  // }

  // Future<void> _countSentAndReceivedMessages() async {
  //   final messageController = Provider.of<MessageController>(context, listen: false);
  //
  //   // جلب جميع الرسائل للمحادثة الحالية
  //   List<Message> msgs = await messageController.getMessagesForThread(widget.address);
  //   int sentMessagesCount = 0;
  //   int receivedMessagesCount = 0;
  //
  //   // حساب عدد الرسائل المرسلة والمستقبلة
  //   for (var message in msgs) {
  //     if (message.isMe) {
  //       sentMessagesCount++; // إذا كانت الرسالة مرسلة
  //     } else {
  //       receivedMessagesCount++; // إذا كانت الرسالة مستقبلة
  //     }
  //   }
  //
  //   // عرض العدد في الـ Console أو استخدمه في مكان آخر حسب الحاجة
  //   print("عدد الرسائل المرسلة: $sentMessagesCount");
  //   print("عدد الرسائل المستقبلة: $receivedMessagesCount");
  //
  //   // تحديث العدادات بشكل دوري
  //   _timer = Timer.periodic(const Duration(milliseconds: 2), (timer) async {
  //     List<Message> updatedMsgs = await messageController.getMessagesForThread(widget.address);
  //     int updatedSentMessagesCount = 0;
  //     int updatedReceivedMessagesCount = 0;
  //
  //     for (var message in updatedMsgs) {
  //       if (message.isMe) {
  //         updatedSentMessagesCount++; // تحديث العدد المرسل
  //       } else {
  //         updatedReceivedMessagesCount++; // تحديث العدد المستلم
  //       }
  //     }
  //
  //     // إذا تغيرت الرسائل المستقبلة، قم بتحميل الرسائل مجددًا
  //     if (updatedReceivedMessagesCount != receivedMessagesCount) {
  //       print("عدد الرسائل المستقبلة قد تغير: $updatedReceivedMessagesCount");
  //       _loadMessages();
  //     }
  //
  //     // تحديث العدادات
  //     receivedMessagesCount = updatedReceivedMessagesCount;
  //     sentMessagesCount = updatedSentMessagesCount;
  //   });
  // }



  Future<void> _loadMessages() async {
    final messageController = Provider.of<MessageController>(
        context, listen: false);
    List<Message> msgs = await messageController.getMessagesForThread(
        widget.address);

    setState(() {
      _messages = msgs;
      _messages.sort((a, b) =>
          a.timestamp.compareTo(
              b.timestamp)); // ترتيب الرسائل من الأقدم إلى الأحدث
      _loadingMessages = false;
    });

    // تمرير الشاشة إلى آخر رسالة عند فتح المحادثة
    if (WidgetsBinding.instance != null) {
      WidgetsBinding.instance!.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  void _startListening() {
      // _listenForNewMessages();
    setState(() {
    });
    // _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
    // });
  }

  // void _listenForNewMessages(){
  //   sms_advanced.SmsReceiver receiver = new sms_advanced.SmsReceiver();
  //   receiver.onSmsReceived?.listen((sms_advanced.SmsMessage msg) => print("sssssssss$msg.body"));
  //

  // }


  // Future<void> getSimInfo() async {
  //   try {
  //     bool permissionGranted = await MobileNumber.hasPhonePermission;
  //     if (!permissionGranted) {
  //       permissionGranted = await MobileNumber.requestPhonePermission;
  //     }
  //     if (permissionGranted) {
  //       List<SimCard> simCards = await MobileNumber.getSimCards;
  //       for (var sim in simCards) {
  //         print("SIM Number: ${sim.number}");
  //         print("Carrier Name: ${sim.carrierName}");
  //         // يمكنك عرض المزيد من المعلومات المتاحة من SimCard.
  //       }
  //     } else {
  //       print("الصلاحيات غير ممنوحة.");
  //     }
  //   } catch (e) {
  //     print("خطأ في استرجاع معلومات SIM: $e");
  //   }
  // }


  void _sendMessage() async {

    // final module = ();
    //
    // if (!module.isSupport()) {
    //   print('Not supported platform');
    // }
    //
    // if (!await module.hasPermission()) {
    //   if (!await module.requestPermission()) {
    //     throw 'Failed to get permission phone number';
    //   }
    // }
    //
    // String phoneNumber = await module.getSimCardList();
    // print('getPhoneNumber result: $phoneNumber');
    final messageController = Provider.of<MessageController>(context, listen: false);
    String text = _messageController.text;

    if (text.isNotEmpty) {
      // إنشاء كائن SmsMessage يدويًا باستخدام المُنشئ الصحيح
      print("Existing shared:");
      // 1. بدء تبادل المفاتيح
      await messageController.initiateKeyExchange(widget.address);
      print("Existing shared:");
      // String address = sms.address ?? 'Unknown';
      // String sender = address;
      // 2. استرجاع مفتاح المحادثة لتشفير الرسالة
      ConversationKey? key = await messageController.getConversationKey(
          widget.address);
      String finalMessage = text;
      print("Existing shared: ${key.toString()}");

      if (key != null && key.sharedSecret != null) {
        print("Existing shared secret1: ${key.sharedSecret}");

        // تشفير الرسالة باستخدام المفتاح المشترك
        finalMessage =
            DiffieHellmanHelper.encryptMessage(text, key.sharedSecret!);
        print("Existing shared: $finalMessage");
      } else {
        print("⚠️ لم يتم تبادل المفاتيح بعد، ستُرسل الرسالة بدون تشفير.");
      }

      // 3. إضافة الرسالة المشفرة مؤقتًا لقائمة المحادثة
      setState(() {
        _messages.add(
          Message(
            sender: widget.address,
            content: text,
            timestamp: DateTime.now(),
            isMe: true,
            isEncrypted: key != null && key.sharedSecret != null,
          ),
        );
      });

      // تمرير الشاشة إلى آخر رسالة بعد الإضافة
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }

      // مسح حقل النص
      _messageController.clear();

      // 4. إرسال الرسالة عبر SMS (سيتم التحقق من وجود تشفير داخل الدالة sendSMS)
      await messageController.sendSMS(text, [widget.address]);

      // 5. إعادة تحميل الرسائل من قاعدة البيانات لتحديث الواجهة
      await _loadMessages();
    }
  }


  // void _sendMessage() async {
  //   final messageController = Provider.of<MessageController>(context, listen: false);
  //   String text = _messageController.text;
  //   // print("11111111$text");
  //
  //   if (text.isNotEmpty) {
  //     await messageController.initiateKeyExchange(widget.address);
  //     await messageController.sendSMS(text, [widget.address]);
  //
  //     _messageController.clear();
  //
  //     // إعادة تحميل الرسائل بعد إرسال الرسالة
  //     await _loadMessages();
  //     setState(() {});
  //   }
  //
  // }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.recipient)),
      body: Column(
        children: [
          Expanded(
            child: Consumer<MessageController>(
              builder: (context, messageController, child) {
                if (_loadingMessages) {
                  return const Center(child: CircularProgressIndicator());
                } else {
                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      bool isMe = message.isMe;
                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment
                            .centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue.shade200 : Colors.grey
                                .shade300,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(15),
                              topRight: const Radius.circular(15),
                              bottomLeft: isMe
                                  ? const Radius.circular(15)
                                  : Radius.zero,
                              bottomRight: isMe ? Radius.zero : const Radius
                                  .circular(15),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                message.content,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${message.timestamp.hour}:${message.timestamp
                                    .minute}",
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "اكتب رسالة...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}