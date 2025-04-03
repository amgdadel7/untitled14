import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'dart:convert';

class DiffieHellmanHelper {
  // استخدام منحنى secp256k1
  static final ECDomainParameters params = ECDomainParameters('secp256k1');

  // توليد زوج المفاتيح (العام والخاص)
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateKeyPair() {
    final secureRandom = FortunaRandom();
    final seedSource = Random.secure();
    final seed = List<int>.generate(32, (_) => seedSource.nextInt(256));
    secureRandom.seed(KeyParameter(Uint8List.fromList(seed)));
    final keyGenerator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(params), secureRandom));
    return keyGenerator.generateKeyPair();
  }

  // حساب المفتاح المشترك باستخدام Diffie-Hellman
  static BigInt computeSharedSecret(ECPrivateKey privateKey, ECPublicKey publicKey) {
    print("123$publicKey");
    final agreement = ECDHBasicAgreement()..init(privateKey);
    return agreement.calculateAgreement(publicKey);
  }

  // اشتقاق مفتاح AES من المفتاح المشترك باستخدام SHA-256
  static String deriveAESKey(BigInt sharedSecret) {
    var bytes = utf8.encode(sharedSecret.toString());
    var digest = sha256.convert(bytes);
    return digest.toString(); // هذا المفتاح مناسب لتشفير AES
  }

  // تشفير الرسالة باستخدام AES (CBC)
  static String encryptMessage(String message, String sharedSecret) {
    String aesKey = deriveAESKey(BigInt.parse(sharedSecret));
    final key = encrypt.Key.fromUtf8(aesKey.substring(0, 32));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(message, iv: iv);
    return "${iv.base64}:${encrypted.base64}";
  }

  // فك تشفير الرسالة باستخدام AES (CBC)
  static String decryptMessage(String encryptedMessage, String sharedSecret) {
    String aesKey = deriveAESKey(BigInt.parse(sharedSecret));
    final parts = encryptedMessage.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final key = encrypt.Key.fromUtf8(aesKey.substring(0, 32));
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }
}
