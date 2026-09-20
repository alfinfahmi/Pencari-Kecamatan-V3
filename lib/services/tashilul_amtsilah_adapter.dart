import 'hisab_detail.dart';
import 'hisab_tashilul_amtsilah_service.dart';

/// Adapter yang menjembatani `HisabTashilulAmtsilahService` (yg antarmukanya
/// berbasis tanggal Hijriah + tanggal-hisab, sesuai desain aslinya di kitab)
/// ke bentuk fungsi yang dipakai `_metodeList` di hisab_awal_bulan_screen.dart
/// & tabel_ijtimak_screen.dart (berbasis `ijtimakUtc`, konsisten dgn
/// As-Syahru/Meeus).
///
/// Konversi Hijriah<->Masehi SEPENUHNYA MANDIRI (kalender tabular, lihat
/// `jdnDariHijriah`/`hijriahDariJdn`/dst di HisabTashilulAmtsilahService)
/// -- TIDAK lagi menumpang HijriService/metode lain sbg jangkar tanggal.
/// Tervalidasi round-trip & thd kasus uji (selisih 1-2 hari dari kalender
/// tabular murni vs hisab sesungguhnya, wajar & diterima).
class TashilulAmtsilahAdapter {
  TashilulAmtsilahAdapter._();

  /// WAJIB dipanggil (await) sekali sebelum [hitung]/[hitungJamIjtimakSaja]/
  /// [cariIjtimakUtc] dipakai -- lihat pemanggilan di initState
  /// hisab_awal_bulan_screen.dart & tabel_ijtimak_screen.dart.
  static Future<void> muatData() => HisabTashilulAmtsilahService.instance.muatDataAwal();

  static bool get sudahSiap => HisabTashilulAmtsilahService.instance.sudahSiap;

  /// Cocok dgn tipe `HasilHisabDetail Function({required DateTime ijtimakUtc,
  /// required double lat, required double lng, required double elevasiM,
  /// required int utcOffset})` yg dipakai `_metodeList`.
  static HasilHisabDetail hitung({
    required DateTime ijtimakUtc,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    // Cari tahun & bulan Hijriah dari ijtimakUtc via konversi kalender
    // tabular MANDIRI (bukan lagi lewat HijriService). Ijtimak yg diberikan
    // adalah AWAL bulan target -- konversi tanggal beberapa jam setelahnya
    // supaya pasti sudah masuk bulan target, bukan akhir bulan sebelumnya.
    final tanggalSetelahIjtimak = ijtimakUtc.add(Duration(hours: utcOffset + 6));
    final jdn = HisabTashilulAmtsilahService.masehiKeJdn(tanggalSetelahIjtimak);
    final hijri = HisabTashilulAmtsilahService.hijriahDariJdn(jdn);

    return HisabTashilulAmtsilahService.instance.hitungLengkapSync(
      tahunHijriah: hijri.tahunH,
      bulanTarget: hijri.bulanH,
      tanggalHisab: 30, // konvensi: hisab dari tanggal 30 bulan sebelumnya
      lintang: lat, bujurLokasi: lng, zonaWaktuJam: utcOffset.toDouble(), elevasiMeter: elevasiM,
    );
  }

  /// Jam ijtimak (desimal, zona lokal [utcOffset]) MURNI hasil Tashilul
  /// Amtsilah sendiri -- dipakai layar Tabel Ijtimak (kolom perbandingan),
  /// TERPISAH dari [hitung] di atas.
  static double hitungJamIjtimakSaja({
    required int tahunH,
    required int bulanH,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    return HisabTashilulAmtsilahService.instance.hitungJamIjtimakSync(
      tahunHijriah: tahunH, bulanTarget: bulanH, tanggalHisab: 30,
      lintang: lat, bujurLokasi: lng, zonaWaktuJam: utcOffset.toDouble(), elevasiMeter: elevasiM,
    );
  }

  /// Ijtimak sbg DateTime UTC penuh, SEPENUHNYA MANDIRI hasil Tashilul
  /// Amtsilah sendiri -- tanggal dari konversi kalender tabular sendiri
  /// (`jdnDariHijriah`), jam dari [hitungJamIjtimakSaja]. Dipakai layar
  /// Tabel Ijtimak (SAMA pola dgn cariIjtimakUtc 3 metode lain, masing2
  /// py cara sendiri cari tanggal+jam independen).
  static DateTime cariIjtimakUtc({
    required int tahunH,
    required int bulanH,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    // Tanggal Masehi utk "awal bulan bulanH" -- via kalender tabular
    // mandiri, hari ke-1 bulan itu.
    final jdnAwalBulanIni = HisabTashilulAmtsilahService.jdnDariHijriah(
      tahunH: tahunH, bulanH: bulanH, tanggalH: 1,
    );
    final tanggalMasehi = HisabTashilulAmtsilahService.jdnKeMasehi(jdnAwalBulanIni);

    final jamLokal = hitungJamIjtimakSaja(
      tahunH: tahunH, bulanH: bulanH, lat: lat, lng: lng, elevasiM: elevasiM, utcOffset: utcOffset,
    );
    final jamBulat = jamLokal.floor();
    final menit = ((jamLokal - jamBulat) * 60).round();
    // Jam ijtimak yg dihitung mengacu ke maghrib SEBELUM tanggal 1 bulan
    // ini (akhir bulan sebelumnya) -- mundur 1 hari dari tanggalMasehi.
    final tanggalIjtimak = tanggalMasehi.subtract(const Duration(days: 1));
    final ijtimakLokal = DateTime(tanggalIjtimak.year, tanggalIjtimak.month, tanggalIjtimak.day, jamBulat, menit);
    return ijtimakLokal.subtract(Duration(hours: utcOffset));
  }
}
