# Metode Ephemeris (metode hisab ke-5)

## Ringkas
- Tab ke-5 "Ephemeris" di Hisab Awal Bulan: PROSEDUR Ephemeris Hisab Rukyat
  (Kemenag RI; cf. Muhyiddin Khazin) dijalankan di atas tabel data per jam.
- Data: `assets/data/ephemeris/<tahun>.csv` (2020-2050, +-3,2 MB total),
  disusun dari JPL DE421 (NASA/JPL) dgn KOLOM & SATUAN buku Ephemeris.
  **Bukan** salinan buku Ephemeris Kemenag (pengguna tidak punya bukunya;
  keputusan: opsi "susun sendiri dari data JPL"). Kalau kelak ada tabel asli,
  isi file tahun yg sama dgn kolom yg sama -- kode tidak perlu diubah.
- Kode: `lib/services/hisab_ephemeris_service.dart`.
- Generator data: `tools/ephemeris/generate_ephemeris.py`
  (`pip install skyfield skyfield-data`; `python3 generate_ephemeris.py 2020 2050 ../../assets/data/ephemeris`).
- Rujukan Python prosedur (rumus identik dgn Dart): `tools/ephemeris/hisab_ephemeris_ref.py`.
- Unit test: `test/hisab_ephemeris_service_test.dart` (angka dari rujukan Python).

## Isi data
Per ijtimak: 2 hari UT (hari ijtimak D & D+1), jam 0-23 UT. Kolom:
Matahari elm, elb, ars, dks, r (AU), sds, eps, eot (jam);
Bulan alb, alt, arm, dkm, hp, sdm, abl, fib (0-1). Sudut dlm derajat desimal.
- Bujur/lintang: ekliptika sejati tanggal itu (nutasi + aberasi), apparent.
- EoT = (GAST - ARo + 12j) - UT. HP = asin(6378,14/jarak). SD bulan =
  358473400"/jarak km (Meeus). SD matahari = 959,63"/R. FIB dari sudut fase.

## Prosedur (sama di Dart & Python)
1. Ijtimak: jam X = FIB terkecil; ijtimak = X + (ELM-ALB)/(SB-SM).
2. Ghurub: h0 = -(SD matahari + 34'30" + 1,76'√elevasi); cos t0 = -tanφ tanδ
   + sin h0/cosφ/cosδ; ghurub = 12 - e + t0/15 + (λzona-λ)/15; iterasi.
3. Saat ghurub (interpolasi A-(A-B)C/I): tb = ARo-ARb+t0; h hakiki; h' = h -
   HP cos h; mar'i = h' + SD bulan + refraksi Bennett + dip.
4. Elongasi geosentrik, azimut "dari Barat, + Utara", lama hilal = mar'i/15,
   nurul hilal -- konvensi sama dgn 4 metode lain.

## Validasi (data resmi Kemenag, Ramadan 1447 H, 17 Feb 2026)
| Besaran | Ephemeris (DE421) | Kemenag |
|---|---|---|
| Ijtimak | 19:01:09 WIB | 19.01 WIB |
| Ghurub Jakarta Pusat | 18:15:20 | 18:15:17 |
| Elongasi Banda Aceh | 0°56'23" | 0°56'23" |
| Elongasi Jayapura | 1°53'38" | 1°53'36" |
Elongasi Mataram 1,207° (BMKG Mataram 1,208°).
Tinggi hilal BELUM tervalidasi: konvensi tinggi yg dipakai Kemenag/BMKG di
berita tidak disebutkan & tidak cocok dgn hakiki/toposentrik/mar'i kita.

## Belum dikerjakan
- Belum dikompilasi (tidak ada Flutter di sesi pembuatan) -> `flutter analyze`
  & `flutter test test/hisab_ephemeris_service_test.dart`.

## Tabel Ijtimak
`tabel_ijtimak_screen.dart`: kolom ke-5 "Ephemeris" (tinggi mar'i, elongasi,
status MABIMS, jam ijtimak WIB milik metode ini). Data per tahun dimuat saat
baris dibangun; selama memuat atau di luar 2020-2050 kolom ini tidak muncul,
4 metode lain tetap tampil.
