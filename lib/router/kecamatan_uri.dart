import '../models/kecamatan_model.dart';

/// Ubah KecamatanModel jadi Map<String,String> untuk dipakai sebagai query
/// parameter URL -- ini yang memungkinkan DetailScreen/ExportJadwalScreen/
/// dkk. DIREKONSTRUKSI ULANG murni dari alamat URL saat browser di-refresh,
/// tanpa butuh objek KecamatanModel asli yang tersimpan di memori (yang
/// hilang setiap kali halaman web dimuat ulang dari nol).
Map<String, String> kecamatanKeQuery(KecamatanModel k) => {
      'id': k.id,
      'kecamatan': k.kecamatan,
      if (k.kelurahan != null) 'kelurahan': k.kelurahan!,
      if (k.kabupaten != null) 'kabupaten': k.kabupaten!,
      'provinsi': k.provinsi,
      'lat': k.lat.toString(),
      'lng': k.lng.toString(),
      if (k.latDms != null) 'latDms': k.latDms!,
      if (k.lngDms != null) 'lngDms': k.lngDms!,
      if (k.elevasiM != null) 'elevasiM': k.elevasiM.toString(),
      if (k.zonaWaktu != null) 'zonaWaktu': k.zonaWaktu!,
      if (k.utcOffset != null) 'utcOffset': k.utcOffset.toString(),
      'isReferensi': k.isReferensi.toString(),
    };

/// Kebalikan dari [kecamatanKeQuery] -- baca kembali query parameter URL
/// jadi KecamatanModel. Dipakai di `builder` tiap route yang butuh data
/// lokasi, supaya refresh browser tetap bisa menampilkan halaman yang
/// sama persis.
KecamatanModel kecamatanDariQuery(Map<String, String> q) => KecamatanModel(
      id: q['id'] ?? 'tidak_diketahui',
      kecamatan: q['kecamatan'] ?? '-',
      kelurahan: q['kelurahan'],
      kabupaten: q['kabupaten'],
      provinsi: q['provinsi'] ?? '-',
      lat: double.tryParse(q['lat'] ?? '') ?? 0,
      lng: double.tryParse(q['lng'] ?? '') ?? 0,
      latDms: q['latDms'],
      lngDms: q['lngDms'],
      elevasiM: int.tryParse(q['elevasiM'] ?? ''),
      zonaWaktu: q['zonaWaktu'],
      utcOffset: int.tryParse(q['utcOffset'] ?? ''),
      isReferensi: q['isReferensi'] == 'true',
    );
