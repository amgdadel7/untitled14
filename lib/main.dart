// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
// import 'package:country_picker/country_picker.dart';
// import 'package:sqflite/sqflite.dart';
// import 'package:path/path.dart';
// import 'package:permission_handler/permission_handler.dart';
// import 'controllers/message_controller.dart';
// import 'views/conversations_screen.dart';
// import 'views/phone_input_screen.dart';
// import 'views/otp_verification_screen.dart';
// import 'package:firebase_core/firebase_core.dart';
//
// class DatabaseHelper {
//   static final DatabaseHelper instance = DatabaseHelper._init();
//   static Database? _database;
//
//   DatabaseHelper._init();
//
//   Future<Database> get database async {
//     if (_database != null) return _database!;
//     _database = await _initDB('my_database.db');
//     return _database!;
//   }
//
//   Future<Database> _initDB(String filePath) async {
//     final dbPath = await getDatabasesPath();
//     final path = join(dbPath, filePath);
//
//     return await openDatabase(path, version: 1, onCreate: _createDB);
//   }
//
//   Future _createDB(Database db, int version) async {
//     await db.execute('''
//       CREATE TABLE myphonenum (
//         id INTEGER PRIMARY KEY AUTOINCREMENT,
//         phone_number TEXT,
//         otp TEXT
//       )
//     ''');
//   }
//
//   Future<bool> isTableEmpty() async {
//     final db = await instance.database;
//     final result = await db.rawQuery('SELECT COUNT(*) FROM myphonenum');
//     return Sqflite.firstIntValue(result) == 0;
//   }
//
//   Future<void> savePhoneNumber(String phone, String otp) async {
//     final db = await instance.database;
//     await db.insert('myphonenum', {'phone_number': phone, 'otp': otp});
//   }
// }
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(); // تهيئة Firebase
//
//   // طلب الصلاحيات
//   await requestPermissions();
//
//   final dbHelper = DatabaseHelper.instance;
//   final isEmpty = await dbHelper.isTableEmpty();
//
//   runApp(
//     MultiProvider(
//       providers: [
//         ChangeNotifierProvider(create: (_) => MessageController()..initDatabases()),
//       ],
//       child: MyApp(showAuth: isEmpty),
//     ),
//   );
// }
//
// Future<void> requestPermissions() async {
//   await Permission.contacts.request();
//   await Permission.sms.request();
//   await Permission.location.request();
//   await Permission.phone.request();
//   await Permission.storage.request();
// }
//
// class MyApp extends StatelessWidget {
//   final bool showAuth;
//
//   const MyApp({Key? key, required this.showAuth}) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'SMS App',
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: showAuth
//           ? PhoneInputScreen(
//         onVerified: (phone, otp) async {
//           await DatabaseHelper.instance.savePhoneNumber(phone, otp);
//           Navigator.pushReplacement(
//             context,
//             MaterialPageRoute(builder: (_) => const ConversationsScreen()),
//           );
//         },
//       )
//           : const ConversationsScreen(),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/message_controller.dart';
import 'views/conversations_screen.dart';
import 'package:sms_advanced/sms_advanced.dart' as sms_advanced;


void main() {
  sms_advanced.SmsReceiver receiver = new sms_advanced.SmsReceiver();
  receiver.onSmsReceived!.listen((sms_advanced.SmsMessage msg) => print("sssssssss$msg.body"));
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MessageController()..initDatabases()),
      ],
      child:  MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SMS App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home:  ConversationsScreen(), // Set ConversationsScreen as the home screen
    );
  }
}