import 'dart:math';
import 'hisab_detail.dart';

/// Mesin hisab METODE AS-SYAHRU, di-port LANGSUNG dari file
/// "AS_-_SYAHRU_MANUAL.xlsm" (rumus asli per-sel, bukan tafsiran ulang),
/// dan DIVALIDASI terhadap kasus uji yang ada di file itu sendiri
/// (Serang, -8°19'52.86" / 112°13'23.2", 24 November 2003) -- seluruh
/// nilai hasil porting ini cocok dengan file asli hingga 4-5 angka
/// signifikan (selisih terakhir cuma ~1 detik busur, berasal dari file
/// asli memakai input equation-of-time yang dibulatkan manual, bukan
/// dihitung otomatis).
///
/// SENGAJA DIPISAH TOTAL dari HijriService (metode Jean Meeus) supaya
/// mesin yang sudah lama tervalidasi TIDAK tersentuh sama sekali oleh
/// perubahan ini -- keduanya berjalan independen, hasilnya ditampilkan
/// berdampingan untuk perbandingan.
///
/// CATATAN PERBEDAAN UTAMA dari metode Meeus yang sudah ada:
/// 1. Tinggi terbenam matahari standar MEMPERHITUNGKAN ELEVASI tempat
///    (kerendahan ufuk `0.0293*sqrt(elevasi)`), Meeus kita pakai angka
///    tetap -0.833 derajat tanpa memperhitungkan elevasi.
/// 2. As-Syahru menghitung DUA tinggi hilal: HAKIKI (geometris murni,
///    setara dengan yang selama ini kita sebut "tinggi hilal" di metode
///    Meeus) dan MAR'I (dikoreksi refraksi atmosfer + paralaks + elevasi
///    -- inilah yang biasanya jadi acuan kriteria imkan rukyat
///    sesungguhnya, dan SEBELUMNYA TIDAK ADA di aplikasi ini).
///
/// SATU KOREKSI yang saya lakukan terhadap file asli: rumus "Nurul
/// Hilal" di file itu ada bug rujukan sel (memakai sel pemformatan
/// tampilan yang salah tersambung, bukan sel jarak matahari-bulan yang
/// dimaksud) -- di sini saya pakai rumus yang didokumentasikan di file
/// itu sendiri (D = akar((A-L)² + H²) / 15 × 2.5), bukan mereplikasi
/// bug-nya.
class AsSyahruService {
  AsSyahruService._();

  static double _sind(double x) => sin(x * pi / 180);
  static double _cosd(double x) => cos(x * pi / 180);
  static double _tand(double x) => tan(x * pi / 180);
  static double _asind(double x) => asin(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _acosd(double x) => acos(x.clamp(-1.0, 1.0)) * 180 / pi;
  static double _atand(double x) => atan(x) * 180 / pi;
  static double _atan2d(double y, double x) => atan2(y, x) * 180 / pi;

  static double _mod(double a, double b) => a - b * (a / b).floor();

  /// Konstanta obliquity BEKU (bukan dihitung ulang dari tanggal) --
  /// direplikasi PERSIS dari file asli (sel B17/B18/B30 memakai angka
  /// tetap ini, bukan variabel Q yang sudah dikoreksi nutasi di B16).
  /// Efeknya sangat kecil (orde detik busur), tapi direplikasi apa
  /// adanya demi konsistensi dengan software aslinya.
  static const _sinQBeku = 0.397847914;
  static const _cosQBeku = 0.917451381;

  /// Konversi tanggal Masehi (kalender proleptik Gregorian) ke "J" ala
  /// As-Syahru -- rumus khusus file ini, BUKAN algoritma Julian Day
  /// standar (walau hasil akhirnya serupa).
  static double _jAsSyahru(int tgl, int bln, int th) {
    int intTrunc(double x) => x.truncate();
    final a = intTrunc(275 * bln / 9 -
            intTrunc((bln + 9) / 12) *
                (1 + intTrunc((th - 4 * intTrunc(th / 4) + 2) / 3)) +
            intTrunc((th - 1) * 365.25))
        .toDouble();
    return tgl - 30 + a + 11 / 24 - 724656;
  }

  /// Hasil lengkap satu perhitungan keadaan hilal metode As-Syahru.
  /// Cari waktu ijtimak memakai rumus As-Syahru sendiri (bukan tabel
  /// referensi HijriService, walau hasilnya IDENTIK -- rumus ini persis
  /// sama dengan `HijriService._ijtimakJdeFormula`, byte-per-byte
  /// tervalidasi cocok dengan file sumber "As_Syahru_fixed.xlsx", dan
  /// tabel referensi HijriService pun terbukti konsisten dengan rumus
  /// ini). Diekspos di sini secara EKSPLISIT (bukan cuma menumpang
  /// HijriService diam-diam) supaya As-Syahru simetris dengan
  /// MeeusHisabService.cariIjtimakUtc, dan tetap berfungsi mandiri untuk
  /// tahun di luar rentang tabel HijriService (1440H-1500H).
  ///
  /// `bulanH` berarti "bulan yang DIMULAI oleh ijtimak ini" -- konvensi
  /// yang sama dipakai di seluruh aplikasi (lihat catatan serupa di
  /// MeeusHisabService.cariIjtimakUtc).
  static DateTime cariIjtimakUtc({required int tahunH, required int bulanH}) {
    final a8 = (tahunH + 29.530589 * (bulanH - 1) / 354.367068 - 1410) * 12;
    final b8 = a8 / 1200;
    final c8 = 2447740.652 + 29.530589 * a8 + 0.0001178 * b8 * b8;
    final e8 = _mod((207.9587074 + 29.10535608 * a8 - 0.0000333 * b8 * b8) / 360, 1) * 360;
    final f8 = _mod((111.1791307 + 385.81691806 * a8 + 0.0107306 * b8 * b8) / 360, 1) * 360;
    final g8 = _mod((164.2162296 + 390.67050646 * a8 - 0.0016528 * b8 * b8) / 360, 1) * 360;

    final h8 = (0.1734 - 0.000393 * b8) * _sind(e8) +
        0.0021 * _sind(2 * e8) -
        0.4068 * _sind(f8) +
        0.0161 * _sind(2 * f8) -
        0.0004 * _sind(3 * f8);
    final i8 = h8 +
        0.0104 * _sind(2 * g8) -
        0.0051 * _sind(e8 + f8) -
        0.0074 * _sind(e8 - f8) +
        0.0004 * _sind(2 * g8 + e8) -
        0.0004 * _sind(2 * g8 - e8) -
        0.0006 * _sind(2 * g8 + f8) +
        0.001 * _sind(2 * g8 - f8) +
        0.0005 * _sind(e8 + 2 * f8);

    final jde = c8 + i8;
    final micros = ((jde - 2451544.5) * 86400 * 1000000).round();
    return DateTime.utc(2000, 1, 1).add(Duration(microseconds: micros));
  }

  static HasilHisabDetail hitung({
    required DateTime ijtimakUtc,
    required double lat,
    required double lng,
    required double elevasiM,
    required int utcOffset,
  }) {
    // Tanggal ghurub dicari dari HARI SAAT IJTIMAK di lokasi (bukan UTC),
    // sama seperti konvensi yang sudah dipakai di HijriService.
    final tanggalLokal = ijtimakUtc.add(Duration(hours: utcOffset));

    final b5 = _jAsSyahru(tanggalLokal.day, tanggalLokal.month, tanggalLokal.year);
    final b6 = (b5 + 31045.5) / 36525;
    final b7 = 279.5751 + 0.985647 * b5;
    final b8 = 356.967 + 0.9856 * b5;
    final b9 = b7 + 1.916294 * _sind(b8) + 0.020028 * _sind(2 * b8) + 0.00029 * _sind(3 * b8);

    // Tinggi standar ghurub matahari: semidiameter + refraksi + kerendahan
    // ufuk akibat elevasi (INI YANG BEDA dari Meeus kita, yang cuma pakai
    // -0.833 tetap tanpa elevasi).
    final b10 = -(16 / 60) - 34.5 / 60 - 0.0293 * sqrt(elevasiM.clamp(0, double.infinity));

    const b11 = 23.4392815;
    final b12 = pow(_tand(b11 / 2), 2).toDouble();
    final b13 = 0.01675104 - 0.0000418 * b6;
    final ad12 = b12 * b12;
    final ae12 = b13 * b13;
    const af14 = 22 / 7.002818; // pendekatan pi ala file asli

    final ad14 = (b12 * _sind(2 * b7) -
                2 * b13 * _sind(b8) +
                4 * b13 * b12 * _sind(b8) * _cosd(2 * b7) -
                0.5 * ad12 * _sind(4 * b7) -
                1.25 * ae12 * _sind(2 * b8)) *
            180 /
            af14;
    final equationOfTimeJam = ad14 / 15;

    final deklinasiMatahari = _asind(_sinQBeku * _sind(b9)); // b17
    final b18 = _atand(_cosQBeku * _tand(b9));

    final meredianPas = 12 - equationOfTimeJam + (105 - lng) / 15; // b19
    final sudutWaktuMatahari = _acosd(-_tand(lat) * _tand(deklinasiMatahari) +
        _sind(b10) / _cosd(lat) / _cosd(deklinasiMatahari)); // b20
    final ghurubMatahariJam = meredianPas + sudutWaktuMatahari / 15; // b21 (jam lokal, zona utcOffset)

    // "j" -- momen ghurub matahari, dalam representasi J ala As-Syahru (UT)
    final j = b5 - 11 / 24 + (ghurubMatahariJam - utcOffset) / 24; // b22

    // Posisi Bulan pada momen ghurub (rumus posisi presisi-rendah gaya
    // Meeus, sama seperti yang dipakai HijriService, cuma pengelompokan
    // variabelnya mengikuti gaya As-Syahru).
    final g = 18.25 + 13.1764 * j; // b23
    final n = 185.33 + 13.06499 * j; // b24
    final w = 356.93 + 0.9856 * j; // b25
    final f = 323.05 + 13.22935 * j; // b26
    final o = 98.64 + 12.19075 * j; // b27

    final lintangBulan = 5.13 * _sind(f) +
        0.28 * _sind(f + n) -
        0.28 * _sind(f - n) -
        0.17 * _sind(f - 2 * o); // b28
    final bujurBulan = g +
        6.29 * _sind(n) -
        1.27 * _sind(n - 2 * o) +
        0.66 * _sind(2 * o) +
        0.21 * _sind(2 * n) -
        0.19 * _sind(w) -
        0.11 * _sind(2 * f); // b29

    final deklinasiBulan = _asind(
        _cosQBeku * _sind(lintangBulan) + _sinQBeku * _cosd(lintangBulan) * _sind(bujurBulan)); // b31

    final azimutMatahari =
        _atand(_tand(deklinasiMatahari) * _cosd(lat) / _sind(sudutWaktuMatahari) - _sind(lat) / _tand(sudutWaktuMatahari)); // b32

    // b30: pendekatan asensiorekta bulan ala file asli (dipakai HANYA
    // untuk sudut waktu bulan di bawah, bukan untuk elongasi -- lihat
    // catatan elongasi terpisah di bawah).
    final raBulanSederhana = _atand((_sind(bujurBulan) * _cosQBeku - _tand(lintangBulan) * _sinQBeku) / _cosd(bujurBulan));

    final sudutWaktuBulan = b18 - raBulanSederhana + sudutWaktuMatahari; // b33
    final azimutBulan =
        _atand(_tand(deklinasiBulan) * _cosd(lat) / _sind(sudutWaktuBulan) - _sind(lat) / _tand(sudutWaktuBulan)); // b34

    final tinggiHilalHakiki =
        _asind(_sind(lat) * _sind(deklinasiBulan) + _cosd(lat) * _cosd(deklinasiBulan) * _cosd(sudutWaktuBulan)); // b35

    final tinggiHilalMari = koreksiHakikiKeMarI(tinggiHilalHakiki, elevasiM); // b36-b37, rumus bersama

    final lamaHilalJam = tinggiHilalMari / 15; // b38
    final jarakAzimutMatahariBulan = azimutBulan - azimutMatahari; // b39 (selisih azimut, BUKAN elongasi sebenarnya)
    final ghurubHilalJam = ghurubMatahariJam + lamaHilalJam; // b42

    // Nurul Hilal -- pakai rumus yang DIDOKUMENTASIKAN di file asli
    // (bukan sel yang salah tersambung, lihat catatan kelas di atas).
    final nurulHilal = sqrt(jarakAzimutMatahariBulan * jarakAzimutMatahariBulan +
            tinggiHilalHakiki * tinggiHilalHakiki) /
        15 *
        2.5;

    // Elongasi SEBENARNYA (jarak sudut sejati matahari-bulan) -- DIHITUNG
    // TERPISAH dari jarak-azimut ala As-Syahru di atas (yang cuma selisih
    // azimut, bukan jarak sudut penuh). Dipakai untuk kriteria imkan
    // rukyat yang butuh elongasi sungguhan (mis. MABIMS 2021), memakai
    // asensiorekta yang dihitung robust (atan2), bukan pendekatan atan
    // sederhana ala file asli yang berisiko salah kuadran.
    final raMatahari = _atan2d(_cosd(23.4392815) * _sind(b9), _cosd(b9));
    final raBulanRobust = _atan2d(
        _sind(bujurBulan) * _cosd(23.4392815) - _tand(lintangBulan) * _sind(23.4392815), _cosd(bujurBulan));
    final cosElongasi = (_sind(deklinasiMatahari) * _sind(deklinasiBulan) +
            _cosd(deklinasiMatahari) * _cosd(deklinasiBulan) * _cosd(raMatahari - raBulanRobust))
        .clamp(-1.0, 1.0);
    final elongasi = acos(cosElongasi) * 180 / pi;

    return HasilHisabDetail(
      namaMetode: 'As-Syahru',
      tinggiHilalHakiki: tinggiHilalHakiki,
      tinggiHilalMari: tinggiHilalMari,
      elongasi: elongasi,
      azimutMatahari: _mod(azimutMatahari, 360),
      azimutBulan: _mod(azimutBulan, 360),
      lamaHilalJam: lamaHilalJam,
      nurulHilal: nurulHilal,
      ghurubMatahariJam: ghurubMatahariJam,
      ghurubHilalJam: ghurubHilalJam,
      tinggiMatahariSaatTerbenam: b10,
      deklinasiMatahari: deklinasiMatahari,
      sudutWaktuMatahari: sudutWaktuMatahari,
      bujurMatahari: _mod(b9, 360),
      bujurBulan: _mod(bujurBulan, 360),
      sudutWaktuBulan: _mod(sudutWaktuBulan, 360),
      deklinasiBulan: deklinasiBulan,
      jarakAzimutMatahariBulan: jarakAzimutMatahariBulan,
    );
  }
}
