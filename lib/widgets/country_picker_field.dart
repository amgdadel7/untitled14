import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:untitled14/utils/country_code_utils.dart';

class CountryPickerField extends StatelessWidget {
  final String countryCode;
  final ValueChanged<Country> onCountrySelected;

  const CountryPickerField({
    required this.countryCode,
    required this.onCountrySelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      // leading: CountryCodeUtils.getFlagImage(countryCode),
      title: Text('Country Code'),
      subtitle: Text('+${CountryCodeUtils.getPhoneCode(countryCode)}'),
      trailing: Icon(Icons.arrow_drop_down),
      onTap: () => showCountryPicker(
        context: context,
        onSelect: onCountrySelected,
      ),
    );
  }
}