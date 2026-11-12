import '../../../production/shared/models/label_usage_status.dart';

class BarangDagangLabel {
  const BarangDagangLabel({
    required this.code,
    required this.name,
    required this.supplier,
    required this.qty,
    required this.remainingQty,
    required this.used,
    required this.isPartial,
    required this.printCount,
    this.receipt = '',
    this.blok = '',
    this.idLokasi = '',
    this.notes = '',
  });
  final String code, name, supplier, receipt, blok, idLokasi, notes;
  final double qty, remainingQty;
  final bool used, isPartial;
  final int printCount;
  String get location => '$blok$idLokasi';
  LabelUsageStatus get usageStatus => used || remainingQty <= 0
      ? LabelUsageStatus.habis
      : isPartial || remainingQty < qty
      ? LabelUsageStatus.terpakai
      : LabelUsageStatus.belumDipakai;
  bool get hasStock => !used && remainingQty > 0;

  factory BarangDagangLabel.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key]?.toString().trim() ?? '';
    double number(dynamic value) {
      final n = value is num
          ? value.toDouble()
          : double.tryParse('$value') ?? 0;
      return n.isFinite && n >= 0 ? n : 0;
    }

    bool flag(dynamic value) =>
        value == true ||
        value == 1 ||
        value == '1' ||
        value?.toString().toLowerCase() == 'true';
    final code = text('NoBarangDagang');
    if (code.isEmpty) {
      throw const FormatException('Nomor label Barang Dagang tidak valid.');
    }
    final qty = number(json['Qty']);
    final used = flag(json['Used']) || text('DateUsage').isNotEmpty;
    final remaining = used
        ? 0.0
        : number(json['QtySisa'] ?? qty).clamp(0.0, qty).toDouble();
    final count = number(json['HasBeenPrinted']).toInt();
    return BarangDagangLabel(
      code: code,
      name: text('NamaBarangDagang'),
      supplier: text('NamaSupplier'),
      qty: qty,
      remainingQty: remaining,
      used: used,
      isPartial: flag(json['IsPartial']),
      printCount: count,
      receipt: text('NoPenerimaan'),
      blok: text('Blok'),
      idLokasi: text('IdLokasi'),
      notes: text('Keterangan'),
    );
  }
}

class BarangDagangLabelPage {
  const BarangDagangLabelPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.total,
  });
  final List<BarangDagangLabel> items;
  final int page, totalPages, total;
}
