"""
Memecah data_koordinat.json menjadi file per-provinsi, khusus untuk build
Web — supaya browser tidak mengunduh 2.5MB sekaligus di awal, dan scraping
massal sedikit lebih sulit (data tidak berbentuk satu file utuh).

Struktur output:
  assets/data/web/manifest.json           -> daftar provinsi + jumlah entri
  assets/data/web/referensi.json          -> 2 titik referensi (Ka'bah, Lirboyo)
  assets/data/web/provinsi/<slug>.json    -> kecamatan per provinsi

Pemakaian di Flutter (khusus target web): muat manifest.json dan referensi.json
saat startup (kecil), lalu muat file provinsi terkait secara lazy saat user
mulai mengetik nama provinsi/kabupaten, atau muat semua provinsi di background
setelah splash selesai jika ingin pengalaman tetap instan seperti mobile.
"""
import json
import re
import os

SRC = "data_source/data_koordinat.json"
OUT_DIR = "assets/data/web"

def slugify(text: str) -> str:
    text = text.lower().strip()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-")

def main():
    with open(SRC, "r", encoding="utf-8") as f:
        data = json.load(f)

    os.makedirs(os.path.join(OUT_DIR, "provinsi"), exist_ok=True)

    # 1) Referensi tetap (Ka'bah, Lirboyo) -> file kecil tersendiri
    with open(os.path.join(OUT_DIR, "referensi.json"), "w", encoding="utf-8") as f:
        json.dump({"referensi": data["referensi"]}, f, ensure_ascii=False, indent=2)

    # 2) Kelompokkan kecamatan per provinsi
    per_provinsi = {}
    for k in data["kecamatan"]:
        prov = k["provinsi"]
        per_provinsi.setdefault(prov, []).append(k)

    manifest = {
        "version": data["meta"]["version"],
        "updated_at": data["meta"]["updated_at"],
        "total_kecamatan": data["meta"]["total_kecamatan"],
        "provinsi": [],
    }

    for prov, items in sorted(per_provinsi.items()):
        slug = slugify(prov)
        filename = f"{slug}.json"
        path = os.path.join(OUT_DIR, "provinsi", filename)
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"provinsi": prov, "kecamatan": items}, f, ensure_ascii=False)  # tanpa indent -> lebih ringkas

        manifest["provinsi"].append({
            "nama": prov,
            "slug": slug,
            "file": f"provinsi/{filename}",
            "jumlah": len(items),
        })

    with open(os.path.join(OUT_DIR, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)

    total_size = sum(
        os.path.getsize(os.path.join(OUT_DIR, "provinsi", p["file"].split("/")[-1]))
        for p in manifest["provinsi"]
    )
    print(f"Jumlah provinsi: {len(manifest['provinsi'])}")
    print(f"Total ukuran seluruh file provinsi: {total_size / 1024:.1f} KB")
    print(f"Rata-rata per provinsi: {total_size / len(manifest['provinsi']) / 1024:.1f} KB")
    print(f"Output di: {OUT_DIR}")

if __name__ == "__main__":
    main()
