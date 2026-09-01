import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../services/hisab_service.dart';

/// Pilihan "volume" notifikasi adzan.
///
/// CATATAN JUJUR: Android/iOS TIDAK mengizinkan aplikasi mengatur volume
/// kontinu (0-100%) untuk suara notifikasi -- itu wewenang penggeser volume
/// sistem di HP. Yang BISA diatur aplikasi hanyalah KE MANA notifikasi itu
/// merujuk: [normal] ikut volume "Notifikasi" HP, [keras] ikut volume
/// "Alarm" HP (biasanya lebih keras & bisa menembus mode senyap/Do Not
/// Disturb -- makanya lebih cocok untuk adzan).
enum VolumeAdzan { normal, keras }

class AdzanNotificationService {
  AdzanNotificationService._internal();
  static final AdzanNotificationService instance = AdzanNotificationService._internal();

  static const _boxName = 'adzan_settings';
  static const _keyAktif = 'aktif';
  static const _keyVolume = 'volume';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _namaWaktu = ['Subuh', 'Dzuhur', 'Ashar', 'Maghrib', "Isya'"];

  Future<Box> _box() async {
    if (!Hive.isBoxOpen(_boxName)) return Hive.openBox(_boxName);
    return Hive.box(_boxName);
  }

  Future<bool> isAktif() async {
    final box = await _box();
    return box.get(_keyAktif, defaultValue: false) as bool;
  }

  Future<VolumeAdzan> getVolume() async {
    final box = await _box();
    final idx = box.get(_keyVolume, defaultValue: 0) as int;
    return VolumeAdzan.values[idx];
  }

  Future<void> setVolume(VolumeAdzan v) async {
    final box = await _box();
    await box.put(_keyVolume, v.index);
  }

  /// Inisialisasi plugin. Dipanggil sekali saat aplikasi mulai -- TIDAK
  /// menyalakan notifikasi apa pun dengan sendirinya.
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  /// Mengaktifkan notifikasi adzan (default OFF sebelum ini dipanggil).
  /// Meminta izin notifikasi eksplisit ke pengguna di sini (bukan otomatis
  /// saat app dibuka), sesuai permintaan "default mati, minta izin/aktif
  /// hanya kalau pengguna nyalakan sendiri".
  Future<bool> aktifkan() async {
    await initialize();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission() ?? true;

    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final grantedIos = await iosPlugin?.requestPermissions(alert: true, badge: true, sound: true) ?? true;

    if (granted && grantedIos) {
      final box = await _box();
      await box.put(_keyAktif, true);
      return true;
    }
    return false;
  }

  Future<void> matikan() async {
    final box = await _box();
    await box.put(_keyAktif, false);
    await _plugin.cancelAll();
  }

  /// Menjadwalkan ulang notifikasi 5 waktu shalat fardhu untuk HARI INI.
  /// Panggil ini setiap kali widget waktu shalat di Home dimuat.
  ///
  /// CATATAN JUJUR soal keandalan: TIDAK ADA penjadwalan ulang otomatis di
  /// latar belakang tanpa membuka aplikasi (butuh WorkManager + boot-
  /// completed receiver yang jauh lebih kompleks, belum diimplementasikan).
  /// Jadwal hari ini akan selalu benar SELAMA aplikasi dibuka minimal
  /// sekali per hari; kalau tidak dibuka berhari-hari, notifikasi hari-hari
  /// itu tidak akan terjadwal.
  Future<void> jadwalkanUntukHariIni(List<WaktuShalatEntry> entries) async {
    if (!await isAktif()) return;
    await initialize();
    await _plugin.cancelAll();

    final volume = await getVolume();
    final now = DateTime.now();

    for (final entry in entries) {
      if (!_namaWaktu.contains(entry.nama)) continue;
      if (entry.waktuDaerah.isBefore(now)) continue;

      final tzWaktu = tz.TZDateTime.from(entry.waktuDaerah, tz.local);
      final id = entry.nama.hashCode & 0x7FFFFFFF;

      await _plugin.zonedSchedule(
        id,
        'Waktu ${entry.nama}',
        'Telah masuk waktu shalat ${entry.nama}.',
        tzWaktu,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'adzan_channel_${volume.name}',
            'Notifikasi Adzan (${volume == VolumeAdzan.keras ? 'Keras' : 'Normal'})',
            channelDescription: 'Notifikasi pengingat waktu shalat',
            importance: Importance.max,
            priority: Priority.high,
            audioAttributesUsage: volume == VolumeAdzan.keras
                ? AudioAttributesUsage.alarm
                : AudioAttributesUsage.notification,
            category: AndroidNotificationCategory.alarm,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }
}
