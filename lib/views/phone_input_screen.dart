import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // استيراد geolocator
import 'package:country_picker/country_picker.dart'; // استيراد country_picker
import 'package:geocoding/geocoding.dart'; // استيراد geocoding
import 'package:untitled14/services/twilio_service.dart'; // استيراد TwilioService
import 'otp_verification_screen.dart'; // استيراد OtpVerificationScreen

class PhoneInputScreen extends StatefulWidget {
  final Function(String phone, String otp) onVerified;

  const PhoneInputScreen({Key? key, required this.onVerified}) : super(key: key);

  @override
  _PhoneInputScreenState createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  final _phoneController = TextEditingController();
  final TwilioService _twilioService = TwilioService();
  bool _isLoading = false;
  Country _selectedCountry = Country(
    phoneCode: '1',
    countryCode: 'US',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'United States',
    example: 'United States',
    displayName: 'United States',
    displayNameNoCountryCode: 'US',
    e164Key: '',
  );

  @override
  void initState() {
    super.initState();
    _determinePosition(); // تحديد الموقع عند بدء التشغيل
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الموقع غير مفعل. يرجى تفعيله.')),
      );
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفض إذن الموقع.')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب تفعيل إذن الموقع يدويًا.')),
      );
      return;
    }

    Position position = await Geolocator.getCurrentPosition();
    _getCountryFromLocation(position); // الحصول على الدولة بناءً على الموقع
  }

  Future<void> _getCountryFromLocation(Position position) async {
    try {
      // استخدام placemarkFromCoordinates من حزمة geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        String countryCode = placemarks.first.isoCountryCode ?? 'US';
        Country? country = Country.tryParse(countryCode);
        if (country != null) {
          setState(() => _selectedCountry = country);
        }
      }
    } catch (e) {
      print('فشل في الحصول على الموقع: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل رقم الهاتف')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            ListTile(
              title: const Text('اختر الدولة'),
              trailing: Text(_selectedCountry.flagEmoji),
              onTap: () {
                showCountryPicker(
                  context: context,
                  onSelect: (Country country) {
                    setState(() => _selectedCountry = country);
                  },
                );
              },
            ),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                prefixText: '+${_selectedCountry.phoneCode} ',
              ),
            ),
            const SizedBox(height: 20),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _sendOTP,
              child: const Text('إرسال الرمز'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendOTP() async {
    setState(() => _isLoading = true);

    final fullNumber = '+${_selectedCountry.phoneCode}${_phoneController.text}';
    final otp = _generateOTP(); // توليد OTP عشوائي

    try {
      // إرسال OTP باستخدام Twilio
      await _twilioService.sendSms(fullNumber, 'Your OTP is $otp');

      // الانتقال إلى شاشة التحقق من OTP
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OtpVerificationScreen(
            phoneNumber: fullNumber,
            otp: otp,
            onVerified: widget.onVerified,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إرسال الرمز: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _generateOTP() {
    return (100000 + Random().nextInt(900000)).toString(); // توليد OTP مكون من 6 أرقام
  }
}