import 'package:flutter_test/flutter_test.dart';
import 'package:pencari_kecamatan/services/activation_service.dart';

void main() {
  group('ActivationService.verifySerial', () {
    test('menerima "falak" huruf kecil', () {
      expect(ActivationService.verifySerial('falak'), isTrue);
    });

    test('tidak peka huruf besar/kecil — FALAK', () {
      expect(ActivationService.verifySerial('FALAK'), isTrue);
    });

    test('tidak peka huruf besar/kecil — Falak', () {
      expect(ActivationService.verifySerial('Falak'), isTrue);
    });

    test('mengabaikan spasi di awal/akhir', () {
      expect(ActivationService.verifySerial('  falak  '), isTrue);
    });

    test('menolak kata kunci lama "lirboyo" (sudah diganti)', () {
      expect(ActivationService.verifySerial('lirboyo'), isFalse);
    });

    test('menolak string kosong', () {
      expect(ActivationService.verifySerial(''), isFalse);
    });

    test('menolak serial number yang salah', () {
      expect(ActivationService.verifySerial('salah123'), isFalse);
    });

    test('hash yang tersimpan panjangnya benar (64 karakter hex, SHA-256)', () {
      expect(ActivationService.expectedHash.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(ActivationService.expectedHash), isTrue);
    });
  });
}
