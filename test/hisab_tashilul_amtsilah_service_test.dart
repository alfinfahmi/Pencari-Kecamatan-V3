import 'package:flutter_test/flutter_test.dart';
import 'package:pencari_kecamatan/services/hisab_tashilul_amtsilah_service.dart';

/// Kasus uji utama: Ijtimak Shafar 1448H, markaz Badas Kab. Kediri
/// (φ=-7.7130861, λ=112.205775, TZ=+7, elevasi≈111m). Nilai referensi
/// dari file Excel sumber "Tashil_Awwalusy_Syuhur_App_fUji_Coba_FIXED.xlsx":
///   Bujur matahari final = 112,9694°, Deklinasi matahari = 21,4936°
///   Bujur bulan final = 127,3111°, Jam ijtimak = 16:41 WIB
///   Tinggi hilal hakiki = 13°14'28,45'', mar'i = 12°1'52,82''
///   Elongasi = 14°29'21,2''
void main() {
  const lintang = -7.7130861;
  const bujurLokasi = 112.205775;
  const zonaWaktu = 7.0;
  const elevasi = 111.0;
  final layanan = HisabTashilulAmtsilahService.instance;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await layanan.muatDataAwal();
  });

  group('Kasus uji Shafar 1448H (Badas, Kediri)', () {
    late Map<String, List<num>> row17;
    late double bujurMatahari;

    setUp(() {
      row17 = layanan.rantaiMeanTafawutProyeksi(
        tahunHijriah: 1448, bulanTarget: 2, tanggalHisab: 30,
        lintang: lintang, bujurLokasi: bujurLokasi,
      );
      bujurMatahari = layanan.bujurMatahariFinal(row17);
    });

    test('bujur matahari final EXACT (112,9694°)', () {
      expect(bujurMatahari, closeTo(112.9694, 0.001));
    });

    test('bujur bulan final dekat referensi (127,3111°)', () {
      final rantaiBulan = layanan.rantaiBulanLengkap(row17: row17, bujurMatahariFinal: bujurMatahari);
      expect(rantaiBulan.bujurBulanFinal, closeTo(127.3111, 0.01)); // toleransi ~36 detik busur
    });

    test('laju bulan (BI11) praktis exact (0,616733°/jam)', () {
      final rantaiBulan = layanan.rantaiBulanLengkap(row17: row17, bujurMatahariFinal: bujurMatahari);
      final laju = layanan.lajuBulanSabqAlQamar(
        anomBurj23: rantaiBulan.anomBurj23, anomDerajat23: rantaiBulan.anomDerajat23,
        anomPecahan23: rantaiBulan.anomPecahan23, duaDMinusM: rantaiBulan.duaDMinusM,
        bujurBulanFinal: rantaiBulan.bujurBulanFinal, bujurMatahariFinal: bujurMatahari,
      );
      expect(laju, closeTo(0.616733, 0.001));
    });

    test('jam ijtimak dekat referensi (16:41 WIB)', () async {
      final jam = await layanan.hitungJamIjtimak(
        tahunHijriah: 1448, bulanTarget: 2, tanggalHisab: 30,
        lintang: lintang, bujurLokasi: bujurLokasi, zonaWaktuJam: zonaWaktu, elevasiMeter: elevasi,
      );
      // 16:41 = 16,6833 jam; toleransi 5 menit (0,0833 jam)
      expect(jam, closeTo(16.6833, 0.0834));
    });

    test('tinggi hilal hakiki & mar\'i, elongasi dekat referensi', () async {
      final hasil = await layanan.hitungLengkap(
        tahunHijriah: 1448, bulanTarget: 2, tanggalHisab: 30,
        lintang: lintang, bujurLokasi: bujurLokasi, zonaWaktuJam: zonaWaktu, elevasiMeter: elevasi,
      );
      expect(hasil.tinggiHilalHakiki, closeTo(13.2412, 0.01));
      expect(hasil.tinggiHilalMari, closeTo(12.0314, 0.01));
      expect(hasil.elongasi, closeTo(14.4892, 0.01));
      expect(hasil.deklinasiMatahari, closeTo(21.4936, 0.001));
    });

    test('azimut matahari & bulan dekat referensi (konvensi Barat-Utara/BU)', () async {
      final hasil = await layanan.hitungLengkap(
        tahunHijriah: 1448, bulanTarget: 2, tanggalHisab: 30,
        lintang: lintang, bujurLokasi: bujurLokasi, zonaWaktuJam: zonaWaktu, elevasiMeter: elevasi,
      );
      // Referensi file asli (konvensi Barat-ke-Utara, BUKAN lagi
      // dikonversi +270 ke standar -- diseragamkan dgn Meeus/As-Syahru/MPT
      // setelah perbaikan bug tanda azimut, lihat TASHILUL_AMTSILAH_CATATAN.md).
      expect(hasil.azimutMatahari, closeTo(21.5366, 0.01));
      expect(hasil.azimutBulan, closeTo(23.2267, 0.01));
    });
  });

  group('Pengaman batas tahun', () {
    test('tahun di bawah minimum melempar TashilulRentangTahunException', () {
      expect(
        () => layanan.posisiRataRata(
          tahunHijriah: 100, bulanTarget: 1, tanggalHisab: 15, kunciBesaran: 'ws_matahari',
        ),
        throwsA(isA<TashilulRentangTahunException>()),
      );
    });

    test('tahun di atas maksimum melempar TashilulRentangTahunException', () {
      expect(
        () => layanan.posisiRataRata(
          tahunHijriah: 2000, bulanTarget: 1, tanggalHisab: 15, kunciBesaran: 'ws_matahari',
        ),
        throwsA(isA<TashilulRentangTahunException>()),
      );
    });

    test('tahun 1448H (dalam rentang) tidak melempar exception', () {
      expect(
        () => layanan.posisiRataRata(
          tahunHijriah: 1448, bulanTarget: 2, tanggalHisab: 30, kunciBesaran: 'ws_matahari',
        ),
        returnsNormally,
      );
    });
  });

  group('Konversi kalender Hijriah<->Masehi mandiri', () {
    test('30 Muharram 1448H dekat 14 Juli 2026 (toleransi kalender tabular)', () {
      final jdn = HisabTashilulAmtsilahService.jdnDariHijriah(tahunH: 1448, bulanH: 1, tanggalH: 30);
      final tgl = HisabTashilulAmtsilahService.jdnKeMasehi(jdn);
      final referensi = DateTime(2026, 7, 14);
      expect(tgl.difference(referensi).inDays.abs(), lessThanOrEqualTo(3));
    });

    test('round-trip Masehi->Hijriah->Masehi konsisten', () {
      final jdnAsli = HisabTashilulAmtsilahService.jdnDariHijriah(tahunH: 1448, bulanH: 2, tanggalH: 5);
      final tglMasehi = HisabTashilulAmtsilahService.jdnKeMasehi(jdnAsli);
      final jdnBalik = HisabTashilulAmtsilahService.masehiKeJdn(tglMasehi);
      expect(jdnBalik, equals(jdnAsli));

      final hijriBalik = HisabTashilulAmtsilahService.hijriahDariJdn(jdnAsli);
      expect(hijriBalik.tahunH, equals(1448));
      expect(hijriBalik.bulanH, equals(2));
    });
  });
}
