// // import 'package:firebase_messaging/firebase_messaging.dart';
// // import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// //
// // class NotificationService {
// //   static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
// //   static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
// //   FlutterLocalNotificationsPlugin();
// //
// //   static final AndroidNotificationChannel _channel = AndroidNotificationChannel(
// //     'chat_notifications', // channel_id
// //     'Chat Notifications', // channel_name
// //     importance: Importance.high,
// //     description: 'Channel for chat messages',
// //   );
// //
// //
// //
// //   static Future<void> initialize() async {
// //     const AndroidInitializationSettings initializationSettingsAndroid =
// //     AndroidInitializationSettings('@mipmap/ic_launcher');
// //     const DarwinInitializationSettings initializationSettingsIOS =
// //     DarwinInitializationSettings();
// //     final InitializationSettings initializationSettings =
// //     InitializationSettings(
// //       android: initializationSettingsAndroid,
// //       iOS: initializationSettingsIOS,
// //     );
// //
// //     await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
// //
// //     await _flutterLocalNotificationsPlugin
// //         .resolvePlatformSpecificImplementation<
// //         AndroidFlutterLocalNotificationsPlugin>()
// //         ?.createNotificationChannel(_channel);
// //
// //     await _firebaseMessaging.requestPermission(
// //       alert: true,
// //       badge: true,
// //       sound: true,
// //     );
// //
// //     FirebaseMessaging.onMessage.listen(showNotification);
// //   }
// //
// //   static void showNotification(RemoteMessage message) {
// //      AndroidNotificationDetails androidPlatformChannelSpecifics =
// //     AndroidNotificationDetails(
// //       _channel.id,
// //       _channel.name,
// //       importance: Importance.high,
// //       priority: Priority.high,
// //     );
// //
// //     const DarwinNotificationDetails iOSPlatformChannelSpecifics =
// //     DarwinNotificationDetails(
// //       presentAlert: true,
// //       presentBadge: true,
// //       presentSound: true,
// //     );
// //
// //     final NotificationDetails platformChannelSpecifics = NotificationDetails(
// //       android: androidPlatformChannelSpecifics,
// //       iOS: iOSPlatformChannelSpecifics,
// //     );
// //
// //     _flutterLocalNotificationsPlugin.show(
// //       0,
// //       message.notification?.title,
// //       message.notification?.body,
// //       platformChannelSpecifics,
// //     );
// //   }
// // }
// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
// import 'package:firebase_messaging/firebase_messaging.dart';
//
// class NotificationService {
//   static final FlutterLocalNotificationsPlugin _notificationsPlugin =
//   FlutterLocalNotificationsPlugin();
//
//   static Future<void> initialize() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     final InitializationSettings initializationSettings =
//     InitializationSettings(android: initializationSettingsAndroid);
//
//     _notificationsPlugin.initialize(initializationSettings);
//   }
//
//   static void showNotification(RemoteMessage message) {
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//     AndroidNotificationDetails(
//       'high_importance_channel', // تأكد من أن ID القناة صحيح
//       'High Importance Notifications',
//       importance: Importance.high,
//       priority: Priority.high,
//     );
//
//     const NotificationDetails platformChannelSpecifics =
//     NotificationDetails(android: androidPlatformChannelSpecifics);
//
//     _notificationsPlugin.show(
//       0, // ID الإشعار
//       message.notification?.title ?? 'رسالة جديدة',
//       message.notification?.body ?? 'لديك إشعار جديد',
//       platformChannelSpecifics,
//     );
//   }
// }
