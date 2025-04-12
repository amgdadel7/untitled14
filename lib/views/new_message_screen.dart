import 'package:flutter/material.dart';
import 'package:fast_contacts/fast_contacts.dart';
import 'package:provider/provider.dart';
import '../controllers/message_controller.dart';
import 'chat_screen.dart';

/// تعريف ثوابت الألوان لتطبيق اللون الرمادي المائل للزُرقة
class AppColors {
  static const scaffoldBackground = Color(0xFFE6EFF6); // رمادي أغمق شوي
  static const topBackground = Color(0xFFF2FBFF); // نفس الخلفية للشريط العلوي
  static const appBarText = Color(0xFF202124);
  static const appBarIcon = Color(0xFF202124);
  static const inputLabel = Color(0xFF5F6368);
}

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

  /// دالة لتوليد لون ثابت للـ Avatar بناءً على اسم جهة الاتصال
  Color _getAvatarBackgroundColor(String text) {
    if (text.isEmpty) return Colors.grey;
    final int hash = text.codeUnits.fold(0, (prev, element) => prev + element);
    return Colors.primaries[hash % Colors.primaries.length].shade400;
  }

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

  /// فلترة جهات الاتصال وفق الاستعلام
  void _filterContacts(String query) {
    setState(() {
      _searchQuery = query;
      _filteredContacts = _contacts.where((contact) {
        final lowerQuery = query.toLowerCase();
        final name = contact.displayName.toLowerCase();
        final phoneMatch = contact.phones.isNotEmpty &&
            contact.phones.any((phone) => phone.number.contains(query));
        return name.contains(lowerQuery) || phoneMatch;
      }).toList();
    });
  }

  /// تطبيع رقم الهاتف للمقارنة الصحيحة
  String _normalizePhoneNumber(String phoneNumber) {
    String normalized = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalized.startsWith('00')) {
      normalized = normalized.substring(2);
    } else if (normalized.startsWith('0')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  /// التحقق من وجود محادثة مسبقًا مع العنوان المحدد
  Future<bool> _isConversationExists(String address) async {
    final messageController =
    Provider.of<MessageController>(context, listen: false);
    final conversations = await messageController.getConversations();
    String normalizedAddress = _normalizePhoneNumber(address);
    for (var key in conversations.keys) {
      if (_normalizePhoneNumber(key) == normalizedAddress) {
        return true;
      }
    }
    return false;
  }

  /// الحصول على المفتاح المطابق للمحادثة إن وجد
  Future<String?> _getExistingConversationKey(String address) async {
    final messageController =
    Provider.of<MessageController>(context, listen: false);
    final conversations = await messageController.getConversations();
    String normalizedAddress = _normalizePhoneNumber(address);
    for (var key in conversations.keys) {
      if (_normalizePhoneNumber(key) == normalizedAddress) {
        return key;
      }
    }
    return null;
  }

  /// تجميع جهات الاتصال حسب أول حرف من الاسم
  Map<String, List<Contact>> _groupContactsByInitial(List<Contact> contacts) {
    contacts.sort((a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    final Map<String, List<Contact>> grouped = {};
    for (var contact in contacts) {
      String firstLetter = contact.displayName.isNotEmpty
          ? contact.displayName[0].toUpperCase()
          : "#";
      if (!grouped.containsKey(firstLetter)) {
        grouped[firstLetter] = [];
      }
      grouped[firstLetter]!.add(contact);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final groupedContacts =  _filteredContacts;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      // الشريط العلوي بخلفية اللون الرمادي المائل للزُرقة
      appBar: AppBar(
        backgroundColor: AppColors.topBackground,
        elevation: 0,
        title: const Text(
          "New conversation",
          style: TextStyle(
            color: AppColors.appBarText,
            fontWeight: FontWeight.w500,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.appBarIcon),
      ),
      body: Column(
        children: [
          // خلفية موحدة للشريط العلوي ومربع البحث
          Container(
            color: AppColors.topBackground,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            // مربع البحث بدون حواف
            child: TextField(
              controller: _searchController,
              cursorColor: AppColors.appBarText,
              style:
              const TextStyle(color: AppColors.appBarText, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.topBackground,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                labelText: "To: Type names, phone numbers",
                labelStyle: TextStyle(
                  color: AppColors.inputLabel,
                  fontSize: 14,
                ),
                // إزالة الحواف بالكامل
                border: InputBorder.none,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _filterContacts("");
                  },
                  color: AppColors.inputLabel,
                )
                    : null,
              ),
              onChanged: _filterContacts,
            ),
          ),
          // لا توجد فواصل هنا (تم إزالة Divider)
          // قائمة جهات الاتصال مع التجميع بحسب أول حرف
          Expanded(
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: groupedContacts.length + (_searchQuery.isNotEmpty ? 1 : 0),
              itemBuilder: (context, index) {
                if (_searchQuery.isNotEmpty && index == 0) {
                  // خيار إرسال الرقم المكتوب
                  return ListTile(
                    leading: const Icon(Icons.person, color: Colors.blueGrey),
                    title: Text(
                      "Send to $_searchQuery",
                      style: const TextStyle(
                        color: AppColors.appBarText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      _searchQuery,
                      style: TextStyle(color: AppColors.inputLabel),
                    ),
                    onTap: () async {
                      bool exists = await _isConversationExists(_searchQuery);
                      String addressToUse = _searchQuery;
                      if (exists) {
                        String? existingKey =
                        await _getExistingConversationKey(_searchQuery);
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
                  );
                }

                final contact = groupedContacts[_searchQuery.isNotEmpty ? index - 1 : index];
                final displayName = contact.displayName.trim();
                final phoneNumber = contact.phones.isNotEmpty
                    ? contact.phones.first.number
                    : "";

                return ListTile(
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: _getAvatarBackgroundColor(displayName),
                    child: Text(
                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    displayName,
                    style: const TextStyle(
                      color: AppColors.appBarText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    phoneNumber.isNotEmpty ? phoneNumber : "No phone number",
                    style: TextStyle(color: AppColors.inputLabel),
                  ),
                  onTap: () async {
                    if (phoneNumber.isNotEmpty) {
                      bool exists = await _isConversationExists(phoneNumber);
                      String addressToUse = phoneNumber;
                      if (exists) {
                        String? existingKey =
                        await _getExistingConversationKey(phoneNumber);
                        if (existingKey != null) {
                          addressToUse = existingKey;
                        }
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            address: addressToUse,
                            recipient: displayName,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
