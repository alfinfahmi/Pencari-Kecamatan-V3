import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../config/supabase_config.dart';
import '../models/koreksi_model.dart';

/// Menangani autentikasi, pengiriman usulan koreksi (dengan antrean lokal
/// bila offline), dan operasi panel moderasi (approve/reject).
///
/// PENTING: fitur ini hanya aktif jika [SupabaseConfig.isConfigured] true
/// (lihat lib/config/supabase_config.dart) -- project ini butuh Supabase
/// project milik Anda sendiri, tidak disertakan otomatis.
class SupabaseService {
  SupabaseService._internal();
  static final SupabaseService instance = SupabaseService._internal();

  static const _antreanBoxName = 'antrean_koreksi_offline';

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !SupabaseConfig.isConfigured) return;
    await sb.Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      // Pakai 'publishableKey' (sistem API key baru Supabase), BUKAN
      // 'anonKey' yang lama -- anon key dijadwalkan deprecated akhir 2026.
      // Parameter 'anonKey' masih diterima package ini untuk kompatibilitas
      // mundur, tapi 'publishableKey' diprioritaskan & jadi cara resmi ke depan.
      publishableKey: SupabaseConfig.supabasePublishableKey,
    );
    _initialized = true;
  }

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  bool get isLoggedIn => _initialized && _client.auth.currentUser != null;
  String? get userId => _initialized ? _client.auth.currentUser?.id : null;

  Future<void> daftar({required String email, required String password, required String nama}) async {
    await _client.auth.signUp(email: email, password: password, data: {'nama': nama});
  }

  Future<void> masuk({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> keluar() async {
    await _client.auth.signOut();
  }

  /// Mengambil role pengguna saat ini ('umum', 'kontributor', 'admin').
  /// Mengembalikan 'umum' jika belum login atau Supabase belum dikonfigurasi.
  Future<String> getRole() async {
    if (!isLoggedIn) return 'umum';
    final res = await _client.from('profiles').select('role').eq('id', userId!).single();
    return res['role'] as String? ?? 'umum';
  }

  // --- Antrean offline ---

  Future<Box<String>> _antreanBox() async {
    if (!Hive.isBoxOpen(_antreanBoxName)) return Hive.openBox<String>(_antreanBoxName);
    return Hive.box<String>(_antreanBoxName);
  }

  Future<int> jumlahAntreanBelumTerkirim() async {
    final box = await _antreanBox();
    return box.length;
  }

  /// Kirim usulan koreksi. Jika online & berhasil, langsung masuk Supabase.
  /// Jika gagal (offline/error jaringan), otomatis disimpan ke antrean lokal
  /// dan akan dicoba kirim ulang lewat [prosesAntrean].
  Future<bool> kirimKoreksi(KoreksiModel koreksi) async {
    if (!SupabaseConfig.isConfigured) {
      await _simpanKeAntrean(koreksi);
      return false;
    }
    try {
      await _client.from('koreksi_koordinat').insert(koreksi.toInsertJson());
      return true;
    } catch (e) {
      await _simpanKeAntrean(koreksi);
      return false;
    }
  }

  Future<void> _simpanKeAntrean(KoreksiModel koreksi) async {
    final box = await _antreanBox();
    final key = DateTime.now().millisecondsSinceEpoch.toString();
    await box.put(key, json.encode(koreksi.toInsertJson()));
  }

  /// Coba kirim ulang semua usulan yang tersimpan di antrean lokal (dipanggil
  /// mis. saat aplikasi dibuka & terdeteksi ada koneksi internet).
  Future<int> prosesAntrean() async {
    if (!SupabaseConfig.isConfigured || !isLoggedIn) return 0;
    final box = await _antreanBox();
    int berhasil = 0;
    for (final key in box.keys.toList()) {
      try {
        final data = json.decode(box.get(key)!) as Map<String, dynamic>;
        await _client.from('koreksi_koordinat').insert(data);
        await box.delete(key);
        berhasil++;
      } catch (_) {
        // Masih gagal (mis. masih offline) -- biarkan di antrean, coba lagi nanti.
        break;
      }
    }
    return berhasil;
  }

  // --- Panel moderasi (khusus kontributor & admin, dibatasi RLS server-side) ---

  Future<List<KoreksiModel>> ambilUsulanPending() async {
    final res = await _client
        .from('koreksi_koordinat')
        .select('*, profiles(nama, role)')
        .eq('status', 'pending')
        .order('created_at');
    return (res as List).map((e) => KoreksiModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> setujuiKoreksi(String id, {String? catatan}) async {
    await _client.from('koreksi_koordinat').update({
      'status': 'approved',
      if (catatan != null) 'catatan_evaluasi': catatan,
    }).eq('id', id);
  }

  Future<void> tolakKoreksi(String id, {String? catatan}) async {
    await _client.from('koreksi_koordinat').update({
      'status': 'rejected',
      if (catatan != null) 'catatan_evaluasi': catatan,
    }).eq('id', id);
  }
}
