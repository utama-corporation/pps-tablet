import '../../bongkar_susun_v2/model/bs_v2_transaction.dart';
import '../../bongkar_susun_v2/repository/bs_v2_repository.dart';
import '../../production/broker/repository/broker_production_repository.dart';
import '../../production/crusher/repository/crusher_production_repository.dart';
import '../../production/gilingan/repository/gilingan_production_repository.dart';
import '../../production/hot_stamp/repository/hot_stamp_production_repository.dart';
import '../../production/inject/repository/inject_production_repository.dart';
import '../../production/key_fitting/repository/key_fitting_production_repository.dart';
import '../../production/mixer/repository/mixer_production_repository.dart';
import '../../production/packing/repository/packing_production_repository.dart';
import '../../production/spanner/repository/spanner_production_repository.dart';
import '../../production/washing/repository/washing_production_repository.dart';
import '../../penjualan/model/penjualan_header_model.dart';
import '../../penjualan/repository/penjualan_repository.dart';
import '../../shared/lokasi/lokasi_repository.dart';
import '../../sortir_reject_v2/model/sr_v2_transaction.dart';
import '../../sortir_reject_v2/repository/sr_v2_repository.dart';
import '../../stock_opname_v2/repository/so_v2_user_lokasi_access_repository.dart';
import '../../warehouse/repository/warehouse_repository.dart';
import '../model/dashboard_summary.dart';

/// Agregasi angka dashboard dari endpoint master yang sudah ada:
/// - User aktif: GET /api/stock-opname-v2/lokasi-access/users (server sudah
///   filter WHERE IsEnable = 1)
/// - Mesin aktif: satu endpoint status-mesin PER departemen produksi (yang
///   sama persis dipakai masing-masing "mesin screen" produksi), dijumlah
///   dari `isActive` (mesin punya produksi *hari ini* yang sedang berjalan —
///   bukan cuma flag Enable master data)
/// - Lokasi aktif (blok/lokasi): GET /api/mst-lokasi (server sudah filter
///   Enable = 1)
/// - Warehouse aktif: GET /api/mst/warehouse (server sudah filter Enable = 1
///   by default)
/// - Bongkar Susun / Sortir Reject hari ini: GET /api/bongkar-susun-v2 dan
///   GET /api/sortir-reject-v2 (list terbaru dulu), difilter client-side by
///   tanggal == hari ini — belum ada filter tanggal di endpoint list-nya
/// - Penjualan selesai 7 hari terakhir: GET /api/penjualan dengan
///   dateFrom/dateTo/status=complete (server sudah filter, tinggal di-group
///   per tanggal)
class DashboardSummaryRepository {
  final SoV2UserLokasiAccessRepository _userRepo;
  final LokasiRepository _lokasiRepo;
  final WarehouseRepository _warehouseRepo;
  final BsV2Repository _bsV2Repo;
  final SrV2Repository _srV2Repo;
  final PenjualanRepository _penjualanRepo;

  final BrokerProductionRepository _brokerRepo;
  final CrusherProductionRepository _crusherRepo;
  final GilinganProductionRepository _gilinganRepo;
  final HotStampProductionRepository _hotStampRepo;
  final InjectProductionRepository _injectRepo;
  final KeyFittingProductionRepository _keyFittingRepo;
  final MixerProductionRepository _mixerRepo;
  final PackingProductionRepository _packingRepo;
  final SpannerProductionRepository _spannerRepo;
  final WashingProductionRepository _washingRepo;

  DashboardSummaryRepository({
    SoV2UserLokasiAccessRepository? userRepo,
    LokasiRepository? lokasiRepo,
    WarehouseRepository? warehouseRepo,
    BsV2Repository? bsV2Repo,
    SrV2Repository? srV2Repo,
    PenjualanRepository? penjualanRepo,
    BrokerProductionRepository? brokerRepo,
    CrusherProductionRepository? crusherRepo,
    GilinganProductionRepository? gilinganRepo,
    HotStampProductionRepository? hotStampRepo,
    InjectProductionRepository? injectRepo,
    KeyFittingProductionRepository? keyFittingRepo,
    MixerProductionRepository? mixerRepo,
    PackingProductionRepository? packingRepo,
    SpannerProductionRepository? spannerRepo,
    WashingProductionRepository? washingRepo,
  }) : _userRepo = userRepo ?? SoV2UserLokasiAccessRepository(),
       _lokasiRepo = lokasiRepo ?? LokasiRepository(),
       _warehouseRepo = warehouseRepo ?? WarehouseRepository(),
       _bsV2Repo = bsV2Repo ?? BsV2Repository(),
       _srV2Repo = srV2Repo ?? SrV2Repository(),
       _penjualanRepo = penjualanRepo ?? PenjualanRepository(),
       _brokerRepo = brokerRepo ?? BrokerProductionRepository(),
       _crusherRepo = crusherRepo ?? CrusherProductionRepository(),
       _gilinganRepo = gilinganRepo ?? GilinganProductionRepository(),
       _hotStampRepo = hotStampRepo ?? HotStampProductionRepository(),
       _injectRepo = injectRepo ?? InjectProductionRepository(),
       _keyFittingRepo = keyFittingRepo ?? KeyFittingProductionRepository(),
       _mixerRepo = mixerRepo ?? MixerProductionRepository(),
       _packingRepo = packingRepo ?? PackingProductionRepository(),
       _spannerRepo = spannerRepo ?? SpannerProductionRepository(),
       _washingRepo = washingRepo ?? WashingProductionRepository();

  Future<DashboardSummary> fetchSummary() async {
    final userCountFuture = _countActiveUsers();
    final machineCountsFuture = _countMachineStatuses();
    final locationCountFuture = _countActiveLocations();
    final warehouseCountFuture = _countActiveWarehouses();
    final bongkarSusunFuture = _countBongkarSusunToday();
    final sortirRejectFuture = _countSortirRejectToday();
    final salesLast7DaysFuture = _fetchSalesCompleteLast7Days();

    final machineCounts = await machineCountsFuture;

    return DashboardSummary(
      activeUsers: await userCountFuture,
      activeMachines: machineCounts.active,
      pendingMachines: machineCounts.pending,
      activeLocations: await locationCountFuture,
      activeWarehouses: await warehouseCountFuture,
      bongkarSusunToday: await bongkarSusunFuture,
      sortirRejectToday: await sortirRejectFuture,
      salesCompleteLast7Days: await salesLast7DaysFuture,
    );
  }

  Future<int?> _countActiveUsers() async {
    try {
      final users = await _userRepo.fetchAllUsers();
      return users.length;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _countActiveLocations() async {
    try {
      final lokasiList = await _lokasiRepo.fetchLokasiList();
      return lokasiList.where((l) => l.enable).length;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _countActiveWarehouses() async {
    try {
      final warehouses = await _warehouseRepo.fetchAll();
      return warehouses.length;
    } catch (_) {
      return null;
    }
  }

  /// Jumlah transaksi Bongkar Susun dengan tanggal = hari ini. Belum ada
  /// endpoint list dengan filter tanggal server-side, jadi diambil dari
  /// `fetchAll` (list terbaru dulu, page 1 pageSize 200 — cap maksimum yang
  /// didukung backend) lalu difilter client-side dengan `tanggal`.
  Future<int?> _countBongkarSusunToday() async {
    try {
      final res = await _bsV2Repo.fetchAll(page: 1, pageSize: 200);
      final items = (res['items'] as List).cast<BsV2Transaction>();
      return items.where((t) => _isToday(t.tanggal)).length;
    } catch (_) {
      return null;
    }
  }

  /// Jumlah transaksi Sortir Reject dengan tanggal = hari ini — sama seperti
  /// [_countBongkarSusunToday], diambil dari `fetchAll` lalu difilter
  /// client-side dengan `tanggal`.
  Future<int?> _countSortirRejectToday() async {
    try {
      final res = await _srV2Repo.fetchAll(page: 1, pageSize: 200);
      final items = (res['items'] as List).cast<SrV2Transaction>();
      return items.where((t) => _isToday(t.tanggal)).length;
    } catch (_) {
      return null;
    }
  }

  /// Jumlah transaksi Penjualan yang sudah selesai (IsComplete = 1) per hari,
  /// untuk 7 hari terakhir (hari ini mundur 6 hari). Server sudah memfilter
  /// by `dateFrom`/`dateTo` dan `status: 'complete'` (WHERE IsComplete = 1),
  /// jadi tidak perlu filter client-side — cuma perlu di-group per tanggal.
  /// Di-loop per halaman kalau totalnya melebihi satu pageSize.
  Future<List<DailySalesPoint>?> _fetchSalesCompleteLast7Days() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startDate = today.subtract(const Duration(days: 6));

      final countByDay = <DateTime, int>{
        for (var i = 0; i < 7; i++) startDate.add(Duration(days: i)): 0,
      };

      var page = 1;
      var totalPages = 1;
      do {
        final res = await _penjualanRepo.fetchAll(
          page: page,
          pageSize: 100,
          dateFrom: startDate,
          dateTo: today,
          status: 'complete',
        );
        final items = (res['items'] as List).cast<PenjualanHeader>();
        for (final item in items) {
          final tanggal = item.tanggal;
          if (tanggal == null) continue;
          final local = tanggal.toLocal();
          final day = DateTime(local.year, local.month, local.day);
          if (countByDay.containsKey(day)) {
            countByDay[day] = countByDay[day]! + 1;
          }
        }
        totalPages = (res['totalPages'] as int?) ?? 1;
        page++;
      } while (page <= totalPages);

      final sorted = countByDay.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      return sorted
          .map((e) => DailySalesPoint(date: e.key, count: e.value))
          .toList();
    } catch (_) {
      return null;
    }
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    final local = date.toLocal();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  /// Jumlah mesin per status (aktif = ada produksi hari ini yang sedang
  /// berjalan; pending = ada shift/jadwal tapi belum ada input) dari setiap
  /// departemen — sama seperti perhitungan "activeCount"/"pendingCount" di
  /// masing-masing halaman mesin produksi (mis. PackingProductionMesinScreen).
  /// Tiap departemen di-fetch sekali lalu dihitung kedua status-nya bareng;
  /// satu departemen gagal fetch tidak menggagalkan total keseluruhan.
  Future<({int? active, int? pending})> _countMachineStatuses() async {
    final fetchers = <Future<({int active, int pending})>>[
      _brokerRepo.fetchBrokerMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _crusherRepo.fetchCrusherMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _gilinganRepo.fetchGilinganMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _hotStampRepo.fetchStampingMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _injectRepo.fetchInjectMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _keyFittingRepo.fetchPasangKunciMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _mixerRepo.fetchMixerMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _packingRepo.fetchPackingMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _spannerRepo.fetchSpannerMesin().then(
        (l) => _tally(l.map((m) => (isActive: m.isActive, isPending: m.isPending))),
      ),
      _washingRepo.fetchWashingMesin().then(
        (r) => _tally(
          r.mesinList.map((m) => (isActive: m.isActive, isPending: m.isPending)),
        ),
      ),
    ];

    var anySucceeded = false;
    var totalActive = 0;
    var totalPending = 0;
    final results = await Future.wait(
      fetchers.map(
        (f) => f.then<({int active, int pending})?>((v) => v).catchError((_) => null),
      ),
    );
    for (final r in results) {
      if (r != null) {
        anySucceeded = true;
        totalActive += r.active;
        totalPending += r.pending;
      }
    }
    return (
      active: anySucceeded ? totalActive : null,
      pending: anySucceeded ? totalPending : null,
    );
  }

  ({int active, int pending}) _tally(
    Iterable<({bool isActive, bool isPending})> items,
  ) {
    var active = 0;
    var pending = 0;
    for (final item in items) {
      if (item.isActive) active++;
      if (item.isPending) pending++;
    }
    return (active: active, pending: pending);
  }
}
