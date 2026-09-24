// lib/features/production/shared/models/qc_downtime_item.dart
/// Satu catatan downtime QC per jam (washing / broker):
/// keterangan teks + jam bucket produksi (hourStart) yang dicatat.
class QcDowntimeItem {
  final int id;
  final String noProduksi;
  final int? idMesin;
  final String? hourStart;
  final String? keterangan;
  final DateTime? dateTimeCreate;

  const QcDowntimeItem({
    required this.id,
    required this.noProduksi,
    this.idMesin,
    this.hourStart,
    this.keterangan,
    this.dateTimeCreate,
  });

  factory QcDowntimeItem.fromJson(Map<String, dynamic> j) {
    return QcDowntimeItem(
      id: (j['id'] as num?)?.toInt() ?? 0,
      noProduksi: j['noProduksi']?.toString() ?? '',
      idMesin: (j['idMesin'] as num?)?.toInt(),
      hourStart: j['hourStart']?.toString(),
      keterangan: j['keterangan']?.toString(),
      dateTimeCreate: DateTime.tryParse(
        j['dateTimeCreate']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}

/// Header produksi (diambil dari tabel header produksi, bukan dari QC).
class QcDowntimeHeader {
  final String noProduksi;
  final String? tglProduksi;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;

  const QcDowntimeHeader({
    required this.noProduksi,
    this.tglProduksi,
    this.shift,
    this.hourStart,
    this.hourEnd,
  });

  factory QcDowntimeHeader.fromJson(Map<String, dynamic> j) {
    return QcDowntimeHeader(
      noProduksi: j['noProduksi']?.toString() ?? '',
      tglProduksi: j['tglProduksi']?.toString(),
      shift: (j['shift'] as num?)?.toInt(),
      hourStart: j['hourStart']?.toString(),
      hourEnd: j['hourEnd']?.toString(),
    );
  }
}

/// Satu bucket jam produksi: jendela input QC (opensAt..closesAt).
/// opensAt = akhir jam produksi (QC jam 07-08 baru bisa diinput dari 08:00),
/// closesAt = opensAt + 60 menit.
class QcDowntimeBucket {
  final String hourStart;
  final String hourEnd;
  final DateTime opensAt;
  final DateTime closesAt;
  final String label;

  const QcDowntimeBucket({
    required this.hourStart,
    required this.hourEnd,
    required this.opensAt,
    required this.closesAt,
    required this.label,
  });

  factory QcDowntimeBucket.fromJson(Map<String, dynamic> j) {
    return QcDowntimeBucket(
      hourStart: j['hourStart']?.toString() ?? '',
      hourEnd: j['hourEnd']?.toString() ?? '',
      opensAt: DateTime.tryParse(j['opensAt']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      closesAt: DateTime.tryParse(j['closesAt']?.toString() ?? '')?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      label: j['label']?.toString() ?? '',
    );
  }
}

/// Hasil GET /api/production/{washing|broker}/:noProduksi/qc
/// { header, items, buckets }
class QcDowntimeDetail {
  final QcDowntimeHeader header;
  final List<QcDowntimeItem> items;
  final List<QcDowntimeBucket> buckets;

  const QcDowntimeDetail({
    required this.header,
    required this.items,
    required this.buckets,
  });

  factory QcDowntimeDetail.fromJson(Map<String, dynamic> j) {
    final headerRaw = j['header'] as Map<String, dynamic>? ?? const {};
    final List itemsRaw = (j['items'] ?? []) as List;
    final List bucketsRaw = (j['buckets'] ?? []) as List;
    return QcDowntimeDetail(
      header: QcDowntimeHeader.fromJson(headerRaw),
      items: itemsRaw
          .map((e) => QcDowntimeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      buckets: bucketsRaw
          .map((e) => QcDowntimeBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}