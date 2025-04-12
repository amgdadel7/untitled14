import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

class CountryCodeUtils {
  static String getPhoneCode(String countryCode) {
    return Country.tryParse(countryCode)?.phoneCode ?? '20';
  }

  static Widget getFlagImage(String countryCode) {
    return Image.asset(
      'flags/${countryCode.toLowerCase()}.png',
      width: 32,
      height: 32,
      package: 'country_picker',
    );
  }
}