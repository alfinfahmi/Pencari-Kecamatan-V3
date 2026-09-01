# Panduan Build APK via GitHub Actions

Panduan ini membangun APK di cloud (server GitHub), jadi Anda TIDAK perlu
install Flutter SDK atau Android SDK di laptop sama sekali — cukup akun
GitHub (gratis) dan koneksi internet.

File workflow (`.github/workflows/build-apk.yml`) sudah saya sertakan di
dalam project. Anda hanya perlu mengunggahnya ke GitHub dan menjalankannya.

---

## Langkah 1 — Buat Repository GitHub

1. Buka [github.com](https://github.com), login (atau daftar jika belum
   punya akun).
2. Klik tombol **"+"** di kanan atas → **New repository**.
3. Isi nama repo, misalnya `pencari-kecamatan`.
4. Pilih **Private** (disarankan, karena project ini berisi data internal
   MHM/Lirboyo) atau Public sesuai keinginan Anda.
5. **Jangan centang** "Add a README" (biar tidak konflik dengan file yang
   sudah ada) → klik **Create repository**.

## Langkah 2 — Unggah Project ke Repository

**Cara paling mudah (tanpa command line), lewat browser:**

1. Extract `pencari_kecamatan.zip` di komputer Anda.
2. Di halaman repository GitHub yang baru dibuat, klik **"uploading an
   existing file"**.
3. Seret (drag-and-drop) SELURUH ISI folder `pencari_kecamatan` (bukan
   folder itu sendiri, tapi isinya — `lib/`, `pubspec.yaml`, `assets/`,
   `.github/`, dst.) ke halaman upload tersebut.
4. Tulis pesan commit, misalnya "Upload project awal", lalu klik
   **Commit changes**.

**Cara alternatif (kalau Anda punya Git terpasang di komputer):**
```bash
cd pencari_kecamatan
git init
git add .
git commit -m "Upload project awal"
git branch -M main
git remote add origin https://github.com/USERNAME/pencari-kecamatan.git
git push -u origin main
```
Ganti `USERNAME` dengan username GitHub Anda.

**Penting:** pastikan file `.github/workflows/build-apk.yml` benar-benar
ter-upload (folder `.github` kadang tersembunyi karena diawali titik —
periksa dulu di file manager Anda apakah "hidden files" ditampilkan sebelum
drag-and-drop).

## Langkah 3 — Jalankan Build

1. Di halaman repository GitHub, klik tab **Actions** (di baris menu atas,
   sejajar dengan "Code", "Issues", dll.).
2. Jika ini pertama kali, GitHub mungkin menampilkan tombol **"I understand
   my workflows, go ahead and enable them"** — klik itu dulu.
3. Klik workflow bernama **"Build APK"** di daftar sebelah kiri.
4. Klik tombol **"Run workflow"** di kanan atas (dropdown) → klik **"Run
   workflow"** hijau untuk konfirmasi.
5. Tunggu 5–10 menit. Anda bisa klik proses yang sedang berjalan untuk
   melihat log secara langsung (berguna kalau ada error).

## Langkah 4 — Unduh APK

1. Setelah selesai (tanda centang hijau ✅), klik proses build yang selesai
   tersebut.
2. Scroll ke bawah ke bagian **Artifacts**.
3. Klik **"pencari-kecamatan-apk"** untuk mengunduh — hasilnya berupa file
   `.zip` berisi `app-release.apk`.
4. Extract, lalu salin `app-release.apk` ke HP Android Anda (lewat kabel
   USB, Google Drive, WhatsApp ke diri sendiri, dll.) dan install seperti
   biasa (mungkin perlu mengizinkan "Install from unknown sources" di
   pengaturan Android).

---

## Catatan Penting

**Soal package name (applicationId):** workflow ini otomatis menjalankan
`flutter create --org com.lflirboyo .` HANYA jika folder `android/` belum
ada di repo Anda. Setelah build pertama berhasil, sebaiknya unduh hasil
kerja CI itu (atau jalankan `flutter create` sekali secara lokal jika Anda
akhirnya install Flutter) dan commit folder `android/` ke repo — supaya
package name (`com.lflirboyo.pencari_kecamatan`) konsisten di setiap build
berikutnya, bukan random tiap kali. Kalau Anda ingin nama organisasi/domain
lain, edit bagian `--org com.lflirboyo` di file
`.github/workflows/build-apk.yml` sebelum menjalankan Actions.

**Soal APK ini belum di-sign untuk Play Store:** APK hasil workflow ini
memakai signing config default (debug keystore bawaan Flutter) — cukup
untuk dipasang manual di HP (sideloading), TAPI TIDAK BISA diunggah ke
Google Play Store. Untuk itu perlu keystore rilis sungguhan + menyimpan
kredensialnya sebagai **GitHub Secrets** (bukan langsung di kode). Beri
tahu saya kalau Anda sudah sampai tahap ini — saya bantu siapkan
konfigurasi signing-nya.

**Soal `python3 encrypt_data.py` di CI:** workflow ini menjalankan skrip
enkripsi setiap kali build, memakai kunci AES yang SAMA dengan yang sudah
tertanam di `encrypt_data.py` dan `decryption_service.dart` (sudah pernah
saya verifikasi identik). Anda tidak perlu melakukan apa pun tambahan
untuk ini — otomatis.

**Kalau build gagal:** klik langkah yang gagal di log Actions untuk melihat
pesan errornya, lalu kirimkan pesan error tersebut ke saya — saya bantu
diagnosis dari sini.
