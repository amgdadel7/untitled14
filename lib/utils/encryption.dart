import 'package:pointycastle/export.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class DiffieHellmanHelper {
  // استخدام منحنى إهليلجي (secp256k1)
  // static final ECDomainParameters _params = ECNamedCurve_secp256k1();
  static final ECDomainParameters params = ECDomainParameters('secp256k1');

  // توليد زوج المفاتيح (العام والخاص)
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateKeyPair() {
    final keyGenerator = ECKeyGenerator()
      ..init(ParametersWithRandom(
          ECKeyGeneratorParameters(params), FortunaRandom()));
    return keyGenerator.generateKeyPair();
  }

  // حساب المفتاح المشترك
  static BigInt computeSharedSecret(ECPrivateKey privateKey, ECPublicKey publicKey) {
    final agreement = ECDHBasicAgreement()..init(privateKey);
    return agreement.calculateAgreement(publicKey);
  }


  // تشفير الرسالة باستخدام AES
  static String encryptMessage(String message, String sharedSecret) {
    final key = encrypt.Key.fromUtf8(sharedSecret.padRight(32, '0').substring(0, 32));
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    final encrypted = encrypter.encrypt(message, iv: iv);
    return "${iv.base64}:${encrypted.base64}";
  }

  // فك تشفير الرسالة باستخدام AES
  static String decryptMessage(String encryptedMessage, String sharedSecret) {
    final parts = encryptedMessage.split(':');
    final iv = encrypt.IV.fromBase64(parts[0]);
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
    final key = encrypt.Key.fromUtf8(sharedSecret.padRight(32, '0').substring(0, 32));
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }
}