import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<String?> getCountryCodeByGPS() async {
    try {
      // التحقق من تفعيل خدمة الموقع
      final isLocationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!isLocationEnabled) return null;

      // الحصول على الإحداثيات الحالية
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // تحويل الإحداثيات إلى رمز الدولة
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isEmpty) return null;
      return placemarks.first.isoCountryCode;
    } catch (e) {
      print("Error getting country code: $e");
      return null;
    }
  }
}