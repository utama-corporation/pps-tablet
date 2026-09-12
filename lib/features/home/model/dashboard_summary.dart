/// Satu titik data pada chart penjualan selesai per hari.
class DailySalesPoint {
  final DateTime date;
  final int count;

  const DailySalesPoint({required this.date, required this.count});
}

/// Ringkasan angka untuk kartu summary di dashboard. Tiap field nullable —
/// null berarti fetch metrik itu gagal (mis. endpoint 403 untuk role user
/// tertentu), supaya satu metrik yang gagal tidak menggagalkan seluruh
/// dashboard.
class DashboardSummary {
  final int? activeUsers;
  final int? activeMachines;
  final int? pendingMachines;
  final int? activeLocations;
  final int? activeWarehouses;
  final int? bongkarSusunToday;
  final int? sortirRejectToday;

  /// 7 titik data (hari ini mundur 6 hari), null berarti gagal fetch.
  final List<DailySalesPoint>? salesCompleteLast7Days;

  const DashboardSummary({
    this.activeUsers,
    this.activeMachines,
    this.pendingMachines,
    this.activeLocations,
    this.activeWarehouses,
    this.bongkarSusunToday,
    this.sortirRejectToday,
    this.salesCompleteLast7Days,
  });
}
