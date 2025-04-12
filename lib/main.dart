import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'controllers/first_launch_manager.dart';
import 'controllers/message_controller.dart';
import 'views/conversations_screen.dart';
import 'views/registration_screen.dart';
void _showPermissionDialog() async {
  await openAppSettings();
}
Future<bool> _requestPermissions() async {
  final permissions = [
    Permission.contacts,
    Permission.location,
    Permission.phone,
    Permission.sms,
  ];

  final results = await permissions.request();

  return results.values.every((status) => status.isGranted);
}
class PermissionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('الرجاء منح الأذونات المطلوبة'),
            ElevatedButton(
              onPressed: () => openAppSettings(),
              child: Text('فتح الإعدادات'),
            ),
          ],
        ),
      ),
    );
  }
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final permissionsGranted = await _requestPermissions();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FirstLaunchManager()),
        ChangeNotifierProvider(create: (_) => MessageController()..initDatabases()),
      ],
      child: MyApp(permissionsGranted: permissionsGranted),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool permissionsGranted;

  const MyApp({Key? key, required this.permissionsGranted}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: permissionsGranted
          ? _buildMainScreen(context)
          : PermissionScreen(),
    );
  }

  Widget _buildMainScreen(BuildContext context) {
    return Consumer<FirstLaunchManager>(
      builder: (context, launchManager, child) {
        return launchManager.isFirstLaunch
            ? RegistrationScreen()
            : ConversationsScreen();
      },
    );
  }
}
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => FirstLaunchManager()),
//         ChangeNotifierProvider(create: (_) => MessageController()..initDatabases()),
//       ],
//       child: MyApp(),
//     ),
//   );
// }
//
// class MyApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Secure Messenger',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       initialRoute: '/',
//       routes: {
//         '/': (context) => Consumer<FirstLaunchManager>(
//           builder: (context, launchManager, child) {
//             return launchManager.isFirstLaunch
//                 ? RegistrationScreen()
//                 : ConversationsScreen();
//           },
//         ),
//         '/home': (context) => ConversationsScreen(),
//       },
//     );
//   }
// }
