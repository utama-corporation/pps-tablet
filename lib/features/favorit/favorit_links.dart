import 'package:flutter/material.dart';

import '../../core/navigation/pps_menu_catalog.dart';
import '../report/model/report_item.dart';
import 'model/favorit_row.dart';

/// Tampilan + tujuan satu favorit, dipakai layar Favorit dan Dashboard.
class FavoritMeta {
  const FavoritMeta({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.menu,
    this.report,
  });

  final String title;

  /// 'Menu' atau 'Laporan'.
  final String subtitle;
  final IconData icon;

  /// Terisi bila favorit menu dan route-nya masih ada di katalog tablet.
  final PpsMenuItem? menu;

  /// Terisi bila favorit laporan dan laporannya ada di katalog tablet.
  final ReportItem? report;

  bool get available => menu?.route != null || report != null;
}

FavoritMeta favoritMeta(FavoritRow row) {
  if (row.tipe == 'menu') {
    final item = PpsMenuCatalog.forRoute(row.kode);
    return FavoritMeta(
      title: item?.title ?? _fallbackTitle(row.kode),
      subtitle: 'Menu',
      icon: item?.icon ?? Icons.apps_rounded,
      menu: item,
    );
  }
  final item = findFavoritReport(row.kode);
  return FavoritMeta(
    title: item?.title ?? _fallbackTitle(row.kode),
    subtitle: 'Laporan',
    icon: item?.icon ?? Icons.description_outlined,
    report: item,
  );
}

ReportItem? findFavoritReport(String kode) {
  for (final item in reportCatalogFlat) {
    final current = item.path ?? item.route ?? item.title;
    if (current == kode || item.title == kode) return item;
  }
  return null;
}

String _fallbackTitle(String kode) {
  final clean = kode.split('/').where((p) => p.isNotEmpty).toList();
  if (clean.isEmpty) return kode;
  final last = clean.last;
  return last[0].toUpperCase() + last.substring(1).replaceAll('-', ' ');
}
