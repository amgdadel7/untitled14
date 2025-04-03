import 'package:twilio_flutter/twilio_flutter.dart';

class TwilioService {
  final TwilioFlutter twilio;

  TwilioService()
      : twilio = TwilioFlutter(
    accountSid: 'AC2a6e4bb201a14b7698f9ee52bb447959', // استبدل بقيمك
    authToken: '83b3fb28bfdd54272cae2347cde35c42', // استبدل بقيمك
    twilioNumber: '+19122507882', // استبدل بقيمك
  );

  Future<void> sendSms(String toNumber, String message) async {
    try {
      final response = await twilio.sendSMS(
        toNumber: toNumber,
        messageBody: message,
      );
      print('SMS Sent: $response');
    } catch (e) {
      print('Failed to send SMS: $e');
      rethrow; // إعادة رمي الخطأ للتعامل معه في الواجهة
    }
  }
}