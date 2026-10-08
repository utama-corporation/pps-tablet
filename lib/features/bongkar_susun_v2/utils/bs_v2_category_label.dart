import 'package:flutter/material.dart';

const Map<String, String> _bsV2CategoryLabels = {
  'washing': 'Washing',
  'broker': 'Broker',
  'crusher': 'Crusher',
  'gilingan': 'Gilingan',
  'mixer': 'Mixer',
  'furnitureWip': 'Furniture WIP',
  'barangJadi': 'Barang Jadi',
  'bahanBaku': 'Bahan Baku',
  'bonggolan': 'Bonggolan',
  'reject': 'Reject',
};

const Map<String, String> _bsV2CategoryCodes = {
  'washing': 'B.',
  'broker': 'D.',
  'crusher': 'F.',
  'gilingan': 'V.',
  'mixer': 'H.',
  'furnitureWip': 'BB.',
  'barangJadi': 'BA.',
  'bahanBaku': 'A.',
  'bonggolan': 'M.',
  'reject': 'BF.',
};

/// Alias kategori yang mungkin dikirim server → key kanonik di atas.
/// Key dinormalisasi (lowercase, tanpa spasi/underscore/hyphen) sebelum dicari.
const Map<String, String> _bsV2CategoryAliases = {
  'washing': 'washing',
  'broker': 'broker',
  'crusher': 'crusher',
  'gilingan': 'gilingan',
  'mixer': 'mixer',
  'furniturewip': 'furnitureWip',
  'barangjadi': 'barangJadi',
  'bahanbaku': 'bahanBaku',
  'bonggolan': 'bonggolan',
  'reject': 'reject',
  'rejectv2': 'reject',
  'rejectv3': 'reject',
  'sortirreject': 'reject',
  'sortir': 'reject',
  'bf': 'reject',
};

/// Samakan penulisan `category` dari server dengan key kanonik modul ini.
/// Kategori kosong/tebakan dari prefix label sebagai fallback (label reject
/// selalu diawali `BF.`), supaya label reject tidak dianggap "kategori lain".
String bsV2NormalizeCategory(String? raw, {String? labelCode}) {
  final value = (raw ?? '').trim();
  if (_bsV2CategoryLabels.containsKey(value)) return value;

  final key = value.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
  if (key.isNotEmpty) return _bsV2CategoryAliases[key] ?? value;

  if ((labelCode ?? '').trim().toUpperCase().startsWith('BF')) return 'reject';
  return value;
}

String bsV2CategoryLabel(
  String? category, {
  String nullLabel = '-',
  String unknownLabel = 'Unknown',
}) {
  if (category == null) return nullLabel;
  return _bsV2CategoryLabels[category] ?? unknownLabel;
}

String bsV2CategoryLabelWithCode(
  String? category, {
  String nullLabel = '-',
  String unknownLabel = 'Bonggolan',
}) {
  if (category == null) return nullLabel;

  final label = _bsV2CategoryLabels[category] ?? unknownLabel;
  final code = _bsV2CategoryCodes[category] ?? _bsV2CategoryCodes['bonggolan']!;
  return '$label ($code)';
}

Widget bsV2CategoryBadge(String? category, {TextStyle? textStyle}) {
  final label = bsV2CategoryLabelWithCode(category);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F4F8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: textStyle),
  );
}
