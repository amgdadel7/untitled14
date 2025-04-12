import 'package:flutter/src/widgets/framework.dart';
import 'package:provider/provider.dart';
import 'package:untitled14/services/api_service.dart';

import '../services/device_service.dart';
import '../services/location_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'first_launch_manager.dart';

class RegistrationController {
  static final LocalDatabaseService _localDb = LocalDatabaseService();

  static Future<void> handleRegistration({
    required String countryCode,
    required String phoneNumber,
    required Function(String) onError, required BuildContext context,
  }) async {
    try {
      final uuid = await DeviceService.getUniqueId();

      // تشغيل العمليات بالتوازي باستخدام Future.wait
      final sendFuture = ApiService.sendDeviceInfo(
        uuid: uuid,
        code: countryCode,
        phoneNum: phoneNumber,
      );

      final localDbFuture = _localDb.upsertDeviceInfo(
        uuid: uuid,
        code: countryCode,
        phoneNum: phoneNumber,
      );

      final success = await sendFuture;
      if (!success) throw Exception('فشل إرسال البيانات إلى الخادم');

      await localDbFuture;

      await Provider.of<FirstLaunchManager>(context, listen: false)
          .completeRegistration();

    } catch (e) {
      onError('⚠️ خطأ: ${e.toString()}');
    }
  }
}
class LocalDatabaseService {
  static const _databaseName = 'local_device.db';
  static const _databaseVersion = 1;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (_database != null) return _database!;
    final path = join(await getDatabasesPath(), _databaseName);
    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS device_info (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uuid TEXT UNIQUE NOT NULL,
        code TEXT NOT NULL,
        phone_num TEXT UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    print('تم إنشاء جدول SQLite المحلي');
  }
  Future<String?> getUuid() async {
    final db = await database;
    List<Map> result = await db.query('device_info', columns: ['uuid'], limit: 1);
    return result.isNotEmpty ? result.first['uuid'] as String : null;
  }
  Future<Map<String, String>?> getDeviceInfo() async {
    final db = await database;
    List<Map> result = await db.query(
      'device_info',
      columns: ['uuid', 'phone_num'],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return {
        'uuid': result.first['uuid'] as String,
        'phone_num': result.first['phone_num'] as String,
      };
    }
    return null;
  }

  // Future<void> upsertDeviceInfo({
  //   required String uuid,
  //   required String code,
  //   required String phoneNum,
  // }) async {
  //   try {
  //     final db = await database;
  //     await db.insert(
  //       'device_info',
  //       {
  //         'uuid': uuid,
  //         'code': code,
  //         'phone_num': phoneNum,
  //       },
  //       conflictAlgorithm: ConflictAlgorithm.replace,
  //     );
  //     print('✅ تم حفظ/تحديث البيانات محليًا');
  //   } catch (e) {
  //     print('❌ خطأ في الحفظ المحلي: ${e.toString()}');
  //     throw Exception('فشل في الحفظ المحلي');
  //   }
  // }
  Future<void> upsertDeviceInfo({
    required String uuid,
    required String code,
    required String phoneNum,
  }) async {
    final db = await database;
    await db.rawInsert('''
    INSERT OR REPLACE INTO device_info 
    (uuid, code, phone_num) 
    VALUES (?, ?, ?)
  ''', [uuid, code, phoneNum]);
  }
}
