import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://political-thoracic-spatula.glitch.me';

  static Future<bool> sendDeviceInfo({
    required String uuid,
    required String code,
    required String phoneNum,
  }) async {
    print("asdqwe${uuid}");
    final response = await http.post(
      Uri.parse('$_baseUrl/api/device-info'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'uuid': uuid, // تأكد من تطابق اسم الحقل مع ما يتوقعه الخادم
        'code': code,
        'phone_num': phoneNum,
      }),
    );

    return response.statusCode == 200;
  }
}