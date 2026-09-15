import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/update_checker_service.dart';
import '../theme/app_theme.dart';

/// Banner "Update tersedia" -- muncul di atas Home kalau versi terbaru
/// di GitHub Release lebih baru dari yang terpasang.
///
/// PENTING -- perubahan alur (sebelumnya cuma buka URL di browser lalu
/// BERHENTI di situ): unduhan lewat browser TERNYATA tidak otomatis
/// lanjut ke instalasi -- pengguna harus tahu untuk membuka lagi file
/// yang sudah terunduh (lewat notifikasi/folder Downloads) secara
/// manual, langkah yang mudah terlewat/tidak disadari (dilaporkan
/// pengguna: unduhan selesai tapi aplikasi tetap versi lama). Sekarang:
/// unduh file APK LANGSUNG DI DALAM aplikasi (pakai `http`, disimpan ke
/// folder sementara), lalu otomatis buka dialog instal Android begitu
/// selesai -- satu alur tanpa perlu pengguna cari file secara manual.
/// Dialog konfirmasi instal Android SENDIRI tetap muncul seperti biasa
/// (tidak bisa/tidak seharusnya dilewati -- itu keamanan Android, bukan
/// sesuatu yang perlu/bisa "diperbaiki").
class UpdateBannerWidget extends StatefulWidget {
  const UpdateBannerWidget({super.key});

  @override
  State<UpdateBannerWidget> createState() => _UpdateBannerWidgetState();
}

class _UpdateBannerWidgetState extends State<UpdateBannerWidget> {
  InfoUpdate? _info;
  bool _ditutup = false;
  double? _progresUnduh; // null = belum mulai/selesai, 0.0-1.0 = sedang unduh
  String? _errorUnduh;

  @override
  void initState() {
    super.initState();
    _cek();
  }

  Future<void> _cek() async {
    final info = await UpdateCheckerService.instance.cekUpdate();
    if (mounted && info != null) setState(() => _info = info);
  }

  Future<void> _unduhDanInstal() async {
    final info = _info;
    if (info == null) return;

    setState(() {
      _progresUnduh = 0.0;
      _errorUnduh = null;
    });

    try {
      final request = http.Request('GET', Uri.parse(info.urlUnduhApk));
      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        throw Exception('Server mengembalikan status ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      var bytesTerunduh = 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        bytesTerunduh += chunk.length;
        if (totalBytes > 0 && mounted) {
          setState(() => _progresUnduh = bytesTerunduh / totalBytes);
        }
      }

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/aplikasi-falak-${info.versiTerbaru}.apk');
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      setState(() => _progresUnduh = null);

      final hasil = await OpenFilex.open(file.path);
      if (hasil.type != ResultType.done && mounted) {
        setState(() => _errorUnduh = 'Gagal membuka installer: ${hasil.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progresUnduh = null;
          _errorUnduh = 'Gagal mengunduh: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null || _ditutup) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sedangUnduh = _progresUnduh != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update_rounded, color: AppColors.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Update tersedia: ${info.versiTerbaru}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: isDark ? AppColors.textDark : AppColors.textLight)),
                    Text(
                      sedangUnduh
                          ? 'Mengunduh... ${(_progresUnduh! * 100).toStringAsFixed(0)}%'
                          : (_errorUnduh ?? 'Ketuk untuk unduh -- instalasi tetap butuh konfirmasi Anda'),
                      style: TextStyle(fontSize: 10.5, color: _errorUnduh != null ? Colors.red.shade300 : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
                    ),
                  ],
                ),
              ),
              if (!sedangUnduh)
                TextButton(
                  onPressed: _unduhDanInstal,
                  child: Text(_errorUnduh != null ? 'Coba Lagi' : 'Unduh', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              if (!sedangUnduh)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => setState(() => _ditutup = true),
                  tooltip: 'Tutup',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          if (sedangUnduh) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progresUnduh! > 0 ? _progresUnduh : null,
                backgroundColor: AppColors.gold.withOpacity(0.15),
                color: AppColors.gold,
                minHeight: 5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
