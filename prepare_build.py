"""
Solusi praktis untuk trade-off ukuran APK/IPA akibat folder
`assets/data/web/` (~2MB) ikut ter-bundle ke SEMUA platform (keterbatasan
bawaan: Flutter tidak mendukung asset kondisional per-platform tanpa setup
product flavors/scheme yang jauh lebih rumit).

Skrip ini memindahkan folder `assets/data/web/` keluar-masuk direktori
project sebelum build, tergantung target:

  python3 prepare_build.py mobile   # sembunyikan assets/data/web/ (hemat ~2MB di APK/IPA)
  python3 prepare_build.py web      # pastikan assets/data/web/ ada (dibutuhkan build web)
  python3 prepare_build.py restore  # kembalikan semuanya (untuk development sehari-hari)

Alur kerja rilis produksi yang disarankan:
  python3 prepare_build.py mobile
  flutter build apk --obfuscate --split-debug-info=build/symbols
  flutter build ios --obfuscate --split-debug-info=build/symbols
  python3 prepare_build.py web
  flutter build web --release
  python3 prepare_build.py restore   # supaya flutter run harian tetap normal

CATATAN JUJUR: ini solusi pragmatis (memindahkan file sebelum build),
bukan konfigurasi asset-variant resmi Flutter. Cukup untuk kebutuhan rilis
manual seperti project ini; jika nanti dipakai CI/CD otomatis, sebaiknya
diganti dengan product flavors (Android) + scheme terpisah (iOS) yang lebih
standar dan tidak bergantung urutan menjalankan skrip secara manual.
"""
import sys
import shutil
import os

PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
WEB_DATA_DIR = os.path.join(PROJECT_ROOT, "assets", "data", "web")
WEB_DATA_HIDDEN = os.path.join(PROJECT_ROOT, "_hidden_web_data")

def hide_web_data():
    if os.path.isdir(WEB_DATA_DIR):
        if os.path.isdir(WEB_DATA_HIDDEN):
            shutil.rmtree(WEB_DATA_HIDDEN)
        shutil.move(WEB_DATA_DIR, WEB_DATA_HIDDEN)
        print(f"Disembunyikan: {WEB_DATA_DIR} -> {WEB_DATA_HIDDEN}")
        print("Sekarang build mobile/desktop TIDAK akan menyertakan data web (~2MB dihemat).")
    else:
        print("assets/data/web/ sudah tidak ada (mungkin sudah disembunyikan sebelumnya). Lanjut.")

def restore_web_data():
    if os.path.isdir(WEB_DATA_HIDDEN):
        if os.path.isdir(WEB_DATA_DIR):
            shutil.rmtree(WEB_DATA_DIR)
        shutil.move(WEB_DATA_HIDDEN, WEB_DATA_DIR)
        print(f"Dikembalikan: {WEB_DATA_HIDDEN} -> {WEB_DATA_DIR}")
    else:
        print("Tidak ada data tersembunyi untuk dikembalikan. Lanjut.")

def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ("mobile", "web", "restore"):
        print(__doc__)
        sys.exit(1)

    mode = sys.argv[1]
    if mode == "mobile":
        hide_web_data()
    elif mode == "web":
        restore_web_data()  # web build butuh assets/data/web/ ada
        if not os.path.isdir(WEB_DATA_DIR):
            print("PERINGATAN: assets/data/web/ tidak ditemukan sama sekali.")
            print("Jalankan dulu: python3 split_data_per_provinsi.py")
    elif mode == "restore":
        restore_web_data()

if __name__ == "__main__":
    main()
