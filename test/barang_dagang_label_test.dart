import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/services/label_print_sync_queue.dart';
import 'package:pps_tablet/core/view_model/label_print_lock_socket_manager.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/label/barang_dagang/model/barang_dagang_label.dart';
import 'package:pps_tablet/features/label/barang_dagang/repository/barang_dagang_label_repository.dart';
import 'package:pps_tablet/features/label/barang_dagang/view_model/barang_dagang_label_view_model.dart';
import 'package:pps_tablet/features/label/barang_dagang/view/barang_dagang_screen.dart';
import 'package:pps_tablet/features/label/barang_dagang/widgets/barang_dagang_detail_dialog.dart';
import 'package:pps_tablet/features/production/shared/widgets/production_output_detail_dialog.dart';
import 'package:pps_tablet/features/production/shared/models/label_usage_status.dart';

Map<String, dynamic> row({
  num remaining = 40,
  bool used = false,
  num printed = 2,
}) => {
  'NoBarangDagang': 'BD.0001',
  'NamaBarangDagang': 'Barang contoh',
  'NamaSupplier': 'Supplier contoh',
  'Qty': '100',
  'QtySisa': remaining,
  'IsPartial': 1,
  'Used': used,
  'HasBeenPrinted': printed.toString(),
};

class FakeApi extends ApiClient {
  Map<String, dynamic> response = {
    'data': [],
    'meta': {'page': 1, 'totalPages': 1, 'total': 0},
  };
  String lastPath = '';
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastPutBody;
  String? lastDeletePath;
  int calls = 0;
  int putCalls = 0;
  int deleteCalls = 0;

  // Simulate a real backend: page 1 returns the configured data, any later
  // page returns empty so infinite scroll stops.
  bool pageAware = false;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    calls++;
    lastPath = path;
    lastQuery = query;
    if (pageAware && (query?['page'] as int? ?? 1) > 1) {
      final meta = response['meta'];
      return {
        'data': <Map<String, dynamic>>[],
        'meta': meta is Map
            ? {...meta, 'page': query?['page']}
            : {'page': query?['page'], 'totalPages': 1, 'total': 0},
      };
    }
    return response;
  }

  @override
  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    lastPath = path;
    return response;
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    putCalls++;
    lastPath = path;
    lastPutBody = body is Map<String, dynamic> ? body : null;
    return response;
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    deleteCalls++;
    lastDeletePath = path;
    return response;
  }
}

class DeferredRepo extends BarangDagangLabelRepository {
  DeferredRepo() : super(api: FakeApi());
  final pending = <Completer<BarangDagangLabelPage>>[];
  @override
  Future<BarangDagangLabelPage> fetchPage({
    int page = 1,
    int limit = 20,
    String search = '',
    bool includeUsed = false,
  }) {
    final c = Completer<BarangDagangLabelPage>();
    pending.add(c);
    return c.future;
  }
}

BarangDagangLabelPage page(String code, {int number = 1, int pages = 1}) =>
    BarangDagangLabelPage(
      items: [
        BarangDagangLabel.fromJson({...row(), 'NoBarangDagang': code}),
      ],
      page: number,
      totalPages: pages,
      total: 1,
    );

Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fontDir = String.fromEnvironment('SIDEBAR_TEST_FONT_DIR');
  const screenshotDir = String.fromEnvironment('BARANG_DAGANG_SCREENSHOT_DIR');
  setUpAll(() async {
    if (fontDir.isEmpty) return;
    final fonts = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      fonts.addFont(
        File('$fontDir/$name').readAsBytes().then(ByteData.sublistView),
      );
    }
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<void> capture(WidgetTester tester, String name) async {
    if (screenshotDir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('capture')),
    );
    await tester.runAsync(() async {
      final bitmap = await boundary.toImage();
      final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '$screenshotDir/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      bitmap.dispose();
    });
  }

  setUp(() {
    dotenv.testLoad(
      fileInput:
          'API_BASE_URL=http://localhost:7500\nDEFAULT_NETWORK_MODE=internal',
    );
  });
  test('partial, used and invalid quantities produce safe remaining stock', () {
    final partial = BarangDagangLabel.fromJson(row());
    expect(partial.remainingQty, 40);
    expect(partial.usageStatus, LabelUsageStatus.terpakai);
    expect(partial.printCount, 2);
    final used = BarangDagangLabel.fromJson(row(used: true));
    expect(used.remainingQty, 0);
    expect(used.hasStock, false);
    expect(used.usageStatus, LabelUsageStatus.habis);
    expect(BarangDagangLabel.fromJson(row(remaining: 999)).remainingQty, 100);
    expect(BarangDagangLabel.fromJson(row(remaining: -1)).remainingQty, 0);
    expect(() => BarangDagangLabel.fromJson({}), throwsFormatException);
  });
  test(
    'repository sends search, paging and used filter and rejects malformed print ack',
    () async {
      final api = FakeApi();
      final repo = BarangDagangLabelRepository(api: api);
      api.response = {
        'data': [row()],
        'meta': {'page': 2, 'totalPages': 3, 'total': 45},
      };
      final result = await repo.fetchPage(
        page: 2,
        search: '  BD  ',
        includeUsed: true,
      );
      expect(api.lastQuery, {
        'page': 2,
        'limit': 20,
        'search': 'BD',
        'includeUsed': 'true',
      });
      expect(result.total, 45);
      expect(result.items.single.code, 'BD.0001');
      api.response = {
        'data': {'HasBeenPrinted': 3},
      };
      expect(await repo.markAsPrinted('BD/1'), 3);
      expect(api.lastPath, '/api/labels/barang-dagang/BD%2F1/print');
      api.response = {'success': true};
      await expectLater(repo.markAsPrinted('BD.1'), throwsFormatException);
    },
  );
  test('repository updateLabel PUTs trimmed body and deleteLabel DELETEs', () async {
    final api = FakeApi();
    final repo = BarangDagangLabelRepository(api: api);
    api.response = {'success': true, 'message': 'ok'};
    await repo.updateLabel('BD 1', {
      'header': {'Qty': 5},
    });
    expect(api.lastPath, '/api/labels/barang-dagang/BD%201');
    expect(api.lastPutBody, {
      'header': {'Qty': 5},
    });
    await repo.deleteLabel('BD/2');
    expect(api.lastDeletePath, '/api/labels/barang-dagang/BD%2F2');
    expect(api.putCalls, 1);
    expect(api.deleteCalls, 1);
    await expectLater(repo.updateLabel('  ', {}), throwsArgumentError);
    await expectLater(repo.deleteLabel('  '), throwsArgumentError);
  });
  test('late search response cannot replace newer results', () async {
    final repo = DeferredRepo();
    final vm = BarangDagangLabelViewModel(repository: repo);
    await vm.fetchHeaders(search: 'old');
    vm.pagingController.fetchNextPage();
    await vm.fetchHeaders(search: 'recent');
    vm.pagingController.fetchNextPage();
    expect(repo.pending.length, 2);
    repo.pending[1].complete(page('new'));
    await flush();
    repo.pending[0].complete(page('old'));
    await flush();
    expect(vm.items.single.code, 'new');
    expect(vm.currentSearch, 'recent');
    expect(vm.isLoading, false);
    vm.dispose();
  });
  test('failed request can be retried with the same filters', () async {
    final repo = DeferredRepo();
    final vm = BarangDagangLabelViewModel(repository: repo);
    vm.setIncludeUsed(true);
    await vm.fetchHeaders(search: 'BD');
    vm.pagingController.fetchNextPage();
    repo.pending[0].completeError(ApiException(503, 'Server belum tersedia'));
    await flush();
    expect(vm.errorMessage, isNotEmpty);
    expect(vm.isLoading, false);
    await vm.refreshCurrent();
    vm.pagingController.fetchNextPage();
    repo.pending[1].complete(page('retry'));
    await flush();
    expect(vm.errorMessage, isEmpty);
    expect(vm.currentSearch, 'BD');
    expect(vm.includeUsed, true);
    expect(vm.items.single.code, 'retry');
    vm.dispose();
  });
  test('updateFromForm sends trimmed PUT body and keeps label selected', () async {
    final api = FakeApi()
      ..response = {
        'data': [row(printed: 0, remaining: 100)],
        'meta': {'page': 1, 'totalPages': 1, 'total': 1},
      };
    final repo = BarangDagangLabelRepository(api: api);
    final vm = BarangDagangLabelViewModel(repository: repo);
    await vm.fetchHeaders();
    vm.pagingController.fetchNextPage();
    await flush();
    expect(vm.items.single.code, 'BD.0001');
    await vm.updateFromForm(
      code: 'BD.0001',
      qty: 120,
      keterangan: '  catatan  ',
    );
    expect(api.putCalls, 1);
    expect(api.lastPath, '/api/labels/barang-dagang/BD.0001');
    expect(api.lastPutBody, {
      'header': {'Qty': 120, 'Keterangan': 'catatan'},
    });
    expect(vm.selectedNoLabel, 'BD.0001');
    vm.dispose();
  });
  test('updateFromForm rejects non positive qty before calling API', () async {
    final api = FakeApi();
    final vm = BarangDagangLabelViewModel(
      repository: BarangDagangLabelRepository(api: api),
    );
    await expectLater(
      vm.updateFromForm(code: 'BD.0001', qty: 0),
      throwsException,
    );
    expect(api.putCalls, 0);
    vm.dispose();
  });
  test('deleteBarangDagang removes label from list', () async {
    final api = FakeApi()
      ..response = {
        'data': [row(printed: 0, remaining: 100)],
        'meta': {'page': 1, 'totalPages': 1, 'total': 1},
      };
    final vm = BarangDagangLabelViewModel(
      repository: BarangDagangLabelRepository(api: api),
    );
    await vm.fetchHeaders();
    vm.pagingController.fetchNextPage();
    await flush();
    expect(vm.items, hasLength(1));
    api.response = {
      'data': [],
      'meta': {'page': 1, 'totalPages': 1, 'total': 0},
    };
    await vm.deleteBarangDagang('BD.0001');
    expect(api.deleteCalls, 1);
    expect(api.lastDeletePath, '/api/labels/barang-dagang/BD.0001');
    expect(vm.items, isEmpty);
    expect(vm.selectedNoLabel, isNull);
    vm.dispose();
  });

  Future<PermissionViewModel> setup(
    WidgetTester tester,
    List<String> grants,
    Widget child,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'permissions': grants});
    final permissions = PermissionViewModel();
    await permissions.loadPermissions();
    addTearDown(permissions.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: permissions),
          ChangeNotifierProvider<LabelPrintSyncQueue>(
            create: (_) => LabelPrintSyncQueue(),
          ),
          ChangeNotifierProvider<LabelPrintLockSocketManager>(
            create: (_) => LabelPrintLockSocketManager(),
          ),
        ],
        child: MaterialApp(
          theme: ThemeData(fontFamily: fontDir.isEmpty ? null : 'Roboto'),
          home: RepaintBoundary(key: const ValueKey('capture'), child: child),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return permissions;
  }

  testWidgets('no read permission never loads labels', (tester) async {
    final api = FakeApi();
    await setup(
      tester,
      [],
      BarangDagangScreen(repository: BarangDagangLabelRepository(api: api)),
    );
    expect(api.calls, 0);
    expect(find.textContaining('tidak memiliki akses'), findsOneWidget);
  });
  testWidgets('search and include used reach repository', (
    tester,
  ) async {
    final api = FakeApi()
      ..pageAware = true
      ..response = {
        'data': [row()],
        'meta': {'page': 1, 'totalPages': 1, 'total': 1},
      };
    await setup(tester, [
      'label_barangdagang:read',
    ], BarangDagangScreen(repository: BarangDagangLabelRepository(api: api)));
    expect(find.text('BD.0001'), findsOneWidget);
    expect(find.text('NAMA BARANG'), findsOneWidget);
    expect(find.text('SISA'), findsOneWidget);
    await capture(tester, 'pps-barang-dagang-list');
    await tester.enterText(find.byType(TextField), 'supplier');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(api.lastQuery?['search'], 'supplier');
    await tester.tap(find.text('Tampilkan Semua'));
    await tester.pumpAndSettle();
    expect(api.lastQuery?['includeUsed'], 'true');
    expect(tester.takeException(), isNull);
  });
  testWidgets('long press opens popover and edit dialog', (tester) async {
    final api = FakeApi()
      ..pageAware = true
      ..response = {
        'data': [row(printed: 0, remaining: 100)],
        'meta': {'page': 1, 'totalPages': 1, 'total': 1},
      };
    await setup(tester, [
      'label_barangdagang:read',
      'label_barangdagang:update',
      'label_barangdagang:delete',
    ], BarangDagangScreen(repository: BarangDagangLabelRepository(api: api)));
    expect(find.text('BD.0001'), findsOneWidget);
    await tester.longPress(find.text('BD.0001'));
    await tester.pumpAndSettle();
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Print'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Label Barang Dagang'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('long press popover delete asks for confirmation', (
    tester,
  ) async {
    final api = FakeApi()
      ..pageAware = true
      ..response = {
        'data': [row(printed: 0, remaining: 100)],
        'meta': {'page': 1, 'totalPages': 1, 'total': 1},
      };
    await setup(tester, [
      'label_barangdagang:read',
      'label_barangdagang:delete',
    ], BarangDagangScreen(repository: BarangDagangLabelRepository(api: api)));
    expect(find.text('BD.0001'), findsOneWidget);
    await tester.longPress(find.text('BD.0001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Confirmation'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('read-only, update and used labels have correct print access', (
    tester,
  ) async {
    Future<void> show(List<String> grants, bool used) => setup(
      tester,
      grants,
      Scaffold(
        body: BarangDagangDetailDialog(
          label: BarangDagangLabel.fromJson(row(used: used)),
          repository: BarangDagangLabelRepository(api: FakeApi()),
          onPrinted: () {},
        ),
      ),
    );
    await show(['label_barangdagang:read'], false);
    expect(
      tester
          .widget<ProductionOutputDetailDialog>(
            find.byType(ProductionOutputDetailDialog),
          )
          .canPrint,
      false,
    );
    await show(['label_barangdagang:read', 'label_barangdagang:update'], false);
    expect(
      tester
          .widget<ProductionOutputDetailDialog>(
            find.byType(ProductionOutputDetailDialog),
          )
          .canPrint,
      true,
    );
    await show(['label_barangdagang:read', 'label_barangdagang:update'], true);
    expect(
      tester
          .widget<ProductionOutputDetailDialog>(
            find.byType(ProductionOutputDetailDialog),
          )
          .canPrint,
      false,
    );
    expect(tester.takeException(), isNull);
  });
}
