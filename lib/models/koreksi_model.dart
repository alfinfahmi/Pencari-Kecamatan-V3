/// Model usulan koreksi koordinat, sesuai skema tabel Supabase
/// `koreksi_koordinat` (lihat supabase/schema.sql).
class KoreksiModel {
  final String? id; // null untuk usulan baru yang belum terkirim (masih di antrean lokal)
  final String kecamatanId;
  final String kecamatanNama;
  final String? kabupatenNama;
  final String provinsiNama;

  final double? latLama;
  final double? lngLama;
  final int? elevasiLama;

  final double latBaru;
  final double lngBaru;
  final int? elevasiBaru;

  final String? catatanPengusul;
  final String? catatanEvaluasi;
  final String status; // pending, approved, rejected
  final String? diusulkanOleh;
  final String? namaPengusul; // hasil join ke profiles, hanya terisi saat fetch untuk moderasi
  final String? rolePengusul;
  final DateTime? createdAt;

  KoreksiModel({
    this.id,
    required this.kecamatanId,
    required this.kecamatanNama,
    this.kabupatenNama,
    required this.provinsiNama,
    this.latLama,
    this.lngLama,
    this.elevasiLama,
    required this.latBaru,
    required this.lngBaru,
    this.elevasiBaru,
    this.catatanPengusul,
    this.catatanEvaluasi,
    this.status = 'pending',
    this.diusulkanOleh,
    this.namaPengusul,
    this.rolePengusul,
    this.createdAt,
  });

  Map<String, dynamic> toInsertJson() => {
        'kecamatan_id': kecamatanId,
        'kecamatan_nama': kecamatanNama,
        'kabupaten_nama': kabupatenNama,
        'provinsi_nama': provinsiNama,
        'lat_lama': latLama,
        'lng_lama': lngLama,
        'elevasi_lama': elevasiLama,
        'lat_baru': latBaru,
        'lng_baru': lngBaru,
        'elevasi_baru': elevasiBaru,
        'catatan_pengusul': catatanPengusul,
      };

  factory KoreksiModel.fromJson(Map<String, dynamic> json) => KoreksiModel(
        id: json['id'] as String?,
        kecamatanId: json['kecamatan_id'] as String,
        kecamatanNama: json['kecamatan_nama'] as String,
        kabupatenNama: json['kabupaten_nama'] as String?,
        provinsiNama: json['provinsi_nama'] as String,
        latLama: (json['lat_lama'] as num?)?.toDouble(),
        lngLama: (json['lng_lama'] as num?)?.toDouble(),
        elevasiLama: json['elevasi_lama'] as int?,
        latBaru: (json['lat_baru'] as num).toDouble(),
        lngBaru: (json['lng_baru'] as num).toDouble(),
        elevasiBaru: json['elevasi_baru'] as int?,
        catatanPengusul: json['catatan_pengusul'] as String?,
        catatanEvaluasi: json['catatan_evaluasi'] as String?,
        status: json['status'] as String? ?? 'pending',
        diusulkanOleh: json['diusulkan_oleh'] as String?,
        namaPengusul: (json['profiles'] as Map<String, dynamic>?)?['nama'] as String?,
        rolePengusul: (json['profiles'] as Map<String, dynamic>?)?['role'] as String?,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      );

  KoreksiModel copyForQueue() => KoreksiModel(
        kecamatanId: kecamatanId, kecamatanNama: kecamatanNama, kabupatenNama: kabupatenNama,
        provinsiNama: provinsiNama, latLama: latLama, lngLama: lngLama, elevasiLama: elevasiLama,
        latBaru: latBaru, lngBaru: lngBaru, elevasiBaru: elevasiBaru, catatanPengusul: catatanPengusul,
      );
}
