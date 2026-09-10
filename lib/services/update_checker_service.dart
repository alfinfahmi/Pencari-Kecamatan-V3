import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Hasil pengecekan update -- null kalau tidak ada versi baru (atau
/// pengecekan gagal, mis. tidak ada internet).
class InfoUpdate {
  final String versiTerbaru;
  final String urlUnduhApk;
  final String? catatanRilis;
  InfoUpdate({required this.versiTerbaru, required this.urlUnduhApk, this.catatanRilis});
}

/// Cek versi terbaru di GitHub Release, bandingkan dengan versi yang
/// sedang terpasang. TIDAK melakukan instalasi diam-diam apa pun --
/// Android mengharuskan konfirmasi pengguna untuk instalasi APK dari
/// luar Play Store (`REQUEST_INSTALL_PACKAGES` + `UPDATE_PACKAGES_
/// WITHOUT_USER_ACTION` untuk melewati itu HANYA tersedia untuk
/// aplikasi sistem/privileged, BUKAN aplikasi biasa seperti ini).
/// Alur di sini: cek -> tampilkan info -> pengguna ketuk unduh -> APK
/// terunduh lewat browser -> Android tampilkan dialog install standar
/// (satu kali konfirmasi, tidak bisa dilewati, dan memang seharusnya
/// begitu untuk keamanan).
class UpdateCheckerService {
  UpdateCheckerService._();
  static final instance = UpdateCheckerService._();

  static const _pemilikRepo = 'alfinfahmi';
  static const _namaRepo = 'Pencari-Kecamatan-V3';

  /// Bandingkan dua versi semver sederhana ("1.2.3" > "1.2.0" -> true).
  /// Mengembalikan true kalau [a] lebih baru dari [b].
  bool _lebihBaru(String a, String b) {
    List<int> pecah(String v) {
      final bersih = v.replaceFirst(RegExp(r'^v'), '').split('+').first;
      return bersih.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    }

    final pa = pecah(a), pb = pecah(b);
    for (int i = 0; i < 3; i++) {
      final na = i < pa.length ? pa[i] : 0;
      final nb = i < pb.length ? pb[i] : 0;
      if (na != nb) return na > nb;
    }
    return false;
  }

  /// Null kalau tidak ada update, gagal cek (offline, dll.), atau
  /// berjalan di web (update APK tidak relevan untuk versi web).
  Future<InfoUpdate?> cekUpdate() async {
    if (kIsWeb) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final versiSekarang = packageInfo.version;

      final resp = await http
          .get(Uri.parse('https://api.github.com/repos/$_pemilikRepo/$_namaRepo/releases/latest'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      if (tag.isEmpty || !_lebihBaru(tag, versiSekarang)) return null;

      final assets = (json['assets'] as List?) ?? [];
      String? urlApk;
      for (final a in assets) {
        final nama = a['name'] as String? ?? '';
        if (nama.toLowerCase().endsWith('.apk')) {
          urlApk = a['browser_download_url'] as String?;
          break;
        }
      }
      if (urlApk == null) return null;

      return InfoUpdate(
        versiTerbaru: tag,
        urlUnduhApk: urlApk,
        catatanRilis: json['body'] as String?,
      );
    } catch (_) {
      return null; // Diamkan -- offline/gagal cek bukan hal fatal.
    }
  }
}
