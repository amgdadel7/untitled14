import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class LocalKeyManager {
  static final _iv = encrypt.IV.fromLength(16);
  static const _encryptionKey = 'your-32-byte-encryption-key';

  static Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), 'local_keys.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shared_secrets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            partner_uuid TEXT NOT NULL,
            partner_phone TEXT NOT NULL,
            shared_secret TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        ''');
      },
    );
  }

  static Future<void> saveSharedSecret({
    required String partnerUUID,
    required String partnerPhone,
    required String sharedSecret,
  }) async {
    final db = await _initDatabase();

    // تشفير sharedSecret قبل التخزين
    final encrypter = encrypt.Encrypter(
        encrypt.AES(encrypt.Key.fromUtf8(_encryptionKey))
    );

    final encryptedSecret = encrypter.encrypt(sharedSecret, iv: _iv).base64;

    await db.insert('shared_secrets', {
      'partner_uuid': partnerUUID,
      'partner_phone': partnerPhone,
      'shared_secret': encryptedSecret,
    });
  }

  static Future<String?> getSharedSecret(String partnerUUID) async {
    final db = await _initDatabase();
    final result = await db.query(
      'shared_secrets',
      where: 'partner_uuid = ?',
      whereArgs: [partnerUUID],
    );

    if (result.isEmpty) return null;

    // فك التشفير
    final encrypter = encrypt.Encrypter(
        encrypt.AES(encrypt.Key.fromUtf8(_encryptionKey))
    );

    return encrypter.decrypt(
        encrypt.Encrypted.fromBase64(result.first['shared_secret'] as String),
        iv: _iv
    );
  }
}