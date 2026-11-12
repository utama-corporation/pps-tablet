import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/core/navigation/pps_menu_catalog.dart';
import 'package:pps_tablet/features/spk/model/spk_models.dart';
import 'package:pps_tablet/features/spk/repository/spk_repository.dart';
import 'package:pps_tablet/features/spk/view_model/spk_view_model.dart';
import 'package:pps_tablet/features/spk/view/spk_screen.dart';
import 'package:pps_tablet/features/spk/view/spk_stock_detail_dialog.dart';
import 'package:pps_tablet/features/spk/view/spk_document_dialog.dart';
import 'package:pps_tablet/features/spk/view/spk_create_dialog.dart';

Map<String, dynamic> stock({
  String name = 'Barang uji',
  String status = 'PERLU PRODUKSI',
  int id = 7,
}) => {
  'IdBJ': id,
  'ItemCode': id == 7 ? 'BJ.007' : 'BJ.$id',
  'NamaBJ': name,
  'UOM': 'PCS',
  'Stock': '25.5',
  'MinStock': 50,
  'MaxStock': 100,
  'MPQ': 12,
  'QtyRekomendasi': 84,
  'Status': status,
};
Map<String, dynamic> history() => {
  'NoSPK': 'SPK.001',
  'Tanggal': '2026-11-09',
  'StatusSPK': 'OPEN',
  'StatusBaris': 'OPEN',
  'QtySPK': 84,
  'QtySelesai': 12,
  'StockSaatSPK': 25.5,
  'QtyRekomendasi': 84,
};
Map<String, dynamic> document() => {
  'NoSPK': 'SPK.001',
  'Tanggal': '2026-11-09',
  'Status': 'OPEN',
  'Keterangan': 'Data simulasi',
  'items': [
    {
      'ItemCode': 'BJ.007',
      'NamaBJ': 'Barang uji',
      'UOM': 'PCS',
      'QtySPK': 84,
      'QtyProduksi': 24,
      'QtySelesai': 12,
      'StockSaatSPK': 25.5,
      'MinStock': 50,
      'MaxStock': 100,
      'MPQ': 12,
      'QtyRekomendasi': 84,
      'Status': 'OPEN',
    },
  ],
};

class TestApi extends ApiClient {
  final requests = <({String path, Map<String, dynamic>? query})>[];
  bool fail = false, empty = false;
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    requests.add((path: path, query: query));
    if (fail) {
      throw ApiException(503, 'Offline');
    }
    if (path.endsWith('/history')) {
      return {
        'data': empty ? [] : [history()],
        'totalData': 1,
        'meta': {'page': query?['page'] ?? 1, 'totalPages': 2},
      };
    }
    if (path != '/api/spk-barang-jadi') {
      return {'data': document()};
    }
    final requested = query?['page'] as int? ?? 1;
    return {
      'data': empty
          ? <Map<String, dynamic>>[]
          : requested > 1
          ? <Map<String, dynamic>>[]
          : List.generate(20, (i) => stock(id: i == 0 ? 7 : 100 + i)),
      'totalData': 21,
      'meta': {
        'page': requested,
        'totalPages': 2,
        'summary': {
          'perluProduksi': 4,
          'stockHabis': 3,
          'mendekatiMinimum': 2,
          'stockAman': 12,
        },
      },
    };
  }
}

class DeferredSpk extends SpkRepository {
  DeferredSpk() : super(api: TestApi());
  final pending = <Completer<SpkPage<SpkStockItem>>>[];
  int? lastPage;
  String? lastSearch, lastStatus, lastSort, lastDir;

  @override
  Future<SpkPage<SpkStockItem>> monitoring({
    int page = 1,
    String search = '',
    String status = '',
    String sort = 'barang',
    String dir = 'asc',
  }) {
    lastPage = page;
    lastSearch = search;
    lastStatus = status;
    lastSort = sort;
    lastDir = dir;
    final c = Completer<SpkPage<SpkStockItem>>();
    pending.add(c);
    return c.future;
  }
}

Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

SpkPage<SpkStockItem> result(String name, {int page = 1, int pages = 1}) =>
    SpkPage(
      items: [SpkStockItem.fromJson(stock(name: name))],
      page: page,
      totalPages: pages,
      total: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fontDir = String.fromEnvironment('SIDEBAR_TEST_FONT_DIR');
  const screenshotDir = String.fromEnvironment('SPK_SCREENSHOT_DIR');
  setUpAll(() async {
    if (fontDir.isEmpty) {
      return;
    }
    final font = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      font.addFont(
        File('$fontDir/$name').readAsBytes().then(ByteData.sublistView),
      );
    }
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(WidgetTester tester, String name) async {
    if (screenshotDir.isEmpty) {
      return;
    }
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$screenshotDir/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('model preserves backend values and two decimal quantities', () {
    final i = SpkStockItem.fromJson(stock());
    expect(i.stock, 25.5);
    expect(i.recommendation, 84);
    expect(i.status, 'PERLU PRODUKSI');
    expect(spkQty(25.5), '25,5');
    expect(spkDate('2026-11-09'), '09/11/2026');
    final d = SpkDocument.fromJson(document());
    expect(d.items.single.produced, 24);
    expect(d.items.single.completed, 12);
    expect(() => SpkStockItem.fromJson({'IdBJ': 0}), throwsFormatException);
  });
  test(
    'repository uses server contract, pagination and encoded detail path',
    () async {
      final api = TestApi();
      final repo = SpkRepository(api: api);
      final list = await repo.monitoring(
        page: 2,
        search: '  BJ  ',
        status: 'STOCK HABIS',
        sort: 'stok',
        dir: 'desc',
      );
      expect(api.requests.last.query, {
        'page': 2,
        'pageSize': 20,
        'search': 'BJ',
        'status': 'STOCK HABIS',
        'sort': 'stok',
        'dir': 'desc',
      });
      expect(list.total, 21);
      expect(list.summary['stockHabis'], 3);
      final h = await repo.history(7, page: 2);
      expect(api.requests.last.query, {'idBJ': 7, 'page': 2, 'pageSize': 10});
      expect(h.items.single.code, 'SPK.001');
      await repo.detail('SPK/001');
      expect(api.requests.last.path, '/api/spk-barang-jadi/SPK%2F001');
    },
  );
  test('newer search wins and filters reset page', () async {
    final repo = DeferredSpk();
    final vm = SpkViewModel(repo);
    await vm.fetchHeaders(search: 'old');
    vm.pagingController.fetchNextPage();
    await vm.fetchHeaders(search: 'new');
    vm.setStatus('STOCK HABIS');
    vm.pagingController.fetchNextPage();
    expect(repo.pending.length, 2);
    repo.pending[1].complete(result('new'));
    await flush();
    repo.pending[0].complete(result('old', page: 1, pages: 2));
    await flush();
    expect(vm.items.single.name, 'new');
    expect(vm.currentSearch, 'new');
    expect(vm.status, 'STOCK HABIS');
    expect(repo.lastSearch, 'new');
    expect(repo.lastStatus, 'STOCK HABIS');
    expect(repo.lastPage, 1);
    expect(vm.isLoading, false);
    vm.dispose();
  });
  test('failed request retries with the same filters', () async {
    final repo = DeferredSpk();
    final vm = SpkViewModel(repo);
    vm.setStatus('STOCK HABIS');
    await vm.fetchHeaders(search: 'BJ');
    vm.pagingController.fetchNextPage();
    repo.pending[0].completeError(ApiException(503, 'Offline'));
    await flush();
    expect(vm.errorMessage, isNotEmpty);
    expect(vm.isLoading, false);
    await vm.refreshCurrent();
    vm.pagingController.fetchNextPage();
    repo.pending[1].complete(result('retry'));
    await flush();
    expect(vm.errorMessage, isEmpty);
    expect(vm.currentSearch, 'BJ');
    expect(vm.status, 'STOCK HABIS');
    expect(vm.items.single.name, 'retry');
    vm.dispose();
  });
  test('SPK sidebar destination requires planning permission', () {
    final item = PpsMenuCatalog.sections
        .expand((s) => s.entries)
        .whereType<PpsMenuItem>()
        .firstWhere((i) => i.id == '/production/spk-barang-jadi');
    expect(item.route, '/production/spk-barang-jadi');
    expect(item.permissions, [spkReadPermission]);
  });
  Future<PermissionViewModel> setup(
    WidgetTester tester,
    Widget child, {
    bool allowed = true,
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'permissions': allowed ? [spkReadPermission] : <String>[],
    });
    final permissions = PermissionViewModel();
    await permissions.loadPermissions();
    addTearDown(permissions.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: permissions,
        // Boundary above MaterialApp so screenshots include dialogs.
        child: RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            theme: ThemeData(fontFamily: fontDir.isEmpty ? null : 'Roboto'),
            home: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return permissions;
  }

  testWidgets('no permission sends no requests', (tester) async {
    final api = TestApi();
    await setup(
      tester,
      SpkScreen(repository: SpkRepository(api: api)),
      allowed: false,
    );
    expect(api.requests, isEmpty);
    expect(find.textContaining('tidak memiliki akses'), findsOneWidget);
  });
  testWidgets(
    'monitoring search, filter, sorting and infinite scroll use backend',
    (tester) async {
      final api = TestApi();
      await setup(tester, SpkScreen(repository: SpkRepository(api: api)));
      expect(find.text('25,5'), findsWidgets);
      await capture(tester, 'pps-spk-monitoring');
      await tester.enterText(find.byType(TextField), 'BJ');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(
        api.requests.any(
          (r) => r.query?['search'] == 'BJ' && r.query?['page'] == 1,
        ),
        isTrue,
      );
      await tester.tap(find.text('STOCK HABIS').first);
      await tester.pumpAndSettle();
      expect(
        api.requests.any(
          (r) => r.query?['status'] == 'STOCK HABIS' && r.query?['page'] == 1,
        ),
        isTrue,
      );
      await tester.tap(find.text('STOK'));
      await tester.pumpAndSettle();
      expect(
        api.requests.any(
          (r) => r.query?['sort'] == 'stok' && r.query?['page'] == 1,
        ),
        isTrue,
      );
      await tester.tap(find.text('STOK'));
      await tester.pumpAndSettle();
      expect(
        api.requests.any(
          (r) =>
              r.query?['sort'] == 'stok' &&
              r.query?['dir'] == 'desc' &&
              r.query?['status'] == 'STOCK HABIS',
        ),
        isTrue,
      );
      // infinite scroll: page 2 (empty in the fake backend) is requested when
      // the table is scrolled to the end.
      await tester.fling(find.text('BJ.007'), const Offset(0, -2000), 3000);
      await tester.pumpAndSettle();
      expect(api.requests.any((r) => r.query?['page'] == 2), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('item detail loads history and opens full SPK document', (
    tester,
  ) async {
    final api = TestApi();
    await setup(tester, SpkScreen(repository: SpkRepository(api: api)));
    await tester.longPress(find.text('BJ.007'));
    await tester.pumpAndSettle();
    expect(find.byType(SpkStockDetailDialog), findsOneWidget);
    expect(api.requests.last.query?['idBJ'], 7);
    await capture(tester, 'pps-spk-history');
    await tester.tap(find.text('SPK.001 · 09/11/2026'));
    await tester.pumpAndSettle();
    expect(find.byType(SpkDocumentDialog), findsOneWidget);
    expect(find.text('QTY PRODUKSI'), findsOneWidget);
    expect(find.text('Keterangan: Data simulasi'), findsOneWidget);
    expect(find.text('12 (14%)'), findsWidgets);
    expect(find.text('24'), findsWidgets);
    expect(api.requests.last.path, '/api/spk-barang-jadi/SPK.001');
    await capture(tester, 'pps-spk-document');
    expect(tester.takeException(), isNull);
  });
  testWidgets('error retry, empty state and narrow tablet remain usable', (
    tester,
  ) async {
    final api = TestApi()..fail = true;
    await setup(
      tester,
      SpkScreen(repository: SpkRepository(api: api)),
      size: const Size(800, 1000),
    );
    expect(find.text('Coba lagi'), findsOneWidget);
    api.fail = false;
    api.empty = true;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Tidak ada barang yang sesuai dengan pencarian atau status ini.',
      ),
      findsOneWidget,
    );
    await capture(tester, 'pps-spk-portrait');
    expect(tester.takeException(), isNull);
  });

  test('selection survives refetch, select-all and clear', () async {
    final repo = DeferredSpk();
    final vm = SpkViewModel(repo);
    await vm.fetchHeaders();
    vm.pagingController.fetchNextPage();
    repo.pending.single.complete(
      SpkPage(
        items: [
          SpkStockItem.fromJson(stock(id: 1)),
          SpkStockItem.fromJson(stock(id: 2)),
        ],
        page: 1,
        totalPages: 1,
        total: 2,
      ),
    );
    await flush();
    vm.toggleSelection(vm.items.first);
    expect(vm.selectedCount, 1);
    expect(vm.loadedSelectionState, isNull);
    vm.setLoadedSelected(true);
    expect(vm.loadedSelectionState, isTrue);
    expect(vm.selectedRecommendationTotal, 168);
    await vm.fetchHeaders(search: 'lain');
    expect(vm.selectedCount, 2, reason: 'search must not drop the selection');
    vm.toggleSelection(vm.selectedItems.first);
    expect(vm.selectedItems.map((i) => i.id), [2]);
    vm.clearSelection();
    expect(vm.hasSelection, isFalse);
    vm.dispose();
  });

  test('qty helpers follow web validation', () {
    expect(spkParseQty('1.234,5'), 1234.5);
    expect(spkParseQty('84'), 84);
    expect(spkParseQty('abc'), isNull);
    expect(spkQtyInput(84), '84');
    expect(spkQtyInput(12.5), '12,5');
    expect(spkQtyInput(0), '');
    expect(spkHasMaxTwoDecimals(1.25), isTrue);
    expect(spkHasMaxTwoDecimals(1.255), isFalse);
    expect(spkIsMpqMultiple(84, 12), isTrue);
    expect(spkIsMpqMultiple(80, 12), isFalse);
    expect(spkIsMpqMultiple(80, 0), isTrue);
  });

  group('with MockClient backend', () {
    late List<http.Request> calls;
    late http.Response Function(http.Request) onCreate;

    setUp(() {
      dotenv.testLoad(
        fileInput:
            'API_BASE_URL=http://localhost:7500\nDEFAULT_NETWORK_MODE=internal',
      );
    });

    Map<String, dynamic> created(List items, String? notes) => {
      'IdSPK': 31,
      'NoSPK': 'SPK.0000000031',
      'Tanggal': '2026-11-10',
      'Status': 'OPEN',
      'Keterangan': notes,
      'CreatedBy': 5,
      'CreatedDate': '2026-11-10T08:30:00.000Z',
      'items': [
        for (final (n, item) in items.indexed)
          {
            'IdSPKDetail': n + 1,
            'IdBJ': item['IdBJ'],
            'ItemCode': 'BJ.${item['IdBJ']}',
            'NamaBJ': 'Barang ${item['IdBJ']}',
            'UOM': 'PCS',
            'QtySPK': item['QtySPK'],
            'QtyProduksi': 0,
            'QtySelesai': 0,
            'StockSaatSPK': 25.5,
            'MinStock': 50,
            'MaxStock': 100,
            'MPQ': 12,
            'QtyRekomendasi': 84,
            'Status': 'OPEN',
            'Keterangan': null,
          },
      ],
    };

    SpkRepository mockRepo() {
      calls = [];
      onCreate = (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'SPK berhasil dibuat',
            'data': created(
              body['items'] as List,
              body['keterangan'] as String?,
            ),
          }),
          201,
        );
      };
      final client = MockClient((req) async {
        calls.add(req);
        if (req.method == 'POST' && req.url.path == '/api/spk-barang-jadi') {
          return onCreate(req);
        }
        if (req.method == 'GET' && req.url.path == '/api/spk-barang-jadi') {
          final page = int.parse(req.url.queryParameters['page'] ?? '1');
          return http.Response(
            jsonEncode({
              'success': true,
              'totalData': 3,
              'data': page > 1
                  ? []
                  : [
                      stock(id: 7),
                      stock(id: 8, name: 'Barang kedua'),
                      stock(id: 9, name: 'Barang ketiga', status: 'STOCK AMAN'),
                    ],
              'meta': {'page': page, 'totalPages': 1, 'summary': {}},
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'message': 'not found'}), 404);
      });
      return SpkRepository(api: ApiClient(client: client));
    }

    test('repository posts the backend create contract', () async {
      SharedPreferences.setMockInitialValues({'token': 'test-token'});
      final repo = mockRepo();
      final doc = await repo.create(
        items: const [
          SpkCreateLine(idBJ: 7, qty: 84),
          SpkCreateLine(idBJ: 8, qty: 12.5),
        ],
        notes: '  stok bulan ini ',
      );
      final req = calls.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/spk-barang-jadi');
      expect(jsonDecode(req.body), {
        'keterangan': 'stok bulan ini',
        'items': [
          {'IdBJ': 7, 'QtySPK': 84.0},
          {'IdBJ': 8, 'QtySPK': 12.5},
        ],
      });
      expect(doc.code, 'SPK.0000000031');
      expect(doc.items.length, 2);
      expect(doc.totalQty, 96.5);
      await repo.create(items: const [SpkCreateLine(idBJ: 7, qty: 1)]);
      expect((jsonDecode(calls.last.body) as Map)['keterangan'], isNull);
    });

    testWidgets('tapping rows selects them and drives the selection bar', (
      tester,
    ) async {
      final repo = mockRepo();
      await setup(tester, SpkScreen(repository: repo));
      expect(find.byKey(const ValueKey('spk-selection-bar')), findsNothing);

      await tester.tap(find.text('Barang kedua'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('spk-selection-bar')), findsOneWidget);
      expect(find.text('1 BARANG DIPILIH'), findsOneWidget);
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('spk-select-8')))
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<Checkbox>(find.byKey(const ValueKey('spk-select-7')))
            .value,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('spk-selection-create')),
        findsOneWidget,
      );
      await capture(tester, 'pps-spk-selection');

      await tester.tap(find.text('Barang kedua'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('spk-selection-bar')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('spk-select-all')));
      await tester.pumpAndSettle();
      expect(find.text('3 BARANG DIPILIH'), findsOneWidget);
      expect(find.text('Total qty (rekomendasi): 252'), findsOneWidget);

      await tester.tap(find.text('Batalkan Pilihan'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('spk-selection-bar')), findsNothing);

      // Long-press opens the detail dialog; its toggle button selects the item.
      await tester.longPress(find.text('Barang ketiga'));
      await tester.pumpAndSettle();
      expect(find.byType(SpkStockDetailDialog), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('spk-detail-toggle-selection')));
      await tester.pumpAndSettle();
      expect(find.text('1 BARANG DIPILIH'), findsOneWidget);
      expect(calls.where((c) => c.method == 'POST'), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Buat SPK validates qty, saves and shows the new document', (
      tester,
    ) async {
      final repo = mockRepo();
      await setup(tester, SpkScreen(repository: repo));
      await tester.tap(find.text('Barang uji'));
      await tester.tap(find.text('Barang kedua'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('spk-selection-create')));
      await tester.pumpAndSettle();
      expect(find.byType(SpkCreateDialog), findsOneWidget);
      expect(find.text('Total Qty SPK: 168'), findsOneWidget);

      final submit = find.byKey(const ValueKey('spk-create-submit'));
      final qty8 = find.byKey(const ValueKey('spk-qty-8'));
      await tester.enterText(qty8, '0');
      await tester.pump();
      expect(find.text('Qty SPK harus lebih dari 0'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(submit).onPressed, isNull);

      await tester.enterText(qty8, '50');
      await tester.pump();
      expect(find.textContaining('Belum kelipatan MPQ'), findsOneWidget);
      expect(tester.widget<ButtonStyleButton>(submit).onPressed, isNotNull);
      final notes = find.byKey(const ValueKey('spk-create-notes'));
      await tester.ensureVisible(notes);
      await tester.enterText(notes, 'Produksi minggu ini');
      await capture(tester, 'pps-spk-create');

      // Server-side rejection is shown inline and keeps the form open.
      onCreate = (_) => http.Response(
        jsonEncode({
          'success': false,
          'message': 'Barang dengan Id 8 tidak ditemukan atau nonaktif',
        }),
        400,
      );
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(
        find.text('Barang dengan Id 8 tidak ditemukan atau nonaktif'),
        findsOneWidget,
      );
      expect(find.byType(SpkCreateDialog), findsOneWidget);

      onCreate = (req) {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'data': created(
              body['items'] as List,
              body['keterangan'] as String?,
            ),
          }),
          201,
        );
      };
      await tester.tap(submit);
      await tester.pumpAndSettle();

      final post = calls.lastWhere((c) => c.method == 'POST');
      expect(jsonDecode(post.body), {
        'keterangan': 'Produksi minggu ini',
        'items': [
          {'IdBJ': 7, 'QtySPK': 84.0},
          {'IdBJ': 8, 'QtySPK': 50.0},
        ],
      });
      expect(find.byType(SpkCreateDialog), findsNothing);
      expect(find.text('SPK Berhasil Dibuat'), findsOneWidget);
      expect(find.text('Nomor SPK SPK.0000000031'), findsOneWidget);
      expect(find.byKey(const ValueKey('spk-selection-bar')), findsNothing);

      final getsBefore = calls.where((c) => c.method == 'GET').length;
      await tester.tap(find.text('Lihat SPK'));
      await tester.pumpAndSettle();
      expect(find.byType(SpkDocumentDialog), findsOneWidget);
      expect(find.text('Detail SPK SPK.0000000031'), findsOneWidget);
      expect(find.text('Keterangan: Produksi minggu ini'), findsOneWidget);
      expect(find.text('134'), findsOneWidget); // total qty SPK
      expect(
        calls.where((c) => c.method == 'GET').length,
        getsBefore,
        reason: 'the created document is shown without refetching',
      );
      await capture(tester, 'pps-spk-created-document');
      expect(tester.takeException(), isNull);
    });
  });
}
