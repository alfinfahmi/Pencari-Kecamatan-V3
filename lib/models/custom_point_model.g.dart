// GENERATED CODE (ditulis manual sebagai pengganti build_runner, karena
// sandbox pembuatan proyek ini tidak memiliki akses ke pub.dev).
//
// Setelah project dibuka di VS Code dengan Flutter SDK terpasang, disarankan
// menjalankan:
//   flutter pub run build_runner build --delete-conflicting-outputs
// untuk memverifikasi/meregenerasi file ini secara resmi. Jika dijalankan,
// hasilnya akan setara dengan isi file ini.

part of 'custom_point_model.dart';

class CustomPointModelAdapter extends TypeAdapter<CustomPointModel> {
  @override
  final int typeId = 1;

  @override
  CustomPointModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CustomPointModel(
      id: fields[0] as String,
      nama: fields[1] as String,
      tipe: fields[2] as String,
      kecamatanId: fields[3] as String,
      kecamatanNama: fields[4] as String,
      kabupatenNama: fields[5] as String?,
      provinsiNama: fields[6] as String,
      lat: fields[7] as double,
      lng: fields[8] as double,
      elevasiM: fields[9] as int?,
      catatan: fields[10] as String?,
      tanggalDibuat: fields[11] as String,
    );
  }

  @override
  void write(BinaryWriter writer, CustomPointModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nama)
      ..writeByte(2)
      ..write(obj.tipe)
      ..writeByte(3)
      ..write(obj.kecamatanId)
      ..writeByte(4)
      ..write(obj.kecamatanNama)
      ..writeByte(5)
      ..write(obj.kabupatenNama)
      ..writeByte(6)
      ..write(obj.provinsiNama)
      ..writeByte(7)
      ..write(obj.lat)
      ..writeByte(8)
      ..write(obj.lng)
      ..writeByte(9)
      ..write(obj.elevasiM)
      ..writeByte(10)
      ..write(obj.catatan)
      ..writeByte(11)
      ..write(obj.tanggalDibuat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomPointModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
