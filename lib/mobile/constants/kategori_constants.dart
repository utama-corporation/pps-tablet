// lib/core/constants/kategori_constants.dart
class KategoriConstants {
  static const kategoriOptions = <MapEntry<String, String>>[
    MapEntry('semua', 'Semua'),
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

  static String getLabel(String? key) {
    if (key == null || key.isEmpty) return '-';
    final entry = kategoriOptions.firstWhere(
          (e) => e.key.toLowerCase() == key.toLowerCase(),
      orElse: () => const MapEntry('', '-'),
    );
    return entry.value;
  }
}
