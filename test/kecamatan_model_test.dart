import 'package:flutter_test/flutter_test.dart';
import 'package:pencari_kecamatan/models/kecamatan_model.dart';

void main() {
  final sample = KecamatanModel(
    id: 'kec_00001',
    kecamatan: 'Baiturrahman',
    kabupaten: 'Kota Banda Aceh',
    provinsi: 'Aceh',
    lat: 5.5455278,
    lng: 95.3194389,
    latDms: '05° 32\' 43.90" U',
    lngDms: '95° 19\' 09.98" T',
    elevasiM: 5,
    zonaWaktu: 'WIB',
    utcOffset: 7,
  );

  group('KecamatanModel.fromJson', () {
    test('parsing sesuai skema data_koordinat.json', () {
      final json = {
        'id': 'kec_00001',
        'kecamatan': 'Baiturrahman',
        'kabupaten': 'Kota Banda Aceh',
        'provinsi': 'Aceh',
        'lat': 5.5455278,
        'lng': 95.3194389,
        'lat_dms': '05° 32\' 43.90" U',
        'lng_dms': '95° 19\' 09.98" T',
        'elevasi_m': 5,
        'zona_waktu': 'WIB',
        'utc_offset': 7,
      };
      final model = KecamatanModel.fromJson(json);
      expect(model.kecamatan, 'Baiturrahman');
      expect(model.kabupaten, 'Kota Banda Aceh');
      expect(model.provinsi, 'Aceh');
      expect(model.lat, 5.5455278);
      expect(model.zonaWaktu, 'WIB');
      expect(model.utcOffset, 7);
      expect(model.isReferensi, false);
    });

    test('elevasi_m dan zona_waktu null (mis. Arab Saudi) ditangani dengan benar', () {
      final json = {
        'id': 'ref_01',
        'kecamatan': "Ka'bah (Masjidil Haram, Makkah)",
        'kabupaten': null,
        'provinsi': 'Arab Saudi',
        'lat': 21.4225,
        'lng': 39.8262,
        'lat_dms': null,
        'lng_dms': null,
        'elevasi_m': null,
        'zona_waktu': 'Waktu Arab Saudi (AST)',
        'utc_offset': 3,
      };
      final model = KecamatanModel.fromJson(json, isReferensi: true);
      expect(model.kabupaten, isNull);
      expect(model.elevasiM, isNull);
      expect(model.utcOffset, 3);
      expect(model.isReferensi, true);
    });
  });

  group('KecamatanModel.searchIndex', () {
    test('menggabungkan kecamatan, kabupaten, provinsi, elevasi dalam huruf kecil', () {
      final index = sample.searchIndex;
      expect(index, contains('baiturrahman'));
      expect(index, contains('kota banda aceh'));
      expect(index, contains('aceh'));
      expect(index, contains('5'));
    });

    test('tidak error saat kabupaten null', () {
      final model = KecamatanModel(
        id: 'ref_01',
        kecamatan: "Ka'bah",
        kabupaten: null,
        provinsi: 'Arab Saudi',
        lat: 21.4225,
        lng: 39.8262,
        latDms: null,
        lngDms: null,
        elevasiM: null,
        zonaWaktu: null,
        utcOffset: null,
        isReferensi: true,
      );
      expect(() => model.searchIndex, returnsNormally);
      expect(model.searchIndex, contains("ka'bah"));
    });
  });

  group('KecamatanModel.toClipboardText', () {
    test('menyertakan semua field yang relevan', () {
      final text = sample.toClipboardText();
      expect(text, contains('Baiturrahman'));
      expect(text, contains('Kota Banda Aceh'));
      expect(text, contains('Aceh'));
      expect(text, contains('5.5455278'));
      expect(text, contains('95.3194389'));
      expect(text, contains('5 mdpl'));
      expect(text, contains('WIB'));
      expect(text, contains('UTC+7'));
    });

    test('tidak menyertakan baris elevasi jika elevasiM null', () {
      final model = KecamatanModel(
        id: 'x', kecamatan: 'Contoh', kabupaten: 'Kab', provinsi: 'Prov',
        lat: 0, lng: 0, latDms: null, lngDms: null,
        elevasiM: null, zonaWaktu: null, utcOffset: null,
      );
      final text = model.toClipboardText();
      expect(text, isNot(contains('mdpl')));
    });
  });
}
