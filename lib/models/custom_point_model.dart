import 'package:hive/hive.dart';

part 'custom_point_model.g.dart';

/// Tipe titik kustom yang bisa ditambahkan pengguna.
enum TitikTipe { desa, dusun, masjid, lainnya }

/// Titik koordinat tambahan buatan pengguna (desa/dusun/masjid/lainnya),
/// selalu terhubung ke satu kecamatan resmi dari data_koordinat.json
/// (hierarki Kecamatan -> Kabupaten -> Provinsi tidak boleh lepas).
///
/// Disimpan terpisah dari data referensi (read-only) di box Hive sendiri,
/// sesuai kesepakatan final.
@HiveType(typeId: 1)
class CustomPointModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String nama;

  @HiveField(2)
  String tipe; // simpan sebagai string agar mudah di-export ke JSON

  @HiveField(3)
  String kecamatanId; // FK ke KecamatanModel.id pada data referensi

  @HiveField(4)
  String kecamatanNama;

  @HiveField(5)
  String? kabupatenNama;

  @HiveField(6)
  String provinsiNama;

  @HiveField(7)
  double lat;

  @HiveField(8)
  double lng;

  @HiveField(9)
  int? elevasiM;

  @HiveField(10)
  String? catatan;

  @HiveField(11)
  String tanggalDibuat; // ISO 8601

  CustomPointModel({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.kecamatanId,
    required this.kecamatanNama,
    required this.kabupatenNama,
    required this.provinsiNama,
    required this.lat,
    required this.lng,
    this.elevasiM,
    this.catatan,
    required this.tanggalDibuat,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nama': nama,
        'tipe': tipe,
        'kecamatan_id': kecamatanId,
        'kecamatan_nama': kecamatanNama,
        'kabupaten_nama': kabupatenNama,
        'provinsi_nama': provinsiNama,
        'lat': lat,
        'lng': lng,
        'elevasi_m': elevasiM,
        'catatan': catatan,
        'tanggal_dibuat': tanggalDibuat,
      };

  factory CustomPointModel.fromJson(Map<String, dynamic> json) => CustomPointModel(
        id: json['id'] as String,
        nama: json['nama'] as String,
        tipe: json['tipe'] as String,
        kecamatanId: json['kecamatan_id'] as String,
        kecamatanNama: json['kecamatan_nama'] as String,
        kabupatenNama: json['kabupaten_nama'] as String?,
        provinsiNama: json['provinsi_nama'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        elevasiM: json['elevasi_m'] as int?,
        catatan: json['catatan'] as String?,
        tanggalDibuat: json['tanggal_dibuat'] as String,
      );
}
