import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:telephony/telephony.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:badges/badges.dart' as badges;
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

class _ConversationsScreenState extends State<ConversationsScreen>
    with WidgetsBindingObserver {
  late Future<List<Contact>> _contactsFuture;
  final Telephony _telephony = Telephony.instance;
  Map<String, List<SmsMessage>> _conversations = {};
  Map<String, int> _unreadCounts = {};
  String _message = "";

  // متغيرات البحث
  bool _isSearching = false;
  String _searchQuery = "";

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConversations();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this);
    _requestSmsPermission();
    _contactsFuture = FastContacts.getAllContacts();
    _loadConversations();
    initPlatformState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this);
    super.dispose();
  }

  onMessage(SmsMessage message) async {
    setState(() {
      _message = message.body ?? "Error reading message body.";
      print("🚀 تم استلام رسالة واردة: $_message");
    });
    final String address = message.address ?? 'Unknown';
    final String normalizedAddress = _normalizePhoneNumber(address);
    setState(() {
      _conversations.putIfAbsent(normalizedAddress, () => []);
      _conversations[normalizedAddress]!.add(message);
      _unreadCounts[normalizedAddress] =
          (_unreadCounts[normalizedAddress] ?? 0) + 1;
    });
    await _loadConversations();
  }

  Future<void> initPlatformState() async {
    bool? result = await _telephony.requestPhoneAndSmsPermissions;
    if (result ?? false) {
      _telephony.listenIncomingSms(
        onNewMessage: onMessage,
        onBackgroundMessage: onBackgroundMessage,
        listenInBackground: true,
      );
      await _loadConversations();
    } else {
      openAppSettings();
    }
  }

  // Future<void> _listenForNewMessages() async {
  //   try {
  //     final messages = await _telephony.getInboxSms();
  //     print("تم العثور على ${messages.length} رسالة جديدة");
  //     await _loadConversations();
  //   } catch (e) {
  //     print("خطأ في جلب الرسائل: $e");
  //   }
  // }

  Future<void> _requestSmsPermission() async {
    await Permission.sms.request();
  }

  Future<void> _loadConversations() async {
    final messageController =
    Provider.of<MessageController>(context, listen: false);
    final conversations =
    await messageController.getConversations(forceRefresh: true);
    // دمج المحادثات القديمة مع الجديدة
    final mergedConversations = {..._conversations, ...conversations};
    setState(() {
      _conversations = mergedConversations;
      _unreadCounts = {};
      mergedConversations.forEach((address, messages) {
        final normalizedAddress =
        messageController.normalizePhoneNumber(address);
        final unread = messages.where((msg) => !(msg.read ?? true)).length;
        if (unread > 0) {
          _unreadCounts[normalizedAddress] = unread;
        }
      });
    });
  }

  // دالة معالجة أرقام الهاتف
  String _normalizePhoneNumber(String phoneNumber) {
    String normalized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');

    // معالجة الأرقام الدولية
    if (normalized.startsWith('+')) {
      return normalized.substring(normalized.length - 9);
    }

    if (normalized.length >= 9) {
      return normalized.substring(normalized.length - 9);
    }
    print("Input: $phoneNumber, Output: ${normalized}");
    return normalized;
  }

  bool _containsLetters(String text) {
    return RegExp(r'[a-zA-Z]').hasMatch(text);
  }

  String getContactName(String address, List<Contact> contacts) {
    // إذا كان العنوان يحتوي على أحرف غير رقمية، عرضه مباشرة
    if (_containsLetters(address)) {
      print("Jaib$address");
      return address;
    }

    final normalizedAddress = _normalizePhoneNumber(address);

    // إذا كان الرقم قصير جدًا (مثل أرقام الخدمة) عرضه كما هو
    if (normalizedAddress.length <= 7) {
      return address;
    }

    // البحث في جهات الاتصال
    for (var contact in contacts) {
      for (var phone in contact.phones) {
        String normalizedContact = _normalizePhoneNumber(phone.number);
        if (normalizedContact == normalizedAddress) {
          return contact.displayName.isNotEmpty
              ? contact.displayName
              : address;
        }
      }
    }

    return address; // إرجاع العنوان الأصلي إذا لم يُعثر على تطابق
  }

  // دالة تنسيق التاريخ حسب الشروط المطلوبة
  String _formatDate(int timestamp) {
    final now = DateTime.now();
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (date.year == now.year && date.month == now.month) {
      return DateFormat('h:mm a').format(date);
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date);
    } else {
      return DateFormat('M/d/yy').format(date);
    }
  }

  Color _getColorFromChar(String char) {
    final code = char.codeUnitAt(0);
    return Colors.primaries[code % Colors.primaries.length];
  }

  // دالة تحديث استعلام البحث
  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  // تصفية المحادثات بالبحث (تحقق في اسم جهة الاتصال أو نص الرسالة)
  List<String> _filterConversations(List<Contact> contacts) {
    if (_searchQuery.isEmpty) return _conversations.keys.toList();
    List<String> results = [];
    _conversations.forEach((key, messages) {
      final name = getContactName(key, contacts);
      if (name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        results.add(key);
      } else {
        bool found = messages.any((msg) =>
        (msg.body != null &&
            msg.body!.toLowerCase().contains(_searchQuery.toLowerCase())));
        if (found) results.add(key);
      }
    });
    return results;
  }

  // تصفية جهات الاتصال بالبحث
  List<Contact> _filterContacts(List<Contact> contacts) {
    if (_searchQuery.isEmpty) return contacts;
    return contacts
        .where((contact) => contact.displayName
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()))
        .toList();
  }

  // دالة تمييز (Highlight) النص الذي يتطابق مع استعلام البحث باللون الأصفر
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text, style: TextStyle(color: Colors.grey[600]));
    List<TextSpan> spans = [];
    String lowerText = text.toLowerCase();
    String lowerQuery = query.toLowerCase();
    int start = 0;
    while (true) {
      int index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(
            text: text.substring(start),
            style: TextStyle(color: Colors.grey[600])));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(
            text: text.substring(start, index),
            style: TextStyle(color: Colors.grey[600])));
      }
      spans.add(TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
              backgroundColor: Colors.yellow, color: Colors.black)));
      start = index + query.length;
    }
    return RichText(text: TextSpan(children: spans, style: const TextStyle(fontSize: 14)));
  }

  // بناء شريط التطبيق المُعدل ليشمل وضع البحث
  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = "";
            });
          },
        ),
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
              hintText: "Search...", border: InputBorder.none),
          onChanged: _updateSearchQuery,
        ),
      );
    } else {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Messages"),
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = true;
              });
            },
          ),
          IconButton(
              icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      );
    }
  }

  Widget buildShimmerScaffold() {
    int itemCount = _conversations.isNotEmpty ? _conversations.keys.length : 11;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            width: 150,
            height: 20,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView.builder(
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Padding(
            padding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 12,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    width: 40,
                    height: 12,
                    color: Colors.white,
                  )
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: Colors.lightBlue[100],
          icon: const Icon(Icons.message_outlined, color: Colors.blue),
          label: const Text("Start chat",
              style: TextStyle(color: Colors.blue)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Contact>>(
      future: _contactsFuture,
      builder: (context, contactsSnapshot) {
        if (contactsSnapshot.connectionState == ConnectionState.waiting) {
          return buildShimmerScaffold();
        } else if (contactsSnapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Messages"),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            body: Center(child: Text("Error: ${contactsSnapshot.error}")),
          );
        } else if (!contactsSnapshot.hasData ||
            contactsSnapshot.data!.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Messages"),
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            body: const Center(child: Text("No contacts available")),
          );
        } else {
          final contacts = contactsSnapshot.data!;
          // إذا كان المستخدم في وضع البحث
          if (_isSearching) {
            final filteredConversations = _filterConversations(contacts);
            final filteredContacts = _filterContacts(contacts);
            return Scaffold(
              backgroundColor: Colors.white,
              appBar: _buildAppBar(),
              body: ListView(
                children: [
                  if (filteredConversations.isNotEmpty)
                    const Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        "Conversations",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ...filteredConversations.map((address) {
                    final messages = _conversations[address]!;
                    final lastMessage = messages.reduce(
                            (a, b) => (a.date ?? 0) > (b.date ?? 0) ? a : b);
                    final name = getContactName(address, contacts);
                    final char = name.isNotEmpty ? name[0] : "?";
                    final color = _getColorFromChar(char);
                    final unreadCount = _unreadCounts[address] ?? 0;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: color,
                        child: Text(
                          char,
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: _buildHighlightedText(
                          lastMessage.body ?? "", _searchQuery),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (lastMessage.date != null)
                            Text(
                              _formatDate(lastMessage.date!),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (unreadCount > 0)
                            badges.Badge(
                              badgeContent: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 10),
                              ),
                              badgeColor: Colors.blueAccent,
                              padding: const EdgeInsets.all(6),
                            ),
                        ],
                      ),
                      onTap: () {
                        final messageController = Provider.of<MessageController>(context, listen: false);
                        final normalizedAddress = messageController.normalizePhoneNumber(address);
                        setState(() {
                          _unreadCounts[normalizedAddress] = 0;
                        });
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              address: address,
                              recipient: name,
                              recipientImageUrl: null,
                              searchQuery: _searchQuery, // تمرير استعلام البحث الحالي
                            ),
                          ),
                        ).then((_) => _loadConversations());
                      },
                    );
                  }).toList(),
                  if (filteredContacts.isNotEmpty)
                    const Padding(
                      padding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        "Contacts",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ...filteredContacts.map((contact) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey.shade400,
                        child: Text(
                          contact.displayName.isNotEmpty
                              ? contact.displayName[0]
                              : "?",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
                      title: Text(
                        contact.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onTap: () async {
                        final messageController = Provider.of<MessageController>(context, listen: false);
                        String? existingAddress;

                        // إذا كان اسم الجهة يحتوي على أحرف غير رقمية
                        if (_containsLetters(contact.displayName)) {
                          existingAddress = contact.displayName;
                        }
                        else {
                          // البحث في أرقام الهاتف
                          for (var phone in contact.phones) {
                            String normalizedPhone = messageController.normalizePhoneNumber(phone.number);

                            for (var convAddress in _conversations.keys) {
                              String normalizedConv = messageController.normalizePhoneNumber(convAddress);

                              if (normalizedConv == normalizedPhone) {
                                existingAddress = convAddress;
                                break;
                              }
                            }
                            if (existingAddress != null) break;
                          }
                        }
                        if (existingAddress != null) {
                          final validAddress = existingAddress!;
                          // استخدم validAddress هنا
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                address: validAddress,
                                recipient: contact.displayName,
                                recipientImageUrl: null,
                              ),
                            ),
                          );
                        }else {
                          if (contact.phones.isEmpty) {
                            // إذا كان الاسم يحتوي على أحرف بدون أرقام
                            if (_containsLetters(contact.displayName)) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    address: contact.displayName,
                                    recipient: contact.displayName,
                                    recipientImageUrl: null,
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("لا يوجد رقم هاتف لهذه الجهة")),
                              );
                            }
                            return;
                          }

                          String phoneNumber = contact.phones.first.number;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                address: phoneNumber,
                                recipient: contact.displayName,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  }).toList(),
                ],
              ),
            );
          } else {
            final addresses = _conversations.keys.toList();
            addresses.sort((a, b) {
              final messagesA = _conversations[a]!;
              final messagesB = _conversations[b]!;
              final lastA =
              messagesA.reduce((a, b) => (a.date ?? 0) > (b.date ?? 0) ? a : b);
              final lastB =
              messagesB.reduce((a, b) => (a.date ?? 0) > (b.date ?? 0) ? a : b);
              return (lastB.date ?? 0).compareTo(lastA.date ?? 0);
            });
            return Scaffold(
              backgroundColor: Colors.white,
              appBar: _buildAppBar(),
              body: ListView.builder(
                itemCount: addresses.length,
                itemBuilder: (context, index) {
                  final address = addresses[index];
                  final messages = _conversations[address]!;
                  final lastMessage = messages.reduce(
                          (a, b) => (a.date ?? 0) > (b.date ?? 0) ? a : b);
                  final name = getContactName(address, contacts);
                  final char = name.isNotEmpty ? name[0] : "?";
                  final color = _getColorFromChar(char);
                  final unreadCount = _unreadCounts[address] ?? 0;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color,
                      child: Text(
                        char,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      lastMessage.body ?? "",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (lastMessage.date != null)
                          Text(
                            _formatDate(lastMessage.date!),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        if (unreadCount > 0)
                          badges.Badge(
                            badgeContent: Text(
                              '$unreadCount',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 10),
                            ),
                            badgeColor: Colors.blueAccent,
                            padding: const EdgeInsets.all(6),
                          ),
                      ],
                    ),
                    onTap: () {
                      final messageController =
                      Provider.of<MessageController>(context, listen: false);
                      final normalizedAddress =
                      messageController.normalizePhoneNumber(address);
                      setState(() {
                        _unreadCounts[normalizedAddress] = 0;
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            address: address,
                            recipient: name,
                            recipientImageUrl: null,
                          ),
                        ),
                      ).then((_) => _loadConversations());
                    },
                  );
                },
              ),
              floatingActionButton: FloatingActionButton.extended(
                backgroundColor: Colors.lightBlue[100],
                icon: const Icon(Icons.message_outlined, color: Colors.blue),
                label: const Text("Start chat",
                    style: TextStyle(color: Colors.blue)),
                onPressed: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) =>  NewMessageScreen()));
                },
              ),
            );
          }
        }
      },
    );
  }
}
