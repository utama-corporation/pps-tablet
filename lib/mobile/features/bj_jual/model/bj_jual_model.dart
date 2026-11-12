class BjJual {
  final String noBJJual;
  final String tanggal;
  final int idPembeli;
  final String namaPembeli;
  final String remark;

  BjJual({
    required this.noBJJual,
    required this.tanggal,
    required this.idPembeli,
    required this.namaPembeli,
    required this.remark,
  });

  factory BjJual.fromJson(Map<String, dynamic> json) {
    return BjJual(
      noBJJual: json['NoBJJual'] ?? '',
      tanggal: json['Tanggal']?.toString() ?? '',
      idPembeli: json['IdPembeli'] ?? 0,
      namaPembeli: json['NamaPembeli'] ?? '-',
      remark: json['Remark'] ?? '',
    );
  }
}
