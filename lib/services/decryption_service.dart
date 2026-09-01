import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/services.dart' show rootBundle;

/// Dekripsi data_koordinat.enc (AES-256-CBC) saat runtime, khusus build
/// mobile/desktop. TIDAK dipakai di Web (lihat README).
///
/// Skema file: [16 byte IV][ciphertext AES-256-CBC + PKCS7 padding],
/// dihasilkan oleh encrypt_data.py. Kunci di bawah ini HARUS SAMA PERSIS
/// dengan AES_KEY_HEX di encrypt_data.py.
///
/// CATATAN JUJUR: kunci tertanam di kode ini tetap bisa ditemukan lewat
/// decompile oleh pihak yang punya niat & keahlian teknis. Ini menaikkan
/// hambatan, bukan proteksi mutlak. Kombinasikan dengan
/// `flutter build apk --obfuscate --split-debug-info=...` saat rilis.
class DecryptionService {
  static const String _keyHex =
      'e00952e4e57895ffe40aad412019328e55a65381581646caca0ad82156b5f608';

  static Future<String> decryptAsset(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    final iv = enc.IV(Uint8List.fromList(bytes.sublist(0, 16)));
    final ciphertext = bytes.sublist(16);

    final key = enc.Key.fromBase16(_keyHex);
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final decrypted = encrypter.decryptBytes(
      enc.Encrypted(Uint8List.fromList(ciphertext)),
      iv: iv,
    );

    return utf8.decode(decrypted);
  }
}
