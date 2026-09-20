# Catatan Implementasi Hisab Tashilul Amtsilah

Dokumentasi ringkas (bukan transkrip penuh) untuk kelanjutan/pemeliharaan
kode `lib/services/hisab_tashilul_amtsilah_service.dart` ke depannya.

## Status Terkini
Inti perhitungan LENGKAP & tervalidasi terhadap kasus uji dari file Excel
sumber (`Tashil_Awwalusy_Syuhur_App_fUji_Coba_FIXED.xlsx`):
- Input uji: Bulan target=Shafar(2), Tahun=1448H, Tanggal hisab=30,
  Markaz=Badas Kab.Kediri (φ=-7.7130861, λ=112.205775, TZ=+7, elevasi≈111m)
- Hasil tervalidasi:
  - Bujur matahari final: **EXACT** (112,9694°)
  - Deklinasi matahari: **EXACT** (21,4936°)
  - Bujur bulan final: ~2,4 detik busur (127,3117° vs 127,3111°)
  - Laju bulan (BI11): praktis EXACT (0,616732 vs 0,616733)
  - Jam ijtimak: selisih 1-2 menit dari referensi 16:41 WIB
  - Tinggi hilal hakiki/mar'i, elongasi: selisih beberapa detik busur
  - Azimut: EXACT (tervalidasi thd sheet Output file asli)

## Yang BELUM selesai (per rekonstruksi terakhir)
1. **PENTING**: fungsi `hitungLengkap()` (utk laporan HasilHisabDetail)
   TIDAK memakai koreksi BI12 (karena HasilHisabDetail tidak perlu jam
   ijtimak) -- ini OK, BI12 cuma relevan utk `hitungJamIjtimak()`.
2. ~~Unit test otomatis belum ditulis.~~ SELESAI -- lihat
   `test/hisab_tashilul_amtsilah_service_test.dart` (kasus uji utama,
   pengaman batas tahun, konversi kalender).
3. ~~Integrasi UI~~ SELESAI -- tab ke-4 di hisab_awal_bulan_screen.dart
   (dgn banner "masih tahap pengujian") + kolom Tashilul di
   tabel_ijtimak_screen.dart.
4. ~~Batas tahun tabel (1350H-1650H) tanpa pengaman~~ SELESAI --
   `TashilulRentangTahunException` dilempar di luar rentang
   1351H-1680H (bukan diam-diam salah).
5. Elevasi default ke 0 kalau kosong di database kecamatan -- BUKAN
   masalah khusus Tashilul, ini konvensi di SELURUH aplikasi (semua
   metode & layar). Kalau mau diperbaiki, di level database kecamatan,
   bukan kode hisab manapun.

## Data aset
`assets/data/tashilul/data_tabel.json` -- 21 tabel gabungan, diekstrak dari
file Excel sumber via skrip Python (openpyxl). Kalau perlu ekstrak ulang,
source Excel-nya harus diunggah ulang oleh pengguna (tidak disimpan di repo).

## Struktur perhitungan (urutan panggilan fungsi di `hitungLengkap`/`hitungJamIjtimak`)
1. `rantaiMeanTafawutProyeksi()` -- posisi rata-rata + tafawut + proyeksi
   jam/menit, utk KELIMA besaran (ws_matahari, khas_matahari, ws_bulan,
   khas_bulan, simpul_bulan) sekaligus -> `row17`
2. `bujurMatahariFinal(row17)` -- equation-of-center matahari
3. `rantaiBulanLengkap(row17, bujurMatahariFinal)` -- 5 tahap koreksi bujur
   bulan + 2 tahap anomali + 1 tahap node -> bujurBulanFinal + beberapa
   nilai antara (argLintangF, duaDMinusM, anomBurj23/Derajat23/Pecahan23)
4. `lajuBulanSabqAlQamar(...)` -- BI11 (laju bulan, 3 komponen)
5. `_koreksiSabqMatahari(...)` -- BI12 (koreksi kecil, HANYA utk jam ijtimak)
6. `jamAcuanBI7(...)` -- BI7 (jam acuan/estimasi maghrib diperhalus)
7. `jamIjtimak(bi7, ..., laju: BI11-BI12, ...)` -- BI14, jam ijtimak final
8. `hilalLengkap(...)` -- deklinasi bulan, tinggi hilal hakiki/mar'i, elongasi

## Catatan penting/jebakan yang PERNAH bikin salah (supaya tidak terulang)
- **Baris 12 Excel** (koreksi jam akibat selisih bujur lokasi) py BUG
  REFERENSI di file sumber (kolom tanpa prefix "Data!", kolom salah pula).
  Diperbaiki dgn pola SAMA persis dgn baris 14 (tabel `gerak_per_jam`,
  kunci beda: T12 dari selisih bujur, bukan T14 dari estimasi maghrib).
- **Tanda tiap tahap koreksi bulan BEDA-BEDA** (bukan pola seragam
  "Burj>5->+"): tahap1&anomali-tahap1 TERBALIK, tahap2-bujur&tahap3-bujur
  STANDAR, tahap4-bujur TERBALIK, tahap5 pakai TABEL TANDA KHUSUS (bukan
  threshold). SEMUA sudah diverifikasi dari formula asli (EA46/FD52/
  ID52/JP52/LB52/OC53/PC54 dst), JANGAN diasumsikan seragam lagi.
- **Rantai anomali (AG) JUGA melewati "tahap2 bujur"** (row19->21, nilai
  IDENTIK dgn koreksi tahap2 bujur -- AG20=AC20) SEBELUM koreksi HD52
  miliknya sendiri (row21->23) -- BUKAN loncat langsung row19->row23.
- **Sabq Al-Qamar Komponen I pakai TABEL TERPISAH** (`sabq_I`, Data!
  ML8:NU38, mulai baris 8) -- BUKAN berbagi tabel dgn Tahap5 Bujur meski
  formatnya mirip (sempat salah asumsi ini di sesi awal).
- **Format tabel Sabq (I/II/III) & bujur_bulan_tahap1/4/anomali-tahap2/
  node**: BEBERAPA tabel TIDAK punya kolom derajat (nilainya selalu <1°,
  cuma [menit,detik] tersimpan) -- WAJIB dicek row6 (header huruf a,b,c..)
  per tabel, JANGAN asumsi semua tabel format [derajat,menit,detik] rata.
- **BI12 (koreksi laju kecil)**: tabel `sabq_matahari`, 73 titik derajat
  0-360 step 5 (BUKAN format Burj-12-kolom spt tabel lain), kunci = anomali
  matahari row17 (Burj*30+derajat penuh, BUKAN dibulatkan).
- **Elevasi TIDAK BOLEH 0** dlm pengujian -- test case Kediri pakai
  elevasi≈111m (mempengaruhi Ho scr signifikan, ~0,3° bedanya dari elev=0).
- **Azimut**: file sumber pakai konvensi "dari Barat ke Utara" (BUKAN
  standar Utara-searah-jarum-jam) -- WAJIB dikonversi `(270+nilai)%360`
  sblm dipakai di HasilHisabDetail supaya konsisten dgn 3 metode lain.

## 2 Typo di file Excel sumber (didokumentasikan, sudah diputuskan solusinya)
1. Baris 12 (`row12`): referensi kolom rusak (dijelaskan di atas).
2. `Data!OC53` (tanda Komponen II Sabq): kondisi `OC459` seharusnya
   `OC45=9` (Burj=9) -- diikuti pola simetri jelas di sekitarnya (Burj
   0,1,2,10,11 semua "-"), bukan bug literal.
3. **Tabel kabisat 30-tahun** (Data!B4:C33): file py 12 tahun kabisat per
   siklus (thn 2,5,7,10,13,**15**,18,21,24,26,29,**30**), BUKAN 11 standar
   (2,5,7,10,13,**16**,18,21,24,26,29) -- selisih 1 hari/siklus, akumulasi
   ~48 hari utk tahun 1448H kalau dipakai apa adanya. KEPUTUSAN PENGGUNA:
   pakai pola STANDAR (11 tahun) utk konversi kalender, BUKAN tabel file
   (function `_isKabisat`/`_kabisatTahunStandar` di service TIDAK memakai
   `fondasi.kabisat_30tahun` dari data_tabel.json -- pakai konstanta
   terpisah). CATATAN: `fondasi.kabisat_30tahun` di data_tabel.json TETAP
   berisi data asli file (12 tahun) krn cuma diekstrak, TIDAK DIPAKAI
   dimanapun di kode saat ini.

## Konversi Hijriah<->Masehi (ditambahkan sesi lanjutan, MANDIRI)
Kalender tabular (epoch tetap JDN 1948440 + pola kabisat standar 11-tahun,
lihat poin 3 di atas) -- fungsi `jdnDariHijriah`/`jdnKeMasehi`/`masehiKeJdn`/
`hijriahDariJdn` di HisabTashilulAmtsilahService, dipakai TashilulAmtsilahAdapter
(TIDAK lagi menumpang HijriService/metode lain sbg jangkar tanggal).
TERVALIDASI round-trip & thd 2 titik referensi (selisih 1-2 hari, wajar
utk kalender tabular murni vs hisab sesungguhnya):
  - 1 Muharram 1421H -> 6 April 2000 (referensi umum ~5 April 2000)
  - 30 Muharram 1448H -> 16 Juli 2026 (referensi kasus uji ~14 Juli 2026)

