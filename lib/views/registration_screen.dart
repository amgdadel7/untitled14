import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:untitled14/utils/country_code_utils.dart';
import 'package:untitled14/utils/validators.dart';
import '../widgets/country_picker_field.dart';
import '../controllers/registration_controller.dart';
import '../services/location_service.dart';
import '../controllers/first_launch_manager.dart';

class RegistrationScreen extends StatefulWidget {
  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _countryCode = 'EG';
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _setupAnimations();
    _autoDetectCountry();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );
    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  Future<void> _requestLocationPermission() async {
    final status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _autoDetectCountry() async {
    final code = await LocationService.getCountryCodeByGPS();
    if (code != null && mounted) {
      setState(() => _countryCode = code);
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    _animationController.reverse();

    try {
      await RegistrationController.handleRegistration(
        countryCode: '+${CountryCodeUtils.getPhoneCode(_countryCode)}',
        phoneNumber: _phoneController.text,
        context: context, // أضف هذا السطر
        onError: (error) => _showErrorDialog(error),
      );

      await Provider.of<FirstLaunchManager>(context, listen: false)
          .completeRegistration();

      Navigator.pushReplacementNamed(context, '/home');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Error Occurred'),
        content: Text(error),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('OK'),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.blue.shade800, Colors.blue.shade400],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(32),
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildFormCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'Get Started',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 30),
              // In your RegistrationScreen build method
              CountryPickerField(
                countryCode: _countryCode, // Pass current country code

                onCountrySelected: (country) => setState(() {
                  _countryCode = country.countryCode;
                }),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: TextStyle(fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefix: Text(
                    '+${CountryCodeUtils.getPhoneCode(_countryCode)} ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                validator: (value) => Validators.validatePhoneNumber(value),
              ),
              SizedBox(height: 30),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: _isLoading ? 60 : 200,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        borderRadius: BorderRadius.circular(_isLoading ? 30 : 10),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          )
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          primary: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_isLoading ? 30 : 10),
          ),
        ),
        child: _isLoading
            ? CircularProgressIndicator(color: Colors.white)
            : Text(
          'Start Now',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
// In your CountryPickerField widget file
// class CountryPickerField extends StatelessWidget {
//   final String countryCode;
//   final ValueChanged<Country> onCountrySelected;
//
//   const CountryPickerField({
//     required this.countryCode,
//     required this.onCountrySelected,
//   });
//
//   void _selectCountry(BuildContext context) async {
//     final country = await showCountryPicker(
//       context: context,
//       showPhoneCode: true, onSelect: (Country value) {  },
//     );
//     if (country != null) {
//       onCountrySelected(country);
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return ListTile(
//       isDense: true, // Properly placed isDense parameter
//       minVerticalPadding: 0,
//       contentPadding: EdgeInsets.zero,
//       leading: SizedBox(
//         height: 32,
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Image.asset(
//               'assets/flags/${countryCode.toLowerCase()}.png',
//               width: 24,
//               height: 24,
//             ),
//             const SizedBox(width: 8),
//             const Icon(Icons.arrow_drop_down, size: 20),
//           ],
//         ),
//       ),
//       title: Text('Country Code'),
//       subtitle: Text('+${CountryCodeUtils.getPhoneCode(countryCode)}'),
//       onTap: () => _selectCountry(context),
//     );
//   }
// }