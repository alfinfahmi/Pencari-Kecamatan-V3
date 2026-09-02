import 'package:flutter/material.dart';

/// Tombol "Kembali ke Beranda" -- dipasang di AppBar layar-layar dalam
/// (Detail, Kompas, Ekspor Jadwal, dll.) supaya pengguna bisa langsung
/// kembali ke Halaman Utama tanpa perlu menekan tombol kembali berkali-kali
/// dari navigasi yang dalam (mis. Home -> Detail -> Kompas Layar Penuh).
class HomeButton extends StatelessWidget {
  const HomeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.home_rounded),
      tooltip: 'Kembali ke Beranda',
      onPressed: () {
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}
