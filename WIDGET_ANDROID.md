# Widget Android Home Screen

Dokumen ini menjelaskan fitur widget launcher Android (widget yang ditaruh pengguna di layar home HP mereka, **di luar** aplikasi -- beda dari tampilan "Home" **di dalam** aplikasi).

## Tiga Widget yang Tersedia

Pengguna menambahkannya lewat cara standar Android: tekan lama di home screen kosong → "Widgets" → cari "Aplikasi Falak" → pilih salah satu dari 3 varian:

1. **Jam** -- WIB (live, lewat `TextClock` bawaan Android) + Istiwa' (snapshot, lihat batasan di bawah)
2. **Waktu Shalat** -- nama & jam shalat berikutnya
3. **Kalender** -- tanggal Masehi, Hijriah, dan pasaran hari ini

Pengguna bisa menambahkan lebih dari satu (atau semuanya sekaligus) kalau mau -- ini bukan pilihan eksklusif, tapi tiga widget terpisah yang masing-masing bisa ditambahkan berkali-kali.

## Arsitektur

```
Flutter (Home dibuka)
  -> HomeWidgetSyncService.sinkronkanSemua()
  -> Hitung data (pakai mesin hisab yang sama & tervalidasi)
  -> HomeWidget.saveWidgetData(...) untuk tiap field
  -> HomeWidget.updateWidget(androidName: ...) untuk trigger refresh

Native Kotlin (WidgetJamProvider / WidgetShalatProvider / WidgetKalenderProvider)
  -> Baca data tersimpan (SharedPreferences, lewat home_widget)
  -> Render ke RemoteViews (layout XML)
  -> Tampilkan di widget
```

Semua file native (layout XML, metadata widget, kode Kotlin, deklarasi di `AndroidManifest.xml`) dibuat **otomatis oleh CI** (lihat langkah "Buat 3 Widget Android Home Screen" di `.github/workflows/build-apk.yml`) -- bukan disimpan langsung di repo, karena folder `android/` sendiri dibuat ulang tiap build lewat `flutter create`.

## Keterbatasan Penting (WAJIB dipahami)

1. **Bukan tampilan live** (kecuali WIB). Widget Android secara umum diperbarui **maksimal tiap 30 menit** oleh sistem operasi (`updatePeriodMillis`, dan Android sendiri membatasi minimal segitu, tidak bisa lebih cepat lewat cara biasa). Di antara refresh itu, data yang tampil adalah **snapshot terakhir** yang disimpan Flutter -- bukan hitungan ulang real-time.

2. **Data cuma diperbarui saat aplikasi dibuka.** `sinkronkanSemua()` dipanggil dari `initState()` Home -- artinya widget baru dapat data terbaru kalau pengguna **membuka aplikasi**. Kalau aplikasi tidak dibuka berhari-hari, widget akan menampilkan data yang makin basi (untuk Waktu Shalat & Kalender, ini bisa berarti menampilkan jadwal HARI YANG SALAH).

3. **Istiwa' bukan jam yang benar-benar berjalan.** Berbeda dari WIB (yang dirender pakai `TextClock` native, selalu akurat live), Istiwa' cuma dihitung ulang oleh Kotlin dari "offset menit" yang terakhir disimpan Flutter -- offset itu sendiri berubah sangat lambat (equation of time, orde menit per hari) jadi masih cukup akurat untuk beberapa jam, tapi TIDAK live-ticking dengan mulus seperti WIB di sebelahnya (update mengikuti siklus 30 menit yang sama seperti widget lain).

4. **Tidak ada kompas kiblat berputar di widget.** Sistem widget Android (`RemoteViews`) tidak bisa membaca sensor langsung -- kalaupun suatu saat ditambahkan widget kiblat, paling realistis cuma menampilkan ANGKA derajat, bukan jarum yang bergerak.

## Status Pengujian (Penting -- Baca Sebelum Percaya Fitur Ini Bekerja)

Seluruh kode Kotlin & XML di fitur ini **belum pernah diuji di perangkat Android sungguhan** -- lingkungan pengembangan tidak punya emulator/device. Yang SUDAH divalidasi sejauh ini:

- Skrip Python yang MEMBUAT file-file native itu sudah diuji berjalan tanpa error terhadap struktur folder tiruan, dan sempat menemukan (lalu memperbaiki) satu bug nyata: baris duplikat di `widget_jam_info.xml`
- Seluruh file XML yang dihasilkan sudah divalidasi well-formed lewat XML parser sungguhan
- Kurung kurawal/kurung di ketiga file Kotlin sudah dicek seimbang

Yang **BELUM BISA** saya validasi (butuh device Android sungguhan):
- Apakah kode Kotlin benar-benar **berhasil dikompilasi** (nama API `home_widget` seperti `HomeWidgetProvider`, `HomeWidgetLaunchIntent` diasumsikan dari pola umum paket ini, belum dicek langsung terhadap source code versi 0.9.4 yang terpasang)
- Apakah widget benar-benar **muncul & tampil benar** di launcher
- Apakah data dari Flutter **benar-benar sampai** ke Kotlin (format penyimpanan `home_widget` di sisi native)

**Kesimpulan: wajib uji coba menyeluruh di HP Android sungguhan sebelum mengandalkan fitur ini untuk keperluan nyata.** Kalau ada error kompilasi Kotlin saat build APK, kemungkinan besar penyebabnya nama API yang meleset dari asumsi di atas -- laporkan pesan errornya untuk diperbaiki.
