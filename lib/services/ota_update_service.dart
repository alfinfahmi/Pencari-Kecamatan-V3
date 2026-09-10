import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// Layanan OTA (over-the-air) update lewat Shorebird -- cek & terapkan
/// patch Dart di latar belakang, TANPA perlu pengguna unduh APK baru.
///
/// **PRASYARAT WAJIB sebelum ini bisa berfungsi** (belum otomatis lewat
/// kode ini saja):
/// 1. Akun Shorebird (shorebird.dev) + `shorebird login` di komputer Anda
/// 2. `shorebird init` di root project -- ini membuat `shorebird.yaml`
///    berisi app_id milik akun Anda (WAJIB di-commit ke repo)
/// 3. APK dibangun lewat `shorebird release android` (BUKAN
///    `flutter build apk` biasa) untuk rilis pertama, lalu
///    `shorebird patch android` untuk tiap pembaruan berikutnya
/// 4. Token API (dari Console Shorebird -> Account -> API Keys) disimpan
///    sebagai GitHub Secret `SHOREBIRD_TOKEN` untuk dipakai CI
///
/// **Batasan penting:** Shorebird CUMA bisa menambal kode Dart. Perubahan
/// izin aplikasi (mis. izin kamera), package native baru, atau perubahan
/// `AndroidManifest.xml`/`Info.plist` TETAP butuh rilis APK baru biasa
/// lewat toko aplikasi/distribusi manual -- tidak bisa lewat OTA ini.
///
/// **Tanpa langkah 1-4 di atas** (mis. APK dibangun dengan `flutter
/// build apk` biasa seperti workflow CI kita saat ini), memanggil fungsi
/// di kelas ini aman (tidak akan crash, cuma selalu melaporkan "tidak
/// ada pembaruan") -- TAPI aplikasi memang belum benar-benar OTA sampai
/// prasyarat di atas dipenuhi.
class OtaUpdateService {
  OtaUpdateService._();

  static final _updater = ShorebirdUpdater();

  /// True kalau aplikasi ini sungguhan dibangun lewat Shorebird (`shorebird
  /// release`) -- false kalau lewat `flutter build` biasa (mis. web, atau
  /// APK yang belum di-setup Shorebird). Dipakai untuk diam-diam melewati
  /// pengecekan OTA sama sekali di kondisi itu, bukan menampilkan error.
  static bool get tersedia => !kIsWeb && _updater.isAvailable;

  /// Cek apakah ada patch baru yang siap diterapkan. Mengembalikan null
  /// kalau OTA tidak tersedia (lihat [tersedia]) atau terjadi error --
  /// SELALU aman dipanggil, tidak pernah melempar exception ke pemanggil.
  static Future<UpdateStatus?> cekPembaruan() async {
    if (!tersedia) return null;
    try {
      return await _updater.checkForUpdate();
    } catch (_) {
      return null;
    }
  }

  /// Unduh & terapkan patch yang tersedia (butuh restart aplikasi supaya
  /// kode baru aktif -- restart TIDAK dilakukan otomatis oleh fungsi ini,
  /// cuma menyiapkan patch-nya). Mengembalikan true kalau berhasil.
  static Future<bool> terapkanPembaruan() async {
    if (!tersedia) return false;
    try {
      await _updater.update();
      return true;
    } catch (_) {
      return false;
    }
  }
}
