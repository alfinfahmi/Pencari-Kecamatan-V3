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


## Sesi lanjutan: 2 bug SERIUS ditemukan & diperbaiki (laporan tinggi hilal ~24-32° janggal)

Pengguna melaporkan tinggi hilal tidak masuk akal (~24°) saat mengecek bulan
berjalan di aplikasi. Ditelusuri sampai ketemu 2 bug BERBEDA di `tashilul_amtsilah_adapter.dart`:

**Bug #1 -- `tanggalHisab` BUKAN konstanta 30**: kode lama selalu memakai
tanggalHisab=30 utk SEMUA bulan. Ternyata ini cuma kebetulan cocok utk kasus
uji asli (Shafar 1448H) -- utk bulan lain, ijtimak sesungguhnya bisa jatuh
di tanggal 27-29. DIPERBAIKI: `cariTanggalHisabOptimal()` (fungsi baru di
`HisabTashilulAmtsilahService`) mencari tanggal yg memberi selisih bujur
bulan-matahari (mean, row10) PALING DEKAT nol, bukan asumsi tetap.

**Bug #2 -- konversi kalender tabular bisa salah pilih BULAN**: konversi
Masehi->Hijriah mandiri (dari sesi sebelumnya) py drift beberapa hari yg
BISA menyeberang batas bulan (bukan cuma batas tanggal). DIPERBAIKI:
`TashilulAmtsilahAdapter._cariBulanTerbaik()` sekarang MEMVERIFIKASI tebakan
tabular dgn membandingkan 3 kandidat bulan (tabular-1, tabular, tabular+1)
-- pilih yg jam-ijtimak-hasil-Tashilul-nya PALING DEKAT ke `ijtimakUtc` yg
diberikan (bukan percaya konversi tabular begitu saja).

**Hasil validasi** (skenario nyata: ijtimak 11 September 2026, 03:27 UTC,
markaz Kediri): sebelum perbaikan tinggi hilal hakiki=25,05° (SALAH), setelah
perbaikan=13,70° (MASUK AKAL, konsisten dgn skenario hilal muda).

**Dampak ke fungsi lain**: `cariIjtimakUtc()`, `hitungJamIjtimakSaja()`, dan
`hitung()` di adapter SEMUA memakai `cariTanggalHisabOptimal()` sekarang
(bukan lagi tanggalHisab=30 tetap).

## Sesi lanjutan: Jam ijtima berbeda drastis antar-lokasi (Aceh -71 menit dari Kediri)

Pengguna menemukan jam ijtimak Tashilul BERBEDA JAUH tergantung lokasi
perhitungan (diuji: Kediri 16:39, Aceh 15:28 WIB -- selisih 71 menit utk
kasus uji yg SAMA persis, hanya beda markaz).

**Akar masalah (dibuktikan lewat uji terpisah)**: 99% dari selisih berasal
dari BUJUR lokasi (cuma 0,5 menit dari lintang). Baris 12-13 (`T12`/`T13`,
kunci `N12=(112-bujurLokasi)/15`) memproyeksikan posisi rata-rata
matahari/bulan maju/mundur berdasar selisih bujur thd 112° -- sehingga
`bujurMatahariFinal` (nilai ASTRONOMIS, bukan cuma jam) BERBEDA tergantung
markaz yg dipakai (dibuktikan: 112,9694° utk Kediri vs 113,0143° utk Aceh,
PADAHAL tanggal targetnya SAMA PERSIS!). Koreksi `N12` di rumus akhir
(`BI14=BI7+selisih/laju-N12`) TIDAK sepenuhnya membatalkan efek ini.

**Penjelasan konseptual**: sistem klasik Tashilul Amtsilah menghitung
"ijtima seperti diproyeksikan dari maghrib LOKASI ANDA" -- bukan momen UTC
universal yg dikonversi zona waktu. Ini WAJAR utk kitab yg dirancang dipakai
dari 1 markaz tetap (Kediri), tapi jadi masalah kalau dipakai lintas-lokasi.

**PERBAIKAN**: `hitungJamIjtimakSync()`/`hitungJamIjtimak()` di
`HisabTashilulAmtsilahService` SEKARANG SELALU memakai markaz REFERENSI
TETAP (`_markazRefLintang`/`_markazRefBujur`/`_markazRefElevasi`, markaz
Badas Kab. Kediri) utk perhitungan POSISI/geometri-nya, TERLEPAS dari
lokasi yg diberikan pemanggil -- HANYA `zonaWaktuJam` yg tetap dihormati
(hasil akhir dlm zona waktu pemanggil). TERVALIDASI: Kediri, Aceh, Kayu
Agung (semua WIB) SEKARANG memberi jam ijtimak SAMA PERSIS (16:39 WIB),
sesuai sifat astronomis ijtima yg sesungguhnya (1 momen UTC, sama di
manapun, cuma beda tampilan kalau BEDA ZONA WAKTU).

**PENTING -- yg TIDAK diubah (sengaja)**: `hitungLengkapSync()` (laporan
hilal lengkap: deklinasi, tinggi hilal, elongasi, azimut) TETAP memakai
lokasi PENGGUNA sesungguhnya -- ini BENAR & harus tetap beda per lokasi
(tinggi hilal di Aceh vs Kediri MEMANG seharusnya berbeda, itu bukan bug).
Yg diperbaiki HANYA "jam ijtimak"-nya (`hitungJamIjtimakSync`/
`hitungJamIjtimak`, dipakai Tabel Ijtimak & pencarian bulan di adapter),
bukan seluruh sistem.

**Dampak ke adapter**: `TashilulAmtsilahAdapter.cariIjtimakUtc()` &
`hitungJamIjtimakSaja()` OTOMATIS ikut benar (keduanya memanggil
`hitungJamIjtimakSync` yg sudah diperbaiki), TANPA perlu ubah kode adapter.

## Sesi lanjutan: Solusi lebih baik ditemukan -- HAPUS pengurangan N12 ganda

Setelah perbaikan "markaz referensi tetap" sebelumnya (efektif tapi mengunci
lokasi ke Kediri), pengguna menanyakan apakah bisa TETAP pakai geometri
lokal tapi dikoreksi supaya konsisten. Jawabannya: BISA, dan lebih elegan.

**Akar masalah SESUNGGUHNYA**: `N12` (koreksi selisih bujur thd 112°)
dihitung DUA KALI -- sekali scr implisit lewat baris12/13 (`T12`/`T13`,
proyeksi posisi rata-rata), sekali lagi eksplisit dikurangkan di rumus
`BI14`. Pengurangan ganda inilah penyebab selisih sampai ~2 jam, BUKAN
sekadar "sistem ini memang location-dependent by design" seperti dugaan
sesi sebelumnya.

**PERBAIKAN**: `jamIjtimak()` di `HisabTashilulAmtsilahService` -- rumus
BI14 diubah dari `bi7+selisih/laju-n12` jadi `bi7+selisih/laju` (hapus
`-n12`). `hitungJamIjtimakSync()` DIKEMBALIKAN memakai lokasi PEMANGGIL
sepenuhnya (BUKAN lagi markaz referensi tetap -- konstanta `_markazRefXxx`
DIHAPUS).

**TERVALIDASI** (banyak kombinasi bulan/tahun/lokasi): residu antar-lokasi
turun jadi 0-4 menit (dari sampai 2 jam), SAMBIL tetap memakai geometri
lokasi asli sepenuhnya -- TANPA markaz referensi tetap. Solusi ini
MENGGANTIKAN pendekatan "markaz tetap" sesi sebelumnya (yg tetap valid
scr teknis, tapi solusi ini lebih sesuai filosofi asli kitab & lebih
sederhana).

## Sesi lanjutan: Bug kuadran CD9/CD12 -- Elongasi/Tinggi Hilal bisa salah 180 derajat

Ditemukan lewat uji 12 kombinasi bulan/lokasi/tahun: `hilalLengkap()` memakai
`atan()` polos (bukan `atan2`) utk asensiorekta matahari/bulan (cd9/cd12).
Utk kombinasi geometri tertentu (mis. lintang -10 s/d -11, bujur 120-125,
bulan Rajab), ini melenceng 180 derajat, membuat elongasi & tinggi hilal
salah drastis (Excel: elongasi 128 derajat, seharusnya ~6 derajat).

**PERBAIKAN**: `cd9`/`cd12` di `hilalLengkap()` diubah dari `math.atan()`
jadi `math.atan2()` (argumen (y,x), konvensi matematika standar Dart --
BEDA dari Excel yg argumennya (x,y) terbalik). TERVALIDASI: kasus Kediri
tetap identik (tinggi hilal 13,2419 vs 13,2420 sebelumnya; azimut bulan
293,2266 vs 293,2267), sementara kasus2 lain yg sebelumnya berpotensi salah
kuadran sekarang benar.

CATATAN: `jamAcuanBI7()` (baris ~544, dipakai jalur Jam Ijtimak) SUDAH py
koreksi kuadran SENDIRI (variabel `k31`) sejak sebelumnya -- TIDAK diubah,
krn cd9-nya adalah variabel LOKAL TERPISAH dari `hilalLengkap()` (beda
fungsi), jadi TIDAK ada risiko koreksi-ganda spt yg terjadi di Excel
(di Excel, CD9 adalah SATU SEL yg dipakai BERSAMA kedua jalur, perlu sel
baru CD29 terpisah utk menghindari koreksi ganda -- di Dart tidak perlu
krn sudah terpisah scr alami).

BELUM DIPERIKSA: Azimut Matahari (di `hitungLengkap()`) mungkin py pola
serupa (formula BEDA, via CD18/CD11) -- perlu ditelusuri terpisah kalau
ditemukan kejanggalan.

## Sesi lanjutan: Bug arah rukyat 350 derajat (Meeus/As-Syahru/MPT) + pilihan tanggal hisab manual

Pengguna melaporkan 2 hal terpisah:

### 1. Arah Rukyatul Hilal 350 derajat (Jumadil Ula 1448H) -- Jean Meeus,
As-Syahru, Jean Meeus Presisi Tinggi (BUKAN Tashilul Amtsilah)

**Akar masalah (BUKAN bug kuadran atan/atan2 spt dugaan awal)**: azimut
mentah dari rumus atand() SUDAH benar (mis. -9,78 derajat = "9,78 derajat
dari Barat ke SELATAN"), tapi kode SEBELUMNYA memanggil `_mod(nilai, 360)`
sebelum disimpan -- ini MENGHANCURKAN tanda negatif (jadi 350,22 derajat),
lalu layar melabeli SEMUA hasil dgn "BU" (Barat-Utara) TANPA CEK TANDA,
membuat arah SELATAN yg wajar terlihat spt "hampir ke Utara".

Ditemukan jg: Meeus Presisi Tinggi pakai konvensi BERBEDA (dari Utara,
standar astronomi) yg TIDAK cocok dgn label "BU" sama sekali (nilai mentah
263 derajat, bkn 350 -- tp SAMA JUGA salah label kalau ditampilkan "BU").

**PERBAIKAN**:
- `MeeusHisabService`/`AsSyahruService`: TIDAK lagi `_mod(x,360)` --
  azimutMatahari/azimutBulan skrg nilai mentah bertanda (rentang -90..90).
- `MeeusPresisiTinggiService`: dikonversi dari konvensi "dari Utara" ke
  konvensi "dari Barat, bertanda" yg SAMA persis (rumus: `raw-90`, dibungkus
  ke -180..180, bkn mod360 ke 0..360).
- `HisabTashilulAmtsilahService`: SAMA jg diseragamkan (dulu `mod360(270+
  mentah)`, skrg langsung pakai nilai mentah) -- `jarakAzimut` TIDAK berubah
  nilainya (pergeseran konstan saling meniadakan saat pengurangan).
- `hisab_awal_bulan_screen.dart`: baris Azimut Matahari/Bulan & Arah
  Rukyatul Hilal skrg pakai helper `_dms()` yg SUDAH ADA (label
  BU/BS otomatis sesuai tanda), bukan `"BU"` yg di-hardcode.

TERVALIDASI numerik (Python replikasi rumus persis): konversi MPT (raw-90)
memberi hasil IDENTIK dgn nilai mentah Meeus/As-Syahru utk kasus uji yg
sama (-6,8981 derajat, sama persis) -- konfirmasi ke-4 metode SEKARANG
konsisten memakai 1 konvensi yg sama.

### 2. Pilihan tanggal hisab manual (28/29/30) di Tashilul Amtsilah

Sesuai permintaan pengguna ("seperti yang ada di Excel", di mana tanggal
hisab diisi manual di sel C7) -- ditambahkan `SegmentedButton` (Otomatis/
28/29/30) khusus di tab Tashilul Amtsilah (`hisab_awal_bulan_screen.dart`).

`TashilulAmtsilahAdapter.hitung()` skrg terima parameter opsional
`tanggalHisabManual` -- kalau diisi (28/29/30), MELEWATI pencarian otomatis
(`cariTanggalHisabOptimal`) utk perhitungan DETAIL. Pencarian bulan/tahun
(`_cariBulanTerbaik`, verifikasi 3 kandidat bulan) TETAP otomatis spt
biasa -- override HANYA memengaruhi tanggal hisab detail-nya, bukan
penentuan bulan/tahun itu sendiri.

Berguna KHUSUS utk kasus spt Jumadil Ula 1448H, di mana selisih posisi
rata-rata (mean position) menyarankan 1 tanggal, tapi selisih PASCA-KOREKSI
bisa jauh berbeda -- membiarkan pengguna (ahli falak) membandingkan 28/29/30
scr manual & memakai penilaian sendiri, PERSIS spt tradisi kitab asli.

## Sesi lanjutan: Z,A (input rumus ijtima) dikunci ke markaz Kediri -- residu 0-4 menit jadi NOL

Setelah perbaikan pengurangan-N12-ganda (rumus BI14 sendiri sudah benar:
C+(Z-A)/(F-W), sesuai konfirmasi notasi asli kitab dari pengguna), masih
ada residu 0-4 menit antar lokasi. Ditelusuri: Z (bujur matahari) & A
(bujur bulan) -- INPUT ke rumus itu sendiri -- masih sedikit bergeser
antar lokasi (sampai 0,91 derajat), krn `rantaiMeanTafawutProyeksi`
(baris 10-17) MEMANG dirancang memproyeksikan posisi mendekati "momen
maghrib LOKASI tsb" (lewat T12/T13 berbasis bujur & T14/T15 berbasis
lintang). Proyeksi ini BENAR & perlu utk laporan hilal (tinggi hilal
MEMANG harus dekat maghrib lokal Anda), tapi jadi sumber residu kalau
dipakai jg utk mencari ijtima (1 momen astronomis yg semestinya sama di
manapun dihitung).

**PERBAIKAN**: `hitungJamIjtimakSync()` SEKARANG mengunci lintang/
bujurLokasi/elevasiMeter ke markaz referensi TETAP (`_markazRefLintang`=
-7,7130861, `_markazRefBujur`=112,205775, `_markazRefElevasi`=111 --
markaz Badas, Kab. Kediri, markaz asli kitab) utk SELURUH rantai Z,A,C,F,W
-- `zonaWaktuJam` TETAP dihormati (hasil akhir dlm zona waktu pemanggil).

**PENTING -- TIDAK diubah**: `hitungLengkapSync()` (laporan hilal
lengkap) TETAP memakai lokasi pemanggil sepenuhnya -- SENGAJA, krn
tinggi hilal/deklinasi/elongasi/azimut MEMANG harus mencerminkan lokasi
pengamat sesungguhnya, bukan markaz Kediri.

TERVALIDASI (Python replikasi rumus): Kediri, Aceh, Jayapura (markaz
BEDA jauh) SEKARANG memberi jam ijtima IDENTIK (0,00 detik selisih,
bukan lagi 0-4 menit) setelah dikonversi ke zona waktu yg sama. File
Excel jg diperbarui dgn pendekatan setara (sheet "Hisab Ijtimak (Acuan
Kediri)" + "Data (Acuan Kediri)").

## Sesi lanjutan: Bug baseline tanggal tdk ikut geser sesuai tanggalHisab manual

Pengguna melaporkan kejanggalan: pilih tanggalHisab=28 -> "Awal Rabiul Akhir"
= Ahad, tapi 29/30 -> Sabtu (SATU HARI LEBIH AWAL dari 28, padahal 29/30
adalah malam yg LEBIH BELAKANGAN). Ditelusuri: BUKAN krn jam ijtimak (semua
kandidat sama2 pagi, dekat), tapi krn kriteria MABIMS: tanggalHisab=28
(tinggi ~2 derajat) -> TIDAK memenuhi -> istikmal (+2 hari dari baseline).
tanggalHisab=29/30 (tinggi 13-25 derajat) -> MEMENUHI -> +1 hari dari
baseline. MASALAHNYA: baseline ("hariIjtimakSaja" di
hisab_awal_bulan_screen.dart) SELALU dari ijtimak BERSAMA (HijriService),
TIDAK IKUT GESER sesuai tanggalHisab yg dipilih -- padahal tanggalHisab
28/29/30 SESUNGGUHNYA mengevaluasi 3 MALAM YG BERBEDA (berjarak 1 hari
kalender persis per unit tanggalHisab, BUKAN variasi presisi kecil dari
malam yg sama).

**PERBAIKAN**: `TashilulAmtsilahAdapter.offsetHariTanggalHisab()` (baru)
menghitung selisih hari antara tanggalHisab yg dipilih dgn tanggalHisab
OTOMATIS ([cariTanggalHisabOptimal]) utk bulan yg sama. `hisab_awal_bulan_
screen.dart` memakai offset ini utk MENGGESER `hariIjtimakSaja` (baseline)
KHUSUS utk Tashilul, sebelum menghitung +1/+2 hari.

TERVALIDASI (kasus Rabiul Akhir 1448H, tanggalHisab otomatis=28):
- tanggalHisab=28 (istikmal, offset=0): tanggal1 = Ahad, 13 Sept 2026
- tanggalHisab=29 (visible, offset=+1): tanggal1 = Ahad, 13 Sept 2026 (SAMA!)
- tanggalHisab=30 (visible, offset=+2): tanggal1 = Senin, 14 Sept 2026

28 & 29 SEKARANG KONVERGEN ke tanggal yg SAMA -- ini justru sifat yg
BENAR/diharapkan: 2 malam berurutan (istikmal lalu visible) semestinya
SEPAKAT soal tanggal 1 bulan baru, bukan berkontradiksi spt sebelumnya.
30 bergeser 1 hari lebih lambat krn scr definisi sudah "terlambat" --
bulan baru sesungguhnya sudah ditentukan mulai sebelum malam ke-30 tiba.

## Sesi lanjutan: Tata ulang sesuai keputusan "malam rukyat tetap malam 29"

Menggantikan pendekatan sesi sebelumnya (`offsetHariTanggalHisab`, baseline
ikut geser sesuai tanggalHisab yg dipilih) dgn pendekatan yg disepakati:
**malam rukyat SELALU malam ke-29** (tanggal Hijriyah menurut kalender
TABULAR kitab, bukan ijtimak astronomis), TERLEPAS dari tanggalHisab
(27-30) yg dipilih utk perhitungan detail.

**Perubahan model mental**: tanggalHisab 27/28/29/30 BUKAN memilih MALAM
YG BERBEDA -- ia cuma TITIK ACUAN TABEL (entry point) berbeda utk
MENGHITUNG keadaan hilal PADA malam ke-29 yg SAMA (tetap). Semakin dekat
titik acuan ke 29/30, umumnya makin presisi hasilnya; titik acuan yg lebih
jauh (mis. 27/28) bisa memberi estimasi yg KURANG akurat (bukan "malam
lain").

**PERBAIKAN**:
- `TashilulAmtsilahAdapter.malamRukyatMasehi()` (baru, menggantikan
  `offsetHariTanggalHisab` yg DIHAPUS) -- menghitung tanggal Masehi utk
  "malam 29" via konversi tabular MANDIRI (`jdnDariHijriah`+`jdnKeMasehi`),
  independen dari tanggalHisab yg dipilih MAUPUN dari ijtimak astronomis
  bersama (HijriService).
- `hisab_awal_bulan_screen.dart`: utk Tashilul Amtsilah, baseline
  ("hariIjtimakSaja") skrg SELALU dari `malamRukyatMasehi()`, bukan lagi
  dari ijtimak bersama. Metode lain (As-Syahru/Meeus/MPT) TIDAK berubah,
  tetap pakai ijtimak bersama (tdk py konsep tanggalHisab ini).
- Selector "Tanggal Hisab" skrg 27/28/29/30 (bukan 28-30 saja) -- sesuai
  tabel hari kitab yg memuat 27-30.

**CATATAN PENTING -- dampak nyata**: krn sumber baseline berubah (dari
ijtimak astronomis REAL ke kalender TABULAR kitab yg bisa beda ±1 hari
dari astronomi sesungguhnya), tanggal keluaran BISA BERGESER drpd versi
sebelumnya. Contoh (Rabiul Akhir 1448H): baseline lama (astronomis) =
11 Sept (Jumat), baseline baru (tabular) = 12 Sept (Sabtu) -- SATU HARI
LEBIH LAMBAT. Ini SESUAI keputusan (pakai kalender tabular kitab, bukan
astronomi modern utk menentukan malam rukyat), tapi perlu diketahui krn
mengubah tanggal akhir yg ditampilkan.

**TERVALIDASI** (Python replikasi fungsi tabular):
- Rabiul Akhir 1448H: malam rukyat=12 Sept (Sabtu). tanggalHisab 29&30
  (sama2 "terpenuhi") KONVERGEN ke 13 Sept (Ahad); tanggalHisab 28
  (istikmal, titik acuan kurang presisi) -> 14 Sept (Senin) -- SELISIH 1
  hari ini SEKARANG benar2 mencerminkan AKURASI titik acuan, bukan "malam
  berbeda".
- Jumadil Ula 1448H: malam rukyat=12 Okt (Senin). tanggalHisab 28/29/30
  SEMUA "terpenuhi" & KONVERGEN sempurna ke 13 Okt (Selasa).

## Sesi lanjutan: KOREKSI pemahaman "malam rukyat" -- tanggalHisab = hari Hijriyah sesungguhnya

MERALAT sesi sebelumnya yg KELIRU memahami "selalu 29" sbg "hitung SELALU
utk 1 malam tetap (malam ke-29 tabular), tanggalHisab cuma titik acuan
tabel berbeda". Pemahaman yg BENAR: "selalu 29" merujuk ke tanggal-29-
Hijriyah yg SUDAH DITETAPKAN lewat rukyat/istikmal bulan SEBELUMNYA
(urusan kalender aplikasi scr umum) -- BUKAN sesuatu yg Tashilul hitung
ulang scr terpisah. Di METODE TASHIL sendiri: tanggalHisab (27/28/29/30)
ADALAH hari Hijriyah (bulan yg sedang berjalan) TEMPAT IJTIMAK DIUJI
JATUH -- masing2 MEWAKILI HARI KALENDER MASEHI YG BERBEDA (berurutan,
1 hari demi 1 hari), BUKAN titik-acuan-tabel utk malam yg sama.

**PERBAIKAN (menggantikan `malamRukyatMasehi` sesi sebelumnya)**:
`TashilulAmtsilahAdapter.hariIjtimakLokal()` -- baseline Awal Bulan
dihitung LANGSUNG via konversi tabular murni (`jdnDariHijriah`) dari HARI
KE-[tanggalHisab] bulan Hijriyah yg sedang berjalan (bulan sblm target),
TANPA melibatkan jam ijtimak sama sekali. tanggalHisab yg dipakai SAMA
dgn yg dipakai detail hilal ([hitung]) -- baseline & detail SELALU
konsisten.

**TERVALIDASI** (Python replikasi fungsi tabular):
- Rabiul Akhir 1448H: tanggalHisab=28(istikmal)->11 Sept(Jumat)+2=Ahad 13
  Sept; tanggalHisab=29(terpenuhi)->12 Sept(Sabtu)+1=Ahad 13 Sept (SAMA
  dgn 28!); tanggalHisab=30(terpenuhi)->13 Sept(Ahad)+1=Senin 14 Sept.
  Pola 28&29 konvergen ke Ahad INI JUGA konsisten dgn laporan pengguna
  PALING AWAL (tanggalHisab 28 -> Ahad) sebelum sesi perbaikan2 ini dimulai.
- Jumadil Ula 1448H: tanggalHisab=28->baseline Ahad 11 Okt+1=Senin 12
  Okt; tanggalHisab=29->baseline Senin 12 Okt+1=Selasa 13 Okt;
  tanggalHisab=30->baseline Selasa 13 Okt+1=Rabu 14 Okt -- progresi
  BERURUTAN (1 hari demi 1 hari per tanggalHisab), BUKAN konvergen, krn
  semua "terpenuhi" (tdk ada titik istikmal yg menyilangkan ambang
  kriteria di bulan ini).

## Sesi lanjutan: Peringatan "ijtima belum terjadi" utk tanggalHisab yg terlalu dini

Ditemukan lewat laporan pengguna (3 tangkapan layar, Sya'ban 1448H markaz
Mojoroto): tanggalHisab 27 & 28 memberi Elongasi yg janggal (turun dulu
15,47->5,27 derajat baru naik lagi ke 7,02 derajat di tanggalHisab 29).

**Akar penyebab**: ijtima sesungguhnya (bulan 1448H ini) jatuh DI ANTARA
tanggalHisab 28 & 29. Artinya tanggalHisab 27 & 28 BUKAN menguji hilal
baru sama sekali -- keduanya menguji posisi BULAN TUA (sisa siklus
SEBELUMNYA, bujur bulan msh di belakang bujur matahari), bukan hilal awal
bulan Sya'ban yg baru. Angka yg ditampilkan scr teknis benar hasil
hitungannya, tapi TIDAK BERMAKNA sbg indikator hilal awal bulan.

**PERBAIKAN**: `hisab_awal_bulan_screen.dart` -- method baru
`_tashilulSebelumIjtima(hasil)` mengecek tanda selisih bujur (bulan -
matahari, dibungkus ke -180..180): NEGATIF berarti bujur bulan msh di
belakang matahari (ijtima belum terjadi). Kalau TRUE & metode = Tashilul
Amtsilah, tampil banner merah "Ijtima belum terjadi pada tanggal hisab
ini..." di atas kartu hasil, memperingatkan pengguna bhw tanggalHisab yg
dipilih terlalu dini.

TERVALIDASI (Python replikasi): tanggalHisab 27 & 28 (Sya'ban 1448H,
markaz Mojoroto) -> selisih negatif -> peringatan TAMPIL; tanggalHisab 29
& 30 -> selisih positif -> peringatan TIDAK tampil (hasil valid).

Tidak ada perubahan pd `HasilHisabDetail` (field bersama 4 metode) --
perhitungan flag murni dari `bujurMatahari`/`bujurBulan` yg sudah tersedia,
jadi 3 metode lain (As-Syahru/Meeus/MPT) sama sekali tdk terpengaruh.

## Sesi lanjutan: Kartu kesimpulan 3 status (+ status "Ijtimak Belum Terjadi")

**Laporan pengguna** (Sya'ban 1448H, markaz Mojoroto): utk tanggalHisab 27
& 28 kartu menulis "Istikmal -- Awal Sya'ban Jumat 8 Jan / Sabtu 9 Jan".
Menyesatkan: ghurub yg dihitung (Rabu 6 Jan / Kamis 7 Jan) masih SEBELUM
ijtimak, jadi aturan istikmal (+2) belum boleh diterapkan sama sekali.
Usulan awal pengguna (ganti label jadi "Hisab akhir Rajab Jumat 8 Jan")
tdk dipakai krn tanggal hisab 27 sebenarnya Rabu 6 Jan, bukan 8 Jan.

**PERBAIKAN** (`hisab_awal_bulan_screen.dart`, UI saja -- service/adapter
& `HasilHisabDetail` tdk berubah, unit test tdk terpengaruh):
- enum baru `_StatusHisab { terpenuhi, istikmal, belumIjtimak }`.
- `belumIjtimak` (KHUSUS Tashilul) = ghurub hari hisab (`hariIjtimakLokal`
  + `ghurubMatahariJam`) < waktu ijtimak (dibandingkan sbg jam dinding
  lokal), ATAU `_tashilulSebelumIjtima(hasil)` (cek bujur, cadangan).
  Metode lain tdk memakai status ini (ijtimak setelah maghrib di metode
  lain memang benar istikmal).
- Kartu kesimpulan: hijau (terpenuhi, +1), oranye (istikmal, +2), abu-abu
  "Ijtimak Belum Terjadi" -- TANPA tanggal awal bulan, hanya baris
  "Hisab akhir <bulan> <tahun> H: <hari, tanggal>" + "Tanggal hisab
  terlalu awal". Kartu hijau/oranye juga menampilkan baris hisab tsb
  (kecil, di bawah tanggal awal bulan).
- Banner merah lama sekarang memakai kondisi `status == belumIjtimak`.

**Belum dikerjakan**: status "tanggal hisab terlalu lambat" (mis.
tanggalHisab 30 Sya'ban 1448H: hilal ~38 jam, tinggi 14,77 derajat) &
mode Otomatis yg memilih ghurub pertama setelah ijtimak.
**Belum dikompilasi** (tidak ada Flutter di lingkungan sesi ini) --
jalankan `flutter analyze` sebelum build.

### Lanjutan: kartu kesimpulan dipecah jadi 2 kartu (permintaan pengguna)
- **Kartu "Awal <bulan> <tahun> H"** (atas): latar netral (surfaceContainerHighest)
  dgn border warna status; tanggal awal bulan + keterangan singkat
  ("esok harinya" utk terpenuhi / "lusa" utk istikmal). TIDAK tampil utk
  status `belumIjtimak`.
- **Kartu hasil hisab** (bawah, gradien warna status): judul status,
  "Hisab akhir <bulan sebelumnya> <tahun> H" + hari/tanggal hisab, Tinggi
  Mar'i & Elongasi. Utk `belumIjtimak` ditambah keterangan "tanggal hisab
  terlalu awal".
