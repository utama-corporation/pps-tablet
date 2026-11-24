import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pps_tablet/core/navigation/pps_menu_catalog.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/features/retur_beli/model/retur_beli.dart';
import 'package:pps_tablet/features/retur_beli/repository/retur_beli_repository.dart';
import 'package:pps_tablet/features/retur_beli/view/retur_beli_detail_screen.dart';
import 'package:pps_tablet/features/retur_beli/view/retur_beli_list_screen.dart';

/// Repository palsu dengan stok label di memori, meniru aturan backend.
class FakeReturBeliRepository extends ReturBeliRepository {
  FakeReturBeliRepository() : super(api: ApiClient());

  ReturBeliHeader header = const ReturBeliHeader(
    noReturBeli: 'RB.0000000001',
    tanggal: '2026-11-23',
    idSupplier: 7,
    namaSupplier: 'PT KEMAS',
  );
  final List<ReturBeliItem> items = [];
  final Map<String, ReturBeliLabel> labels = {
    'BP.01': const ReturBeliLabel(
      noLabel: 'BP.01',
      idSupplier: 7,
      namaSupplier: 'PT KEMAS',
      namaBarang: 'KOTAK PK 3105',
      sisa: 10,
      qtyAwal: 10,
      available: true,
    ),
    'BP.LAIN': const ReturBeliLabel(
      noLabel: 'BP.LAIN',
      idSupplier: 8,
      namaSupplier: 'PT LAIN',
      sisa: 5,
      available: true,
    ),
  };
  final List<String> calls = [];

  @override
  Future<ReturBeliDetail> detail(String no) async =>
      ReturBeliDetail(header: header, items: List.of(items));

  @override
  Future<ReturBeliLabel> lookupLabel(String noLabel) async {
    final l = labels[noLabel];
    if (l == null) {
      throw ApiException(404, 'x', responseBody: '{"message":"Label tidak ditemukan"}');
    }
    return l;
  }

  @override
  Future<void> addItem(String no, {required String noLabel, num? qty, String remark = ''}) async {
    calls.add('add $noLabel ${qty ?? 'all'}');
    final l = labels[noLabel]!;
    items.add(ReturBeliItem(
      idItem: items.length + 1,
      noLabel: noLabel,
      qty: qty ?? l.sisa,
      qtyAwal: l.qtyAwal,
      namaBarang: l.namaBarang,
      remark: remark,
    ));
  }

  @override
  Future<void> deleteItem(String no, int idItem) async {
    calls.add('delete $idItem');
    items.removeWhere((i) => i.idItem == idItem);
  }

  @override
  Future<void> complete(String no, ReturBeliPenyelesaian penyelesaian) async {
    calls.add('complete ${penyelesaian.code}');
    header = ReturBeliHeader(
      noReturBeli: header.noReturBeli,
      tanggal: header.tanggal,
      idSupplier: header.idSupplier,
      namaSupplier: header.namaSupplier,
      status: 'SELESAI',
      penyelesaian: penyelesaian,
    );
  }

  @override
  Future<ReturBeliPage> list({
    String search = '',
    String status = '',
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls.add('list $status');
    return ReturBeliPage(items: [header], total: 1);
  }
}

void main() {
  String scanCode = 'BP.01';
  String? scanError;

  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(() {
    scanCode = 'BP.01';
    scanError = null;
  });

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> pumpDetail(
    WidgetTester tester,
    FakeReturBeliRepository repo, {
    Set<String> perms = const {'returbeli:read', 'returbeli:update', 'returbeli:delete'},
  }) async {
    bigScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: ReturBeliDetailScreen(
          noReturBeli: 'RB.0000000001',
          repository: repo,
          can: perms.contains,
          embedded: true,
          // Scan palsu: jalankan validasi asli layar (onLookup) untuk kode tertentu.
          scanLabel: (ctx, onLookup) async {
            scanError = await onLookup(scanCode);
            return scanError == null ? repo.labels[scanCode] : null;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scanAndSave(WidgetTester tester, {String? qty}) async {
    await tester.tap(find.byKey(const ValueKey('rb-scan')));
    await tester.pumpAndSettle();
    if (qty != null) {
      await tester.enterText(find.byKey(const ValueKey('rb-qty')), qty);
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('rb-qty-save')));
    await tester.pumpAndSettle();
  }

  testWidgets('scan a label, return part of it, then delete it', (tester) async {
    final repo = FakeReturBeliRepository();
    await pumpDetail(tester, repo);
    expect(find.textContaining('Belum ada label'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rb-scan')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('rb-qty')), '11');
    await tester.pump();
    expect(find.text('Maksimal 10'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('rb-qty')), '3');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('rb-qty-save')));
    await tester.pumpAndSettle();
    expect(repo.calls, ['add BP.01 3']);
    expect(find.byKey(const ValueKey('rb-item-BP.01')), findsOneWidget);
    expect(find.text('Sebagian'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rb-item-delete-BP.01')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Hapus'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete 1');
    expect(find.byKey(const ValueKey('rb-item-BP.01')), findsNothing);
  });

  testWidgets('full remaining qty is sent as "all"', (tester) async {
    final repo = FakeReturBeliRepository();
    await pumpDetail(tester, repo);
    await scanAndSave(tester);
    expect(repo.calls, ['add BP.01 all']);
    expect(find.text('Utuh'), findsOneWidget);
  });

  testWidgets('label from another supplier is rejected at scan', (tester) async {
    final repo = FakeReturBeliRepository();
    scanCode = 'BP.LAIN';
    await pumpDetail(tester, repo);
    await tester.tap(find.byKey(const ValueKey('rb-scan')));
    await tester.pumpAndSettle();
    expect(scanError, contains('PT LAIN'));
    expect(find.byKey(const ValueKey('rb-qty')), findsNothing);
    expect(repo.calls, isEmpty);
  });

  testWidgets('Potong Tagihan completes and locks the document', (tester) async {
    final repo = FakeReturBeliRepository();
    await pumpDetail(tester, repo);
    // Tanpa item belum ada tombol penyelesaian.
    expect(find.byKey(const ValueKey('rb-penyelesaian-DIGANTI')), findsNothing);
    await scanAndSave(tester);

    await tester.tap(find.byKey(const ValueKey('rb-penyelesaian-POTONG_TAGIHAN')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ya, Potong Tagihan'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'complete POTONG_TAGIHAN');
    expect(find.textContaining('dipotong dari tagihan'), findsOneWidget);
    expect(find.byKey(const ValueKey('rb-scan')), findsNothing);
    expect(find.byKey(const ValueKey('rb-item-delete-BP.01')), findsNothing);
    expect(find.byKey(const ValueKey('rb-delete')), findsNothing);
  });

  testWidgets('cancelling the confirmation keeps the retur open', (tester) async {
    final repo = FakeReturBeliRepository();
    await pumpDetail(tester, repo);
    await scanAndSave(tester);
    await tester.tap(find.byKey(const ValueKey('rb-penyelesaian-DIGANTI')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(repo.calls.where((c) => c.startsWith('complete')), isEmpty);
    expect(find.byKey(const ValueKey('rb-scan')), findsOneWidget);
  });

  testWidgets('read-only user sees no edit actions', (tester) async {
    final repo = FakeReturBeliRepository()
      ..items.add(const ReturBeliItem(idItem: 1, noLabel: 'BP.01', qty: 2, qtyAwal: 10));
    await pumpDetail(tester, repo, perms: const {'returbeli:read'});
    expect(find.byKey(const ValueKey('rb-item-BP.01')), findsOneWidget);
    expect(find.byKey(const ValueKey('rb-scan')), findsNothing);
    expect(find.byKey(const ValueKey('rb-penyelesaian-DIGANTI')), findsNothing);
    expect(find.byKey(const ValueKey('rb-item-delete-BP.01')), findsNothing);
    expect(find.byKey(const ValueKey('rb-delete')), findsNothing);
  });

  testWidgets('list is master-detail: tapping a card shows its detail', (tester) async {
    final repo = FakeReturBeliRepository();
    bigScreen(tester);
    await tester.pumpWidget(
      MaterialApp(home: ReturBeliListScreen(repository: repo, can: (_) => false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pilih retur beli dari daftar di sebelah kiri'), findsOneWidget);
    expect(find.byKey(const ValueKey('rb-create')), findsNothing);
    expect(find.text('Open'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rb-row-RB.0000000001')));
    await tester.pumpAndSettle();
    expect(find.text('Label Retur'), findsOneWidget);
    expect(find.text('Pilih retur beli dari daftar di sebelah kiri'), findsNothing);
  });

  testWidgets('status filter dialog reloads the list', (tester) async {
    final repo = FakeReturBeliRepository();
    bigScreen(tester);
    await tester.pumpWidget(
      MaterialApp(home: ReturBeliListScreen(repository: repo, can: (_) => true)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('rb-create')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rb-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rb-filter-SELESAI')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rb-filter-apply')));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'list SELESAI');
  });

  test('menu entry requires returbeli:read', () {
    final item = PpsMenuCatalog.forRoute('/shell/retur-beli');
    expect(item?.title, 'Retur Beli');
    expect(PpsMenuCatalog.canOpenRoute('/shell/retur-beli', (p) => p == 'returbeli:read'), isTrue);
    expect(PpsMenuCatalog.canOpenRoute('/shell/retur-beli', (p) => p == 'retur:read'), isFalse);
  });

  test('formatQty trims trailing zeros', () {
    expect(formatQty(10), '10');
    expect(formatQty(4.5), '4.5');
    expect(formatQty(2.250), '2.25');
  });
}
