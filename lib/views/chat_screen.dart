import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/message_controller.dart';
import '../models/message_model.dart';

class ChatScreen extends StatefulWidget {
  final String address;
  final String recipient;

  const ChatScreen({
    Key? key,
    required this.address,
    required this.recipient,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<Message> _messages = [];
  bool _loadingMessages = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final messageController = Provider.of<MessageController>(context, listen: false);
    List<Message> msgs = await messageController.getMessagesForThread(widget.address);
    print("عدد الرسائل المحملة: ${msgs.length}");
    setState(() {
      _messages = msgs;
      _loadingMessages = false;
    });
  }

  void _sendMessage() async {
    final messageController = Provider.of<MessageController>(context, listen: false);
    String text = _messageController.text;
    if (text.isNotEmpty) {
      Message newMessage = Message(
        sender: widget.address,
        content: text,
        timestamp: DateTime.now(),
        isMe: true,
        isEncrypted: true,
      );
      setState(() {
        _messages.insert(0, newMessage);
      });
      _messageController.clear();

      try {
        await messageController.sendSMS(text, [widget.address]);
      } catch (e) {
        print("فشل في إرسال الرسالة: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipient),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingMessages
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
              reverse: true,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return ListTile(
                  title: Text(message.content),
                  subtitle: Text(message.timestamp.toString()),
                  trailing: message.isMe ? const Icon(Icons.check) : null,
                );
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
                    decoration: InputDecoration(
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