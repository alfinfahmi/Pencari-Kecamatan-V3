/// KONFIGURASI SUPABASE -- WAJIB DIISI SEBELUM FITUR KOREKSI/MODERASI AKTIF.
///
/// Cara mendapatkan nilai ini (sistem API key BARU Supabase -- anon key
/// lama dijadwalkan deprecated akhir 2026, jadi pakai yang ini):
/// 1. Buat project baru di https://supabase.com (gratis untuk skala kecil).
/// 2. Buka project -> Settings -> API Keys.
/// 3. Salin "Project URL" -> [supabaseUrl] di bawah.
/// 4. Di tab "API Keys": jika belum ada, klik "Create new API keys" untuk
///    membuat Publishable key & Secret key. Salin nilai **Publishable key**
///    (format sb_publishable_...) -> [supabasePublishableKey] di bawah.
///    JANGAN pakai Secret key (sb_secret_...) di sini -- itu untuk
///    server/backend, bukan aplikasi Flutter.
/// 5. Buka SQL Editor -> jalankan seluruh isi file `supabase/schema.sql`
///    (satu folder di atas lib/) untuk membuat tabel & policy.
///
/// CATATAN KEAMANAN: publishable key AMAN ditaruh di kode aplikasi (bukan
/// rahasia seperti secret key) -- akses sebenarnya dibatasi oleh Row Level
/// Security (RLS) yang sudah didefinisikan di schema.sql, BUKAN oleh
/// kerahasiaan key ini.
class SupabaseConfig {
  static const String supabaseUrl = 'https://jtmpztriyqjcydkvladm.supabase.co/rest/v1/';
  static const String supabasePublishableKey = 'sb_publishable_PLGNlFYY-OhKIZlPRCSyZg_VC5OfV_t';

  static bool get isConfigured =>
      supabaseUrl != 'https://jtmpztriyqjcydkvladm.supabase.co/rest/v1/' &&
      supabasePublishableKey != 'sb_publishable_PLGNlFYY-OhKIZlPRCSyZg_VC5OfV_t' &&
      supabaseUrl.isNotEmpty &&
      supabasePublishableKey.isNotEmpty;
}
