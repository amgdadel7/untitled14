import 'package:flutter/material.dart';

import 'conversations_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final String otp;
  final Function(String, String) onVerified;

  const OtpVerificationScreen({
    Key? key,
    required this.phoneNumber,
    required this.onVerified,
    required this.otp,
  }) : super(key: key);

  @override
  _OtpVerificationScreenState createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من الرمز')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text('تم إرسال الرمز إلى ${widget.phoneNumber}'),
            const SizedBox(height: 20),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number, // لوحة مفاتيح رقمية
              maxLength: 6, // الحد الأقصى لطول رمز OTP
              decoration: InputDecoration(
                labelText: 'أدخل الرمز',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _verifyOTP,
              child: const Text('تحقق'),
            ),
          ],
        ),
      ),
    );
  }

  void _verifyOTP() async {
    setState(() => _isLoading = true);

    final enteredOtp = _otpController.text;

    if (enteredOtp == widget.otp) {
      // إذا كان الرمز المدخل صحيحًا
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرمز صحيح!')),
      );

      await Future.delayed(const Duration(seconds: 1));

      // الانتقال إلى شاشة المحادثات
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConversationsScreen(),
        ),
      );

      // استدعاء callback للتحقق
      widget.onVerified(widget.phoneNumber, enteredOtp);
    } else {
      // إذا كان الرمز المدخل غير صحيح
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرمز غير صحيح!')),
      );
    }

    setState(() => _isLoading = false);
  }
}