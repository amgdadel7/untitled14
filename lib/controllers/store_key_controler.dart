import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'local_keys.db');
    return openDatabase(
      path,
      version: 2, // زيادة الإصدار من 1 إلى 2
      onCreate: onCreate,
    );
  }
  Future<BigInt?> getSharedSecret({
    required String senderUUID,
    required String receiverUUID,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'key_info',
      columns: ['sharedSecret'],
      where: 'senderUUID = ? AND receiverUUID = ?',
      whereArgs: [senderUUID, receiverUUID],
    );
    print("filteredMessages1${result.first['sharedSecret']}");
    return result.isNotEmpty
        ? BigInt.parse(result.first['sharedSecret'] as String)
        : null;
  }
  Future<BigInt?> getSharedSecret1({
    required String senderNUM,
    required String receiverNUM,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'key_info',
      columns: ['sharedSecret'],
      where: 'senderNUM = ? AND receiverNUM = ?',
      whereArgs: [senderNUM, receiverNUM],
    );
    print("filteredMessages1${result.first['sharedSecret']}");
    return result.isNotEmpty
        ? BigInt.parse(result.first['sharedSecret'] as String)
        : null;
  }
  Future<void> onCreate(Database db, int version) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS key_info (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      senderUUID TEXT NOT NULL,
      senderNUM TEXT,
      receiverUUID TEXT NOT NULL,
      receiverNUM TEXT,
      sharedSecret TEXT NOT NULL, 
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(senderUUID, receiverUUID)
    )
  ''');
    print('✅ تم إنشاء جدول key_info محلياً');
  }
  Future<String?>  queryreceiverUUID({
    required String senderUUID,
    required String receiverNUM,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> getkey = await db.query(
      'key_info',
      where: 'senderNUM = ? AND receiverNUM = ?',
      whereArgs: [senderUUID, receiverNUM],
    );

    if (getkey.isEmpty) {
      print('⚠️ No keys found for senderUUID: $senderUUID and receiverNUM: $receiverNUM');
      return null;
    }

    final receiverUUID = getkey[0]['receiverUUID'] as String?;


    return receiverUUID;
  }
  Future<String?> queryreceiverUUID_by_serderUUID({
    required String senderNUM,
    required String receiverNUM,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'key_info',
      where: 'senderNUM = ? AND receiverNUM = ?',
      whereArgs: [senderNUM, receiverNUM],
      limit: 1,
    );

    if (results.isEmpty) return null;

    // تأكيد أن الحقل موجود وأنه من النوع الصحيح
    final receiverUUID = results[0]['receiverUUID']?.toString();
    return receiverUUID;
  }
  Future<String?> queryKeysLocally({
    required String senderUUID,
    required String receiverNUM,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> getkey = await db.query(
      'key_info',
      where: 'senderUUID = ? AND receiverNUM = ?',
      whereArgs: [senderUUID, receiverNUM],
    );

    if (getkey.isEmpty) {
      print('⚠️ No sharedSecret found for senderUUID: $senderUUID ');
      return null;
    }

    final sharedSecret = getkey[0]['sharedSecret'] as String?;
    print('🔑 SharedSecret key is: $sharedSecret');
    return sharedSecret;
  }
  Future<String?> queryKeysLocally1({
    required String senderNUM,
    required String receiverNUM,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> getkey = await db.query(
      'key_info',
      where: 'senderNUM = ? AND receiverNUM = ?',
      whereArgs: [senderNUM, receiverNUM],
    );

    if (getkey.isEmpty) {
      print('⚠️ No sharedSecret found for senderUUID: $senderNUM ');
      return null;
    }

    final sharedSecret = getkey[0]['sharedSecret'] as String?;
    print('🔑 SharedSecret key is: $sharedSecret');
    return sharedSecret;
  }


  // دالة لحفظ المفاتيح محلياً
  Future<void> storeKeysLocally({
    required String senderUUID,
    required String senderNUM,
    required String? receiverUUID,
    required String receiverNUM,
    required BigInt sharedSecret,
  }) async {
    final db = await database;

    final List<Map<String, dynamic>> existing = await db.query(
      'key_info',
      where: 'senderUUID = ? AND receiverUUID = ?',
      whereArgs: [senderUUID, receiverUUID],
    );

    if (existing.isEmpty) {
      await db.insert(
        'key_info',
        {
          'senderUUID': senderUUID,
          'senderNUM':senderNUM,
          'receiverUUID': receiverUUID,
          'receiverNUM': receiverNUM,
          'sharedSecret': sharedSecret.toString(), // التحويل إلى String
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      print('$sharedSecret 🔑 تم حفظ المفاتيح محلياً');
    } else {
      print('المفاتيح موجودة مسبقاً');
    }
  }


  // دالة للتحقق من وجود الجدول
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }
}