/// Row dari `GET /api/mst-supplier` — backend JOIN-ready (IdSupplier,
/// NmSupplier, Initial, NoTlp, Enable).
class SupplierItem {
  const SupplierItem({
    required this.idSupplier,
    required this.namaSupplier,
    this.initial = '',
    this.noTlp = '',
    this.enable = true,
  });

  final int idSupplier;
  final String namaSupplier;
  final String initial;
  final String noTlp;
  final bool enable;

  factory SupplierItem.fromJson(Map<String, dynamic> j) {
    bool toBool(dynamic v) {
      if (v == null) return true;
      if (v is bool) return v;
      if (v is num) return v != 0;
      final s = v.toString().trim().toLowerCase();
      return s == '1' || s == 'true' || s == 'y';
    }

    int toInt(dynamic v) {
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    return SupplierItem(
      idSupplier: toInt(j['IdSupplier'] ?? j['idSupplier'] ?? j['id']),
      namaSupplier:
          (j['NmSupplier'] ?? j['NamaSupplier'] ?? j['namaSupplier'] ?? '')
              .toString(),
      initial: (j['Initial'] ?? j['initial'] ?? '').toString(),
      noTlp: (j['NoTlp'] ?? j['noTlp'] ?? '').toString(),
      enable: toBool(j['Enable'] ?? j['IsEnable'] ?? j['enable']),
    );
  }

  String get displayName => enable ? namaSupplier : '$namaSupplier (non-aktif)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplierItem &&
          runtimeType == other.runtimeType &&
          idSupplier == other.idSupplier;

  @override
  int get hashCode => idSupplier.hashCode;
}
