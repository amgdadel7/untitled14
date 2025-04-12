import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:convert/convert.dart';

class DiffieHellmanHelper {
  // استخدام منحنى secp256k1
  static final ECDomainParameters params = ECDomainParameters('secp256k1');

  static AsymmetricKeyPair<PublicKey, PrivateKey> generateKeyPair() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seed = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));

    final keyGenerator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(params), secureRandom));

    return keyGenerator.generateKeyPair();
  }

  // دالة جديدة لتحويل المفتاح العام إلى تنسيق HEX غير مضغوط
  static String encodePublicKey(ECPublicKey publicKey) {
    final x = publicKey.Q!.x!.toBigInteger();
    final y = publicKey.Q!.y!.toBigInteger();

    // تحويل الإحداثيات إلى سداسي عشر مع padding لضمان 64 حرف لكل منهما
    final xHex = x?.toRadixString(16).padLeft(64, '0');
    final yHex = y?.toRadixString(16).padLeft(64, '0');

    return '04$xHex$yHex'; // 04 + 64 + 64 = 130 حرف
  }

  // حساب المفتاح المشترك باستخدام Diffie-Hellman
  static BigInt computeSharedSecret(ECPrivateKey privateKey, ECPublicKey publicKey) {
    print("123$publicKey");
    final agreement = ECDHBasicAgreement()..init(privateKey);
    return agreement.calculateAgreement(publicKey);
  }

  // اشتقاق مفتاح AES من المفتاح المشترك باستخدام SHA-256
  static String deriveAESKey(BigInt sharedSecret) {
    final bytes = sharedSecret.toRadixString(16).padLeft(64, '0').codeUnits;
    final digest = sha256.convert(bytes);
    return hex.encode(digest.bytes);
    // var bytes = utf8.encode(sharedSecret.toString());
    // var digest = sha256.convert(bytes);
    // return digest.toString(); // هذا المفتاح مناسب لتشفير AES
  }
  static String getPublicKey(ECPublicKey publicKey) {
    final encoded = publicKey.Q!.getEncoded(false); // uncompressed format
    return hex.encode(encoded);
  }
  // تشفير الرسالة باستخدام AES (CBC)
  static String encryptMessage(String message, BigInt sharedSecret) {
    // String aesKey = deriveAESKey(BigInt.parse(sharedSecret));
    String aesKey = deriveAESKey(sharedSecret);
    final key = encrypt.Key.fromUtf8(aesKey.substring(0, 32));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(message, iv: iv);
    return "${iv.base64}:${encrypted.base64}";
  }

  // فك تشفير الرسالة باستخدام AES (CBC)
  static String decryptMessage(String encryptedMessage, String sharedSecret) {
    String aesKey = deriveAESKey(BigInt.parse(sharedSecret));
    print("aesKey$aesKey");
    final parts = encryptedMessage.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final key = encrypt.Key.fromUtf8(aesKey.substring(0, 32));
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }
  // static String decryptMessage(String encryptedMessage, String sharedSecret) {
  //   try {
  //     // اشتقاق مفتاح AES من المفتاح المشترك
  //     String aesKey = deriveAESKey(BigInt.parse(sharedSecret));
  //     // تقسيم الرسالة إلى IV والبيانات المشفرة
  //     final parts = encryptedMessage.split(':');
  //     if (parts.length != 2) {
  //       throw FormatException("صيغة الرسالة غير صحيحة. يجب أن تكون IV:encryptedData");
  //     }
  //     final ivBase64 = parts[0].trim();
  //     final cipherTextBase64 = parts[1].trim();
  //
  //     // تسجيل القيم للتأكد من صحتها
  //     print("IV (base64): $ivBase64");
  //     print("CipherText (base64): $cipherTextBase64");
  //
  //     final iv = encrypt.IV.fromBase64(ivBase64);
  //     final encrypted = encrypt.Encrypted.fromBase64(cipherTextBase64);
  //     final key = encrypt.Key.fromUtf8(aesKey.substring(0, 32));
  //
  //     // إنشاء المحرك وتحديد وضع AES CBC مع PKCS7
  //     final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
  //     return encrypter.decrypt(encrypted, iv: iv);
  //   } catch (e) {
  //     print("فشل في فك تشفير الرسالة: $e");
  //     rethrow; // أو يمكنك إعادة قيمة مناسبة
  //   }
  // }
}
