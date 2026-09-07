import 'dart:math';

/// Hasil lengkap satu perhitungan keadaan hilal dari SATU metode hisab --
/// bentuk data ini SENGAJA dibuat generik (bukan spesifik As-Syahru atau
/// Meeus) supaya metode hisab lain yang mungkin ditambahkan ke depannya
/// tinggal mengisi struktur yang sama ini, tanpa perlu ubah layar
/// laporan/tampilan perbandingan sama sekali.
class HasilHisabDetail {
  /// Nama metode untuk ditampilkan (mis. "Jean Meeus", "As-Syahru").
  final String namaMetode;
  final double tinggiHilalHakiki;
  final double tinggiHilalMari;
  final double elongasi;
  final double azimutMatahari;
  final double azimutBulan;
  final double lamaHilalJam;
  final double nurulHilal;
  final double ghurubMatahariJam;
  final double ghurubHilalJam;
  final double tinggiMatahariSaatTerbenam;
  final double deklinasiMatahari;
  final double sudutWaktuMatahari;
  final double bujurMatahari;
  final double bujurBulan;
  final double sudutWaktuBulan;
  final double deklinasiBulan;
  /// Selisih azimut matahari-bulan -- tandanya menunjukkan hilal miring
  /// ke utara (positif) atau selatan (negatif) dari matahari.
  final double jarakAzimutMatahariBulan;

  HasilHisabDetail({
    required this.namaMetode,
    required this.tinggiHilalHakiki,
    required this.tinggiHilalMari,
    required this.elongasi,
    required this.azimutMatahari,
    required this.azimutBulan,
    required this.lamaHilalJam,
    required this.nurulHilal,
    required this.ghurubMatahariJam,
    required this.ghurubHilalJam,
    required this.tinggiMatahariSaatTerbenam,
    required this.deklinasiMatahari,
    required this.sudutWaktuMatahari,
    required this.bujurMatahari,
    required this.bujurBulan,
    required this.sudutWaktuBulan,
    required this.deklinasiBulan,
    required this.jarakAzimutMatahariBulan,
  });

  /// Kriteria MABIMS 2021 dievaluasi terhadap tinggi hilal MAR'I (bukan
  /// hakiki) -- ini yang secara metodologis benar untuk kriteria imkan
  /// rukyat, karena MAR'I adalah tinggi yang sungguhan teramati mata.
  bool get memenuhiMabims2021 => tinggiHilalMari >= 3.0 && elongasi >= 6.4;

  /// "Miring ke Utara" kalau bulan lebih utara dari matahari (selisih
  /// azimut positif), "Miring ke Selatan" kalau sebaliknya.
  String get keadaanHilalArah => jarakAzimutMatahariBulan >= 0 ? 'Miring ke Utara' : 'Miring ke Selatan';
}

/// Koreksi tinggi hilal HAKIKI (geometris) jadi MAR'I (refraksi atmosfer +
/// paralaks bulan + kerendahan ufuk akibat elevasi) -- rumus UNIVERSAL,
/// bukan spesifik satu metode hisab, jadi dipakai bersama oleh
/// AsSyahruService & MeeusHisabService supaya keduanya bisa dibandingkan
/// setara (beda-nya cuma cara menghitung posisi bulan/mataharinya, bukan
/// cara koreksi refraksinya). Rumus persis direplikasi dari
/// AS_-_SYAHRU_MANUAL.xlsm (sel B36-B37), sudah divalidasi terhadap kasus
/// uji di file itu.
double koreksiHakikiKeMarI(double hakikiDerajat, double elevasiM) {
  double tand(double x) => tan(x * pi / 180);
  double cosd(double x) => cos(x * pi / 180);

  final b36 = hakikiDerajat - (0.266666666 / 0.2725) * cosd(hakikiDerajat) + 0.266666666;
  return b36 + (0.0167 / tand(b36 + 7.31 / (b36 + 4.4))) + 0.0293 * sqrt(elevasiM.clamp(0, double.infinity));
}
