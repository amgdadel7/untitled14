import 'package:flutter/material.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:provider/provider.dart';
import '../controllers/message_controller.dart';
import 'chat_screen.dart';

class NewMessageScreen extends StatefulWidget {
  const NewMessageScreen({Key? key}) : super(key: key);

  @override
  _NewMessageScreenState createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends State<NewMessageScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Contact> _contacts = [];
  List<Contact> _filteredContacts = [];
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await FastContacts.getAllContacts();
    setState(() {
      _contacts = contacts;
      _filteredContacts = contacts;
    });
  }

  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      _filteredContacts = _contacts
          .where((contact) =>
      contact.displayName.toLowerCase().contains(query.toLowerCase()) ||
          (contact.phones.isNotEmpty &&
              contact.phones.any((phone) => phone.number.contains(query))))
          .toList();
    });
  }

  // دالة لتطبيع الأرقام (للمقارنة الصحيحة)
  String _normalizePhoneNumber(String phoneNumber) {
    String normalized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.startsWith('00')) {
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  // التحقق مما إذا كانت المحادثة موجودة بالفعل
  Future<bool> _isConversationExists(String address) async {
    final messageController = Provider.of<MessageController>(context, listen: false);
    final conversations = await messageController.getConversations();
    String normalizedAddress = _normalizePhoneNumber(address);
    for (var key in conversations.keys) {
      if (_normalizePhoneNumber(key) == normalizedAddress) {
        return true;
      }
    }
    return false;
  }

  // الحصول على المفتاح (الرقم) المطابق للمحادثة إن وجد
  Future<String?> _getExistingConversationKey(String address) async {
    final messageController = Provider.of<MessageController>(context, listen: false);
    final conversations = await messageController.getConversations();
    String normalizedAddress = _normalizePhoneNumber(address);
    for (var key in conversations.keys) {
      if (_normalizePhoneNumber(key) == normalizedAddress) {
        return key;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("New Message"),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: "To: Type names, phone numbers",
                border: OutlineInputBorder(),
              ),
              onChanged: _filterContacts,
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                const Divider(),
                // عرض الخيار للرقم المكتوب إذا لم يكن موجودًا في جهات الاتصال
                if (_searchQuery.isNotEmpty &&
                    !_filteredContacts.any((contact) =>
                        contact.phones.any((phone) =>
                            phone.number.contains(_searchQuery))))
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: Text("Send to $_searchQuery"),
                    subtitle: Text(_searchQuery),
                    onTap: () async {
                      bool exists = await _isConversationExists(_searchQuery);
                      String addressToUse = _searchQuery;
                      if (exists) {
                        String? existingKey = await _getExistingConversationKey(_searchQuery);
                        if (existingKey != null) {
                          addressToUse = existingKey;
                        }
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            address: addressToUse,
                            recipient: _searchQuery,
                          ),
                        ),
                      );
                    },
                  ),
                // عرض قائمة جهات الاتصال المُفلترة
                ..._filteredContacts.map((contact) {
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(contact.displayName.isNotEmpty ? contact.displayName[0] : '?'),
                    ),
                    title: Text(contact.displayName),
                    subtitle: Text(contact.phones.isNotEmpty
                        ? contact.phones.first.number
                        : "No phone number"),
                    onTap: () async {
                      final recipientNumber = contact.phones.isNotEmpty
                          ? contact.phones.first.number
                          : "";
                      if (recipientNumber.isNotEmpty) {
                        bool exists = await _isConversationExists(recipientNumber);
                        String addressToUse = recipientNumber;
                        if (exists) {
                          String? existingKey = await _getExistingConversationKey(recipientNumber);
                          if (existingKey != null) {
                            addressToUse = existingKey;
                          }
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              address: addressToUse,
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
          ),
        ],
      ),
    );
  }
}
