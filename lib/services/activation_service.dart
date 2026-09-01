import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Proteksi aktivasi sederhana & offline sesuai kesepakatan final:
/// - Satu serial number tunggal: "falak" (tidak peka huruf besar/kecil).
/// - Dibandingkan dalam bentuk hash SHA-256, bukan teks polos, agar tidak
///   langsung terlihat lewat `strings` pada binari hasil build.
/// - Sekali aktivasi berhasil, status tersimpan lokal (Hive) sehingga
///   aplikasi tidak meminta input ulang.
///
/// CATATAN JUJUR (baca README): ini BUKAN proteksi keamanan kuat, terutama
/// pada build Web di mana seluruh kode dapat dilihat lewat DevTools. Untuk
/// mobile/desktop, kombinasikan dengan:
///   flutter build apk --obfuscate --split-debug-info=build/symbols
/// agar nama variabel & alur logika tersamar dari decompile kasar.
class ActivationService {
  static const _boxName = 'app_status';
  static const _keyActivated = 'is_activated';

  // SHA-256("falak") — dihitung sekali, tidak pernah menyimpan kata
  // aslinya di dalam kode.
  static const String expectedHash =
      '336def2a41fea85e12a7a5ccc0d5b633759b89be3080efee7219994667d23476';

  /// Fungsi murni (tidak menyentuh storage), sengaja dipisah supaya bisa
  /// diuji langsung lewat unit test tanpa perlu inisialisasi Hive.
  /// Perbandingan tidak peka huruf besar/kecil.
  static bool verifySerial(String input) {
    final normalized = input.trim().toLowerCase();
    final hash = sha256.convert(utf8.encode(normalized)).toString();
    return hash == expectedHash;
  }

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) {
      return Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  Future<bool> isActivated() async {
    final box = await _box();
    return box.get(_keyActivated, defaultValue: false) as bool;
  }

  /// Mengembalikan true jika serial number cocok, dan langsung menyimpan
  /// status aktivasi.
  Future<bool> tryActivate(String input) async {
    if (verifySerial(input)) {
      final box = await _box();
      await box.put(_keyActivated, true);
      return true;
    }
    return false;
  }

  Future<void> resetActivation() async {
    final box = await _box();
    await box.put(_keyActivated, false);
  }
}
