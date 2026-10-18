# Kriteria imkan rukyat di layar-layar hisab

Pilihan kriteria (enum `KriteriaImkanRukyat` di `hijri_service.dart`):
MABIMS 2021 (irtifa 3°, elongasi 6,4°), Irtifa 2° + usia 6 jam,
Irtifa 2° + usia 8 jam, Irtifa 2° saja. Tinggi yg dinilai = tinggi MAR'I.

## Hisab Awal Bulan (`hisab_awal_bulan_screen.dart`)
- Dropdown "Kriteria Imkan Rukyat" di bawah Tahun H / Bulan.
- Awalnya = pengaturan aplikasi (`HijriService.kriteriaAktif`). Mengubahnya
  di layar ini HANYA berlaku di layar ini (utk membandingkan), tidak
  mengubah pengaturan global.
- Berlaku utk kelima metode: status kartu (terpenuhi/istikmal), tanggal
  awal bulan (+1/+2), warna kartu Keadaan Hilal, dan teks kaki.
- Usia hilal = ghurub hari hisab - ijtimak (jam dinding lokal, lintas hari
  utk Tashilul tanggal hisab manual); ditampilkan di kartu Keadaan Hilal.

## Tabel Ijtimak & Kalender Hijriah
- SEBELUMNYA kolom Meeus Presisi Tinggi / Tashilul / Ephemeris SELALU
  memakai MABIMS 2021 (`memenuhiMabims2021`), sementara Jean Meeus &
  As-Syahru mengikuti pengaturan -> tidak konsisten. Sekarang semuanya
  mengikuti `HijriService.kriteriaAktif`.
- Sekalian diperbaiki: `usiaHilalJam` Meeus Presisi Tinggi sebelumnya diisi
  `lamaHilalJam` (lama hilal di atas ufuk), sekarang usia sejati
  (ghurub - ijtimak).

## Kode
`HasilHisabDetail.memenuhiKriteria(kriteria, usiaHilalJam:)` dan
`HasilHisabDetail.usiaHilalJam(ijtimakUtc:, utcOffset:)` di `hisab_detail.dart`.
`memenuhiMabims2021` tetap ada (dipakai unit test).
