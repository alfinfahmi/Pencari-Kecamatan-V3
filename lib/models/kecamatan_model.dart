/// Model data kecamatan / titik referensi, sesuai skema data_koordinat.json.
/// Field `isReferensi` membedakan Ka'bah & Lirboyo dari data kecamatan biasa.
class KecamatanModel {
  final String id;
  final String kecamatan;
  final String? kabupaten;
  final String provinsi;
  final double lat;
  final double lng;
  final String? latDms;
  final String? lngDms;
  final int? elevasiM;
  final String? zonaWaktu;
  final int? utcOffset;
  final bool isReferensi;
  /// Nama desa/kelurahan -- OPSIONAL, cuma terisi untuk lokasi hasil GPS
  /// (dari reverse geocoding), tidak ada di data kecamatan resmi (yang
  /// memang levelnya kecamatan, bukan desa).
  final String? kelurahan;

  KecamatanModel({
    required this.id,
    required this.kecamatan,
    required this.kabupaten,
    required this.provinsi,
    required this.lat,
    required this.lng,
    required this.latDms,
    required this.lngDms,
    required this.elevasiM,
    required this.zonaWaktu,
    required this.utcOffset,
    this.isReferensi = false,
    this.kelurahan,
  });

  factory KecamatanModel.fromJson(Map<String, dynamic> json, {bool isReferensi = false}) {
    return KecamatanModel(
      id: json['id'] as String,
      kecamatan: json['kecamatan'] as String,
      kabupaten: json['kabupaten'] as String?,
      provinsi: json['provinsi'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      latDms: json['lat_dms'] as String?,
      lngDms: json['lng_dms'] as String?,
      elevasiM: json['elevasi_m'] as int?,
      zonaWaktu: json['zona_waktu'] as String?,
      utcOffset: json['utc_offset'] as int?,
      isReferensi: isReferensi,
    );
  }

  /// Teks lengkap untuk fitur "Salin Data".
  String toClipboardText() {
    final buf = StringBuffer();
    if (kelurahan != null) buf.writeln(kelurahan);
    buf.writeln(kecamatan);
    if (kabupaten != null) buf.writeln(kabupaten);
    buf.writeln(provinsi);
    buf.writeln('Lat: $lat, Lng: $lng');
    if (latDms != null && lngDms != null) {
      buf.writeln('DMS: $latDms, $lngDms');
    }
    if (elevasiM != null) buf.writeln('Elevasi: $elevasiM mdpl');
    if (zonaWaktu != null) buf.writeln('Zona Waktu: $zonaWaktu (UTC+$utcOffset)');
    return buf.toString().trim();
  }

  /// Gabungan teks yang dipakai mesin pencari instan.
  String get searchIndex =>
      '${kecamatan.toLowerCase()} ${kabupaten?.toLowerCase() ?? ''} ${provinsi.toLowerCase()} ${elevasiM ?? ''}';
}
