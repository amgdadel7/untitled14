import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:telephony/telephony.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:badges/badges.dart'; // أضف هذه المكتبة
import '../controllers/message_controller.dart';
import 'chat_screen.dart';
import 'new_message_screen.dart';
onBackgroundMessage(SmsMessage message) {
  debugPrint("onBackgroundMessage called");
}
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late Future<List<Contact>> _contactsFuture;
  final Telephony _telephony = Telephony.instance;
  Map<String, List<SmsMessage>> _conversations = {};
  late Timer _timer;
  String _message = "";
  final telephony = Telephony.instance;
  @override
  void initState() {
    super.initState();
    _requestSmsPermission();
    _contactsFuture = FastContacts.getAllContacts();
    _loadConversations();
    initPlatformState();

    // _startListening();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
  onMessage(SmsMessage message) async {
    setState(() {
      _message = message.body ?? "Error reading message body.";
      print("🚀 تم استلام رسالة واردة: $_message");
      _listenForNewMessages();

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
          onNewMessage: onMessage, onBackgroundMessage: onBackgroundMessage);
    }

    if (!mounted) return;
  }
  // void _startListening() {
  //   _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
  //     _listenForNewMessages();
  //   });
  // }

  Future<void> _requestSmsPermission() async {
    if (await Permission.sms.request().isGranted) {
      print("تم منح إذن قراءة الرسائل");
    } else {
      print("تم رفض إذن قراءة الرسائل");
    }
  }

  Future<void> _loadConversations() async {
    final messageController = Provider.of<MessageController>(context, listen: false);
    final conversations = await messageController.getConversations();
    setState(() {
      _conversations = conversations;
    });
  }

  void _listenForNewMessages() {
    _telephony.getInboxSms().then((messages) {
      print("تم التحقق من الرسائل الواردة");
      _loadConversations();
    });
  }

  String _normalizePhoneNumber(String phoneNumber) {
    String normalized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');

    if (normalized.startsWith('00')) {
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }

    return normalized;
  }

  // 🔹 دالة للتحقق مما إذا كان النص يحتوي على أحرف
  bool _containsLetters(String text) {
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  String getContactName(String address, List<Contact> contacts) {
    // إذا كان العنوان يحتوي على أحرف، نعيده كما هو
    if (_containsLetters(address)) {
      return address;
    }

    // إذا كان العنوان رقمًا، نقوم بتطبيعه والبحث عن الاسم
    final normalizedAddress = _normalizePhoneNumber(address);

    for (var contact in contacts) {
      for (var phone in contact.phones) {
        String normalizedContactNumber = _normalizePhoneNumber(phone.number);

        if (normalizedAddress.endsWith(normalizedContactNumber) ||
            normalizedContactNumber.endsWith(normalizedAddress)) {
          return contact.displayName;
        }
      }
    }
    return address; // إذا لم يتم العثور على اسم، يتم إرجاع الرقم كما هو
  }

  String _formatDate(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("المحادثات"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {},
          ),
        ],
      ),
      body: FutureBuilder<List<Contact>>(
        future: _contactsFuture,
        builder: (context, contactsSnapshot) {
          if (contactsSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (contactsSnapshot.hasError) {
            return Center(child: Text("حدث خطأ: ${contactsSnapshot.error}"));
          } else if (!contactsSnapshot.hasData || contactsSnapshot.data!.isEmpty) {
            return const Center(child: Text("لا توجد جهات اتصال"));
          } else {
            final contacts = contactsSnapshot.data!;
            final addresses = _conversations.keys.toList();
            addresses.sort((a, b) {
              final messagesA = _conversations[a]!;
              final messagesB = _conversations[b]!;
              final lastMsgA = messagesA.reduce((curr, next) => (curr.date ?? 0) > (next.date ?? 0) ? curr : next);
              final lastMsgB = messagesB.reduce((curr, next) => (curr.date ?? 0) > (next.date ?? 0) ? curr : next);
              return (lastMsgB.date ?? 0).compareTo(lastMsgA.date ?? 0);
            });

            return ListView.builder(
              itemCount: addresses.length,
              itemBuilder: (context, index) {
                final address = addresses[index];
                final messages = _conversations[address]!;
                final lastMessage = messages.reduce((curr, next) => (curr.date ?? 0) > (next.date ?? 0) ? curr : next);

                String recipientName = getContactName(address, contacts);

                // 🔹 حساب عدد الرسائل غير المقروءة
                int unreadCount = messages.where((msg) => msg.read == false).length;

                return ListTile(
                  leading: CircleAvatar(
                    child: Text(recipientName.isNotEmpty ? recipientName[0] : '?'),
                  ),
                  title: Text(recipientName),
                  subtitle: Text(lastMessage.body ?? ""),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_formatDate(lastMessage.date ?? 0)),
                      if (unreadCount > 0)
                        Badge(
                          badgeContent: Text(
                            unreadCount.toString(),
                            style: const TextStyle(color: Colors.white),
                          ),
                          badgeColor: Colors.green, // لون البادج
                          elevation: 0, // إزالة الظل
                          padding: const EdgeInsets.all(6), // حجم البادج
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          address: address,
                          recipient: recipientName,
                        ),
                      ),
                    ).then((_) {
                      _loadConversations();
                    });
                  },
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewMessageScreen(),
            ),
          );
        },
        child: const Icon(Icons.message),
      ),
    );
  }
}