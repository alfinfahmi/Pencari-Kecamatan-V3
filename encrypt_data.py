"""
Mengenkripsi assets/data/data_koordinat.json menjadi data_koordinat.enc
menggunakan AES-256-CBC, khusus untuk build mobile/desktop (Android, iOS,
macOS, Windows) -- TIDAK dipakai untuk build Web (lihat catatan di README
soal keterbatasan proteksi di Web).

Skema file terenkripsi:
  [16 byte IV][ciphertext AES-256-CBC + PKCS7 padding]

Kunci AES (32 byte / 256-bit) disimpan sebagai konstanta hex di kedua sisi:
- Python (skrip ini, dipakai sekali saat menyiapkan build)
- Dart (lib/services/decryption_service.dart, dipakai saat runtime untuk
  dekripsi ke memori)

CATATAN JUJUR: kunci yang tertanam di kode Dart tetap bisa ditemukan lewat
decompile APK/IPA oleh pihak yang punya niat & keahlian teknis. Langkah ini
menaikkan hambatan (orang awam tidak bisa sekadar buka file JSON di editor
teks), bukan membuatnya mustahil. Kombinasikan dengan
`flutter build apk --obfuscate --split-debug-info=...` agar lebih sulit lagi.

Pemakaian:
  python3 encrypt_data.py
"""
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad
import os

# HARUS SAMA PERSIS dengan AES_KEY_HEX di lib/services/decryption_service.dart
AES_KEY_HEX = "e00952e4e57895ffe40aad412019328e55a65381581646caca0ad82156b5f608"

SRC = "data_source/data_koordinat.json"
OUT = "assets/data/data_koordinat.enc"

def main():
    key = bytes.fromhex(AES_KEY_HEX)
    assert len(key) == 32, "Kunci harus 32 byte (256-bit)"

    with open(SRC, "rb") as f:
        plaintext = f.read()

    iv = os.urandom(16)
    cipher = AES.new(key, AES.MODE_CBC, iv)
    ciphertext = cipher.encrypt(pad(plaintext, AES.block_size))

    with open(OUT, "wb") as f:
        f.write(iv + ciphertext)

    print(f"Terenkripsi: {SRC} ({len(plaintext)} bytes)")
    print(f"Output: {OUT} ({len(iv) + len(ciphertext)} bytes)")
    print("Ingat: hapus/jangan sertakan data_koordinat.json versi PLAIN di")
    print("build final mobile/desktop -- cukup sertakan file .enc.")

if __name__ == "__main__":
    main()
