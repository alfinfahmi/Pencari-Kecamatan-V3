import 'package:flutter/material.dart';
import '../main.dart' show themeModeNotifier;
import '../models/kecamatan_model.dart';
import '../services/app_data_service.dart';
import '../services/favorite_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import '../widgets/kecamatan_card.dart';
import '../widgets/home_prayer_widget.dart';
import '../widgets/watermark_footer.dart';
import 'moderation_panel_screen.dart';
import 'adzan_settings_screen.dart';

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

    if (requestId != _searchRequestId || !mounted) return;

    setState(() {
      _results = [...referensiMatch, ...kecamatanMatch];
      _searching = false;
    });
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

  Future<List<KecamatanModel>> _resolveIds(List<String> ids) async {
    return ids.map((id) => _data.findById(id)).whereType<KecamatanModel>().toList();
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
            const Expanded(child: Text('Koordinat Kec. Tashil', overflow: TextOverflow.ellipsis)),
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
          // Widget waktu shalat & hero pencarian disembunyikan saat sedang
          // menampilkan hasil pencarian -- keduanya makan banyak ruang
          // layar, membuat kartu hasil (setelah dibuka) jadi terlalu sempit
          // untuk menampilkan koordinat & tombol menu sekaligus.
          if (_tab == _Tab.pencarian && !_sudahMencari) const HomePrayerWidget(),
          if (_tab == _Tab.pencarian && !_sudahMencari) _buildHeroSearch(isDark),
          if (_tab == _Tab.pencarian && _sudahMencari) _buildSearchBarRingkas(isDark),
          _buildTabBar(),
          const SizedBox(height: 4),
          Expanded(child: _buildList()),
          const WatermarkFooter(),
        ],
      ),
    );
  }

  /// Versi ringkas search bar (1 baris saja, tanpa judul/subjudul/chip
  /// saran) -- dipakai saat hasil pencarian sedang tampil, supaya kartu
  /// hasil (terutama saat dibuka) punya ruang layar yang cukup.
  Widget _buildSearchBarRingkas(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Cari Kecamatan, Kabupaten...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSearch(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white12 : Colors.black.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pencarian Koordinat\nGeografis', style: AppTypography.headlineLg(color: AppColors.emerald)),
          const SizedBox(height: 6),
          Text(
            'Cari data astronomi presisi untuk wilayah mana pun di Indonesia.',
            style: AppTypography.bodyMd(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
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
                  ),
                ),
              ),
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

  Widget _buildList() {
    if (_tab == _Tab.pencarian) {
      if (_searching) {
        return const Center(child: CircularProgressIndicator());
      }
      return _listView(_results, tampilkanHeader: _sudahMencari);
    }

    final future = _tab == _Tab.favorit
        ? _favService.getFavoriteIds().then(_resolveIds)
        : _favService.getHistoryIds().then(_resolveIds);

    return FutureBuilder<List<KecamatanModel>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!;
        if (items.isEmpty) {
          return Center(
            child: Text(
              _tab == _Tab.favorit ? 'Belum ada lokasi favorit' : 'Belum ada riwayat pencarian',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          );
        }
        return _listView(items);
      },
    );
  }

  Widget _listView(List<KecamatanModel> items, {bool tampilkanHeader = false}) {
    if (items.isEmpty) {
      return Center(
        child: Text('Tidak ditemukan', style: TextStyle(color: Colors.grey.shade500)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      itemCount: items.length + (tampilkanHeader ? 1 : 0),
      itemBuilder: (context, index) {
        if (tampilkanHeader) {
          if (index == 0) return _headerHasilPencarian(items.length);
          index -= 1;
        }
        final item = items[index];
        return KecamatanCard(
          data: item,
          isFavorite: _favoriteIds.contains(item.id),
          onToggleFavorite: () => _toggleFavorite(item.id),
          awalTerbuka: index == 0,
        );
      },
    );
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
