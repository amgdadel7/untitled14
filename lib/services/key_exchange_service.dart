import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/conversation_key.dart';

class KeyExchangeService {
  // عنوان الخادم الخاص بتبادل المفاتيح
  final String serverUrl = "https://quilted-odd-palm.glitch.me/api/key_exchange";

  /// ترسل المفتاح العام إلى الخادم مع عنوان الطرف
  /// ويتوقع الخادم إعادة المفتاح العام للطرف الآخر (إن وجد) وأيضاً يمكن أن يحسب المفتاح المشترك
  Future<ConversationKey?> sendPublicKey(String address, String publicKey) async {
    try {
      print("📤 جاري إرسال المفتاح العام إلى الخادم...");

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "address": address,
          "public_key": publicKey,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ تم إرسال المفتاح بنجاح واستلمنا ردًا من الخادم.");
        print("📌 المفتاح العام للطرف الآخر: ${data["their_public_key"]}");
        print("🔒 المفتاح المشترك المستلم: ${data["shared_secret"]}");

        return ConversationKey(
          address: address,
          ownPrivateKey: "",
          ownPublicKey: publicKey,
          theirPublicKey: data["their_public_key"],
          sharedSecret: data["shared_secret"],
        );
      } else {
        print("❌ فشل إرسال المفتاح. كود الاستجابة: ${response.statusCode}");
        print("⚠️ تفاصيل الخطأ: ${response.body}");
        return null;
      }
    } catch (e) {
      print("🚨 استثناء أثناء تبادل المفاتيح: $e");
      return null;
    }
  }
}
