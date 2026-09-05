import 'package:flutter/material.dart';
import '../main.dart' show themeModeNotifier;
import '../models/kecamatan_model.dart';
import '../models/custom_point_model.dart';
import '../services/app_data_service.dart';
import '../services/favorite_service.dart';
import '../services/custom_point_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/kecamatan_card.dart';
import '../widgets/home_prayer_widget.dart';
import '../widgets/watermark_footer.dart';
import 'moderation_panel_screen.dart';
import 'adzan_settings_screen.dart';
import 'tabel_ijtimak_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _Tab { pencarian, favorit, riwayat }

const _saranPencarian = ['Kediri, Jawa Timur', 'Jakarta Selatan', 'Banda Aceh', 'Denpasar, Bali'];

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  final _favService = FavoriteService();
  final _customPointService = CustomPointService();
  final _data = AppDataService.instance;

  List<KecamatanModel> _results = [];
  Set<String> _favoriteIds = {};
  _Tab _tab = _Tab.pencarian;
  bool _searching = false;
  bool _sudahMencari = false;

  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _results = _data.referensi;
  }

  Future<void> _loadFavorites() async {
    final ids = await _favService.getFavoriteIds();
    if (mounted) setState(() => _favoriteIds = ids.toSet());
  }

  Future<void> _onSearchChanged(String query) async {
    final requestId = ++_searchRequestId;

    setState(() {
      _tab = _Tab.pencarian;
      _sudahMencari = query.trim().isNotEmpty;
      if (query.trim().isEmpty) {
        _results = _data.referensi;
        _searching = false;
      } else {
        _searching = true;
      }
    });

    if (query.trim().isEmpty) return;

    final referensiMatch = _data.referensi.where(
      (r) => r.searchIndex.contains(query.toLowerCase()),
    );
    final kecamatanMatch = await _data.search(query);
    final titikKustomMatch = await _cariTitikKustom(query);

    if (requestId != _searchRequestId || !mounted) return;

    setState(() {
      _results = [...referensiMatch, ...kecamatanMatch, ...titikKustomMatch];
      _searching = false;
    });
  }

  /// Ubah titik kustom (CustomPointModel) jadi KecamatanModel sintetis
  /// supaya bisa dipakai KecamatanCard yang sama -- mewarisi zona waktu &
  /// UTC offset dari kecamatan induknya (titik kustom sendiri tidak
  /// menyimpan itu, karena selalu terikat ke kecamatan resmi).
  Future<List<KecamatanModel>> _cariTitikKustom(String query) async {
    final hasil = await _customPointService.search(query);
    return hasil.map((p) {
      final induk = _data.findById(p.kecamatanId);
      return KecamatanModel(
        id: 'custom_${p.id}',
        kecamatan: '${p.nama} (Titik Kustom)',
        kabupaten: p.kabupatenNama,
        provinsi: p.provinsiNama,
        lat: p.lat,
        lng: p.lng,
        latDms: null,
        lngDms: null,
        elevasiM: p.elevasiM,
        zonaWaktu: induk?.zonaWaktu,
        utcOffset: induk?.utcOffset,
      );
    }).toList();
  }

  void _cariSaran(String saran) {
    final kataKunci = saran.split(',').first.trim();
    _searchController.text = kataKunci;
    _onSearchChanged(kataKunci);
    _searchFocus.unfocus();
  }

  Future<void> _toggleFavorite(String id) async {
    await _favService.toggleFavorite(id);
    await _loadFavorites();
  }

  /// Selain ID kecamatan resmi (lewat AppDataService), juga tangani ID
  /// titik kustom (prefix "custom_") -- supaya favorit/riwayat pada titik
  /// kustom tidak "hilang" begitu saja karena AppDataService tidak
  /// mengenalnya.
  Future<List<KecamatanModel>> _resolveIds(List<String> ids) async {
    final hasil = <KecamatanModel>[];
    for (final id in ids) {
      if (id.startsWith('custom_')) {
        final pointId = id.substring('custom_'.length);
        final semuaTitik = await _customPointService.getAll();
        CustomPointModel? match;
        for (final p in semuaTitik) {
          if (p.id == pointId) { match = p; break; }
        }
        if (match != null) {
          final induk = _data.findById(match.kecamatanId);
          hasil.add(KecamatanModel(
            id: id,
            kecamatan: '${match.nama} (Titik Kustom)',
            kabupaten: match.kabupatenNama,
            provinsi: match.provinsiNama,
            lat: match.lat,
            lng: match.lng,
            latDms: null,
            lngDms: null,
            elevasiM: match.elevasiM,
            zonaWaktu: induk?.zonaWaktu,
            utcOffset: induk?.utcOffset,
          ));
        }
      } else {
        final match = _data.findById(id);
        if (match != null) hasil.add(match);
      }
    }
    return hasil;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.explore_rounded, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Aplikasi Falak', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          FutureBuilder<String>(
            future: SupabaseService.instance.getRole(),
            builder: (context, snapshot) {
              final role = snapshot.data ?? 'umum';
              if (role != 'kontributor' && role != 'admin') return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.fact_check_rounded),
                tooltip: 'Panel Moderasi',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ModerationPanelScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifikasi Adzan',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdzanSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_month_rounded),
            tooltip: 'Tabel Ijtimak',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TabelIjtimakScreen()),
              );
            },
          ),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeModeNotifier,
            builder: (context, mode, _) {
              final darkNow = mode == ThemeMode.dark ||
                  (mode == ThemeMode.system &&
                      MediaQuery.platformBrightnessOf(context) == Brightness.dark);
              return IconButton(
                icon: Icon(darkNow ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                tooltip: 'Ganti tema',
                onPressed: () {
                  themeModeNotifier.value = darkNow ? ThemeMode.light : ThemeMode.dark;
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                // Widget waktu shalat & hero pencarian disembunyikan saat
                // sedang menampilkan hasil pencarian -- keduanya makan
                // banyak ruang layar, membuat kartu hasil (setelah dibuka)
                // jadi terlalu sempit untuk menampilkan koordinat & tombol
                // menu sekaligus.
                //
                // PENTING: setiap sliver di sini WAJIB punya `key` unik.
                // Tanpa key, Flutter mencocokkan widget dalam List
                // berdasarkan POSISI/INDEKS, bukan identitas. Karena
                // HomePrayerWidget dihilangkan total (bukan cuma
                // disembunyikan) begitu mulai mengetik, posisi search bar
                // bergeser dari indeks ke-2 jadi ke-1 -- tanpa key, Flutter
                // mengira search bar di posisi baru itu widget yang
                // berbeda, lalu membongkar-ulang TextField-nya (kehilangan
                // fokus/keyboard tertutup). Key membuat Flutter tetap
                // mengenali search bar sebagai elemen yang SAMA meski
                // posisinya bergeser.
                if (_tab == _Tab.pencarian && !_sudahMencari)
                  SliverToBoxAdapter(key: const ValueKey('prayer_widget'), child: const HomePrayerWidget()),
                if (_tab == _Tab.pencarian)
                  SliverToBoxAdapter(key: const ValueKey('search_card'), child: _buildSearchCard(isDark)),
                SliverToBoxAdapter(key: const ValueKey('tab_bar'), child: _buildTabBar()),
                const SliverToBoxAdapter(key: ValueKey('spacer'), child: SizedBox(height: 4)),
                ..._buildListSlivers(),
              ],
            ),
          ),
          // Watermark SENGAJA di luar CustomScrollView -- tetap terlihat
          // permanen di bawah layar, tidak ikut ter-scroll bersama konten.
          const WatermarkFooter(),
        ],
      ),
    );
  }

  /// Versi ringkas search bar (1 baris saja, tanpa judul/subjudul/chip
  /// saran) -- dipakai saat hasil pencarian sedang tampil, supaya kartu
  /// hasil (terutama saat dibuka) punya ruang layar yang cukup.
  /// SATU widget search bar untuk kedua mode (hero besar / ringkas saat
  /// mencari) -- strukturnya SELALU SAMA (Container > Column > judul +
  /// Row(TextField) + chip saran), cuma bagian judul & chip yang
  /// disembunyikan pakai Visibility(maintainState: true) saat sedang
  /// mencari, BUKAN diganti dengan widget yang berbeda strukturnya.
  ///
  /// Ini sengaja dihindari: kalau TextField dipindah ke widget yang
  /// berbeda bentuk pohonnya (seperti sebelumnya: kartu besar vs bar
  /// ringkas terpisah), Flutter akan MEMBONGKAR & MEMBUAT ULANG elemen
  /// TextField-nya saat berpindah mode -- itulah yang menyebabkan
  /// keyboard tertutup sendiri tiap kali mulai mengetik huruf pertama.
  Widget _buildSearchCard(bool isDark) {
    return Container(
      margin: EdgeInsets.fromLTRB(14, _sudahMencari ? 10 : 8, 14, _sudahMencari ? 6 : 4),
      padding: EdgeInsets.fromLTRB(16, _sudahMencari ? 10 : 12, 16, _sudahMencari ? 10 : 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Visibility(
            visible: !_sudahMencari,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pencarian Koordinat Geografis',
                    style: AppTypography.headlineMd(color: AppColors.emerald).copyWith(fontSize: 15)),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  onSubmitted: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Cari Kecamatan, Kabupaten...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    isDense: true,
                  ),
                ),
              ),
              Visibility(
                visible: !_sudahMencari,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(9999),
                      onTap: () {
                        _onSearchChanged(_searchController.text);
                        _searchFocus.unfocus();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(13),
                        decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Visibility(
            visible: !_sudahMencari,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                SizedBox(
                  height: 32,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _saranPencarian.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final saran = _saranPencarian[i];
                      return InkWell(
                        onTap: () => _cariSaran(saran),
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(9999),
                          ),
                          child: Text(saran, style: AppTypography.bodyMd(color: Colors.grey.shade600).copyWith(fontSize: 12)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTabBar() {
    Widget tabButton(_Tab tab, String label, IconData icon) {
      final selected = _tab == tab;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tab = tab),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: selected ? AppColors.gold : Colors.transparent, width: 2.5),
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 18, color: selected ? AppColors.emerald : Colors.grey),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: selected ? AppColors.emerald : Colors.grey,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tabButton(_Tab.pencarian, 'Pencarian', Icons.search_rounded),
        tabButton(_Tab.favorit, 'Favorit', Icons.star_rounded),
        tabButton(_Tab.riwayat, 'Riwayat', Icons.history_rounded),
      ],
    );
  }

  /// Mengembalikan daftar SLIVER (bukan Widget biasa) untuk disisipkan
  /// langsung ke `CustomScrollView.slivers` -- supaya hasil pencarian ikut
  /// jadi bagian dari SATU area scroll bersama widget shalat/pencarian/tab
  /// di atasnya (bukan area scroll terpisah yang membatasi ruang).
  List<Widget> _buildListSlivers() {
    if (_tab == _Tab.pencarian) {
      if (_searching) {
        return [_sliverMuat()];
      }
      return _sliverDaftarLokasi(_results, tampilkanHeader: _sudahMencari);
    }

    final future = _tab == _Tab.favorit
        ? _favService.getFavoriteIds().then(_resolveIds)
        : _favService.getHistoryIds().then(_resolveIds);

    return [
      FutureBuilder<List<KecamatanModel>>(
        future: future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return _sliverMuat();
          final items = snapshot.data!;
          if (items.isEmpty) {
            return _sliverPesan(
              _tab == _Tab.favorit ? 'Belum ada lokasi favorit' : 'Belum ada riwayat pencarian',
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => KecamatanCard(
                data: items[index],
                isFavorite: _favoriteIds.contains(items[index].id),
                onToggleFavorite: () => _toggleFavorite(items[index].id),
                awalTerbuka: index == 0,
              ),
              childCount: items.length,
            ),
          );
        },
      ),
    ];
  }

  Widget _sliverMuat() {
    return const SliverToBoxAdapter(
      child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator())),
    );
  }

  Widget _sliverPesan(String pesan) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 160,
        child: Center(child: Text(pesan, style: TextStyle(color: Colors.grey.shade500))),
      ),
    );
  }

  List<Widget> _sliverDaftarLokasi(List<KecamatanModel> items, {bool tampilkanHeader = false}) {
    if (items.isEmpty) {
      return [_sliverPesan('Tidak ditemukan')];
    }
    return [
      if (tampilkanHeader) SliverToBoxAdapter(child: _headerHasilPencarian(items.length)),
      SliverPadding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => KecamatanCard(
              data: items[index],
              isFavorite: _favoriteIds.contains(items[index].id),
              onToggleFavorite: () => _toggleFavorite(items[index].id),
              awalTerbuka: index == 0,
            ),
            childCount: items.length,
          ),
        ),
      ),
    ];
  }

  Widget _headerHasilPencarian(int jumlah) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Hasil Pencarian', style: AppTypography.headlineMd().copyWith(fontSize: 16)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.15),
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Text('$jumlah lokasi ditemukan', style: AppTypography.bodyMd(color: Colors.grey.shade600).copyWith(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
