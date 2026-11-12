import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/features/favorit/repository/favorit_repository.dart';
import 'package:pps_tablet/features/favorit/view_model/favorit_view_model.dart';
import 'package:pps_tablet/features/report/model/report_item.dart';
import 'package:pps_tablet/features/report/view/report_list_screen.dart';
import 'package:pps_tablet/features/report/view/report_table_screen.dart';
import 'package:pps_tablet/features/report/view_model/report_list_view_model.dart';

class FakeApi extends ApiClient {
  String lastPath = '';
  Map<String, dynamic>? lastQuery;
  Duration? lastTimeout;
  int getJsonCalls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getJsonCalls++;
    lastPath = path;
    lastQuery = query;
    if (path == '/api/laporan/warehouse-options') {
      return {
        'success': true,
        'options': ['ALL', 'GUDANG UTAMA', 'GUDANG KW2'],
      };
    }
    if (path == '/api/laporan/mutasi/washing') {
      return {
        'success': true,
        'columns': [
          {'key': 'Jenis', 'label': 'Jenis'},
          {'key': 'BeratAwal', 'label': 'BeratAwal'},
          {'key': 'BeratAkhir', 'label': 'BeratAkhir'},
        ],
        'rows': [
          {'Jenis': 'PP GIL BIRU', 'BeratAwal': 100.5, 'BeratAkhir': 120},
          {'Jenis': 'PP GIL MERAH', 'BeratAwal': 50, 'BeratAkhir': 45},
        ],
        'totalRows': 2,
      };
    }
    return {'data': <dynamic>[], 'columns': <dynamic>[], 'rows': <dynamic>[]};
  }

  @override
  Future<Uint8List> getPdfBytesForPath(
    String path, {
    Map<String, dynamic>? query,
    Duration? timeout,
  }) async {
    lastPath = path;
    lastQuery = query;
    lastTimeout = timeout;
    return Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // %PDF
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('katalog mirror web /laporan (13 grup, 56 tersedia + 8 segera)', () {
    expect(reportKategoriCatalog.length, 13);
    expect(
      reportKategoriCatalog.map((k) => k.nama),
      [
        'Bahan Baku',
        'Washing',
        'Broker',
        'Bonggolan',
        'Crusher',
        'Gilingan',
        'Mixer',
        'Reject',
        'Furniture WIP',
        'Barang Jadi',
        'Barang Dagang',
        'Rekap Produksi',
        'Semua Laporan',
      ],
    );
    final all = reportCatalogFlat;
    final soon = all.where((i) => i.comingSoon).toList();
    expect(soon.length, 8);
    expect(reportCatalogCount, all.length);
    for (final item in all) {
      if (item.comingSoon) continue;
      expect(item.path ?? item.route, isNotEmpty,
          reason: '${item.title} tanpa endpoint/route');
    }
    expect(
      reportSectionsFor('washing').single.items.map((i) => i.title),
      [
        'Stok Washing',
        'Mutasi Washing',
        'Produksi Washing',
        'Stock Opname Washing',
        'Umur Washing',
      ],
    );
    expect(reportSectionsFor('semua').single.items.length, 8);
    expect(reportSectionsFor(null).length, 13);
  });

  test('generateReport menyusun query dari values', () async {
    final api = FakeApi();
    final vm = ReportListViewModel(apiClient: api);

    final pdf = reportKategoriCatalog
        .expand((k) => k.items)
        .firstWhere((i) => i.title == 'Mutasi Washing' || i.title == 'Stok Bahan Baku');
    await vm.generateReport(
      item: pdf,
      values: {'tglAwal': '2026-11-01', 'tglAkhir': '2026-11-09'},
    );
    expect(api.lastTimeout, ReportListViewModel.pdfTimeout);
    expect(api.lastQuery, {'tglAwal': '2026-11-01', 'tglAkhir': '2026-11-09'});
    expect(api.lastPath, pdf.path);
    vm.dispose();
  });

  testWidgets('screen shows sections and search filters; tap opens dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: FakeApi()),
          ChangeNotifierProvider<FavoritViewModel>(
            create: (ctx) =>
                FavoritViewModel(FavoritRepository(api: ctx.read<ApiClient>()))
                ..load(),
          ),
        ],
        child: const MaterialApp(home: ReportListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('BAHAN BAKU'), findsNothing);
    expect(find.text('Stok Bahan Baku'), findsOneWidget);
    expect(find.text('Mutasi Washing'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('laporan-search')), 'hasil');
    await tester.pumpAndSettle();
    expect(find.text('Hasil Produksi Barang Jadi'), findsOneWidget);
    expect(find.text('Mutasi Gilingan'), findsNothing); // section lain tidak cocok
    expect(find.text('1 laporan'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('laporan-search')), 'washing');
    await tester.pumpAndSettle();
    expect(find.text('Stok Washing'), findsOneWidget);
    expect(find.text('Mutasi Washing'), findsOneWidget);
    expect(find.text('Mutasi Gilingan'), findsNothing);

    await tester.tap(find.text('Stok Washing'));
    await tester.pumpAndSettle();
    expect(find.text('Buka PDF'), findsOneWidget);
    expect(find.text('Tanggal'), findsWidgets); // field tglAkhir
    expect(find.byKey(const ValueKey('report-field-warehouse')), findsOneWidget);
  });

  testWidgets('table report opens table screen and loads rows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: FakeApi()),
          ChangeNotifierProvider<FavoritViewModel>(
            create: (ctx) =>
                FavoritViewModel(FavoritRepository(api: ctx.read<ApiClient>()))
                ..load(),
          ),
        ],
        child: const MaterialApp(home: ReportListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('laporan-search')), 'mutasi washing');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mutasi Washing'));
    await tester.pumpAndSettle();

    expect(find.byType(ReportTableScreen), findsOneWidget);
    expect(find.text('PP GIL BIRU'), findsOneWidget);
    expect(find.text('PP GIL MERAH'), findsOneWidget);
    expect(find.text('2 baris'), findsOneWidget);
    expect(find.byKey(const ValueKey('table-report-show')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('table-report-export-excel')),
      findsOneWidget,
    );
  });

  testWidgets('Segera item is disabled; filter badge shown', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: FakeApi()),
          ChangeNotifierProvider<FavoritViewModel>(
            create: (ctx) =>
                FavoritViewModel(FavoritRepository(api: ctx.read<ApiClient>()))
                ..load(),
          ),
        ],
        child: const MaterialApp(home: ReportListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('laporan-search')), 'stock opname');
    await tester.pumpAndSettle();
    // Ada 8 item "Stock Opname ..." bertanda Segera.
    expect(find.text('Segera'), findsWidgets);
  });

  testWidgets('categoryKey narrows the screen to one kategori', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: FakeApi()),
          ChangeNotifierProvider<FavoritViewModel>(
            create: (ctx) =>
                FavoritViewModel(FavoritRepository(api: ctx.read<ApiClient>()))
                ..load(),
          ),
        ],
        child: const MaterialApp(home: ReportListScreen(categoryKey: 'washing')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('WASHING'), findsNothing);
    expect(find.text('Stok Washing'), findsOneWidget);
    expect(find.text('Mutasi Washing'), findsOneWidget);
    expect(find.text('Mutasi Broker'), findsNothing);
    expect(find.text('5 laporan'), findsOneWidget);
  });

  testWidgets('categoryKey semua shows only the 8 ringkas reports', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: FakeApi()),
          ChangeNotifierProvider<FavoritViewModel>(
            create: (ctx) =>
                FavoritViewModel(FavoritRepository(api: ctx.read<ApiClient>()))
                ..load(),
          ),
        ],
        child: const MaterialApp(home: ReportListScreen(categoryKey: 'semua')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Semua Label'), findsOneWidget);
    expect(find.text('Rekap Produksi Harian'), findsOneWidget);
    expect(find.text('Dashboard Produktifitas'), findsOneWidget);
    expect(find.text('Hasil Produksi Barang Jadi'), findsOneWidget);
    expect(find.text('Produktivitas Washing'), findsOneWidget);
    expect(find.text('Produktivitas Broker'), findsOneWidget);
    expect(find.text('Laporan Bongkar Susun'), findsOneWidget);
    expect(find.text('Laporan Sortir Reject'), findsOneWidget);
    expect(find.text('Stok Bahan Baku'), findsNothing);
    expect(find.text('Stok Washing'), findsNothing);
    expect(find.text('8 laporan'), findsOneWidget);
  });

  testWidgets('warehouse dropdown only for warehouse reports', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: FakeApi()),
          ChangeNotifierProvider<FavoritViewModel>(
            create: (ctx) =>
                FavoritViewModel(FavoritRepository(api: ctx.read<ApiClient>()))
                ..load(),
          ),
        ],
        child: const MaterialApp(home: ReportListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stok Bahan Baku'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-field-warehouse')), findsOneWidget);
    expect(find.text('Semua Gudang'), findsOneWidget);

    Navigator.of(tester.element(find.text('Buka PDF'))).pop();
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('laporan-search')), 'mutasi washing');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mutasi Washing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-field-warehouse')), findsNothing);
    expect(find.byKey(const ValueKey('table-report-show')), findsOneWidget);
  });
}
