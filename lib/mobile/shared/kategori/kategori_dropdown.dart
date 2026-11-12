import 'package:flutter/material.dart';
import '../components/app_dropdown.dart'; // ⬅️ gunakan desain global

class KategoriDropdown extends StatelessWidget {
  final String? value; // key kategori terpilih
  final ValueChanged<String?>? onChanged;
  final bool includeSemua;
  final String semuaValue;
  final String semuaText;

  const KategoriDropdown({
    super.key,
    this.value,
    this.onChanged,
    this.includeSemua = true,
    this.semuaValue = 'semua',
    this.semuaText = 'Kategori (Semua)',
  });

  static const _kategoriOptions = <MapEntry<String, String>>[
    MapEntry('bahanbaku', 'Bahan Baku'),
    MapEntry('washing', 'Washing'),
    MapEntry('broker', 'Broker'),
    MapEntry('crusher', 'Crusher'),
    MapEntry('bonggolan', 'Bonggolan'),
    MapEntry('gilingan', 'Gilingan'),
    MapEntry('mixer', 'Mixer'),
    MapEntry('furniturewip', 'Furniture WIP'),
    MapEntry('barangjadi', 'Barang Jadi'),
    MapEntry('reject', 'Reject'),
  ];

  @override
  Widget build(BuildContext context) {
    // susun item dropdown (opsi semua + kategori lain)
    final items = <DropdownMenuItem<String>>[
      if (includeSemua)
        DropdownMenuItem(value: semuaValue, child: Text(semuaText)),
      ..._kategoriOptions.map((e) => DropdownMenuItem(
        value: e.key,
        child: Text(e.value),
      )),
    ];

    final effectiveValue = value ?? (includeSemua ? semuaValue : null);

    // 🔹 gunakan AppDropdown untuk konsistensi desain
    return AppDropdown<String>(
      value: effectiveValue,
      hint: 'Pilih Kategori',
      items: items,
      onChanged: (val) {
        if (onChanged == null) return;
        if (val == semuaValue) {
          onChanged!(null); // kirim null untuk “semua”
        } else {
          onChanged!(val);
        }
      },
    );
  }
}
