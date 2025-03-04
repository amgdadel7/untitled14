import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'controllers/message_controller.dart';
import 'views/conversations_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MessageController()),
      ],
      child: const MyApp(),
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