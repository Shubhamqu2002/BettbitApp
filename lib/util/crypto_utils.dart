// lib/util/crypto_utils.dart
import 'package:encrypt/encrypt.dart' as encrypt;

const String _aesKey = '7E892875A52C59A3B588306B13C31FBD';
const String _aesIv = 'XYE45DKJ0967GFAZ';

/// Encrypt text using AES-256-CBC (PKCS7) and return Base64
String encryptText(String plainText) {
  if (plainText.isEmpty) return '';

  final key = encrypt.Key.fromUtf8(_aesKey); // 32 bytes => 256-bit
  final iv = encrypt.IV.fromUtf8(_aesIv);    // 16 bytes IV
  final aes = encrypt.Encrypter(
    encrypt.AES(
      key,
      mode: encrypt.AESMode.cbc,
      padding: 'PKCS7',
    ),
  );

  final encrypted = aes.encrypt(plainText, iv: iv);
  return encrypted.base64;
}

/// Decrypt Base64 AES text (optional helper)
String? decryptText(String cipherBase64) {
  if (cipherBase64.isEmpty) return null;

  final key = encrypt.Key.fromUtf8(_aesKey);
  final iv = encrypt.IV.fromUtf8(_aesIv);
  final aes = encrypt.Encrypter(
    encrypt.AES(
      key,
      mode: encrypt.AESMode.cbc,
      padding: 'PKCS7',
    ),
  );

  try {
    final encrypted = encrypt.Encrypted.fromBase64(cipherBase64);
    final decrypted = aes.decrypt(encrypted, iv: iv);
    return decrypted;
  } catch (_) {
    return null;
  }
}
