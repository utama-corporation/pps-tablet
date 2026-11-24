import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/core/navigation/pps_menu_catalog.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/features/my_work/model/my_work.dart';
import 'package:pps_tablet/features/my_work/repository/my_work_repository.dart';
import 'package:pps_tablet/features/my_work/view/my_work_screen.dart';
import 'package:pps_tablet/features/my_work/view_model/my_work_view_model.dart';

MyWorkItem item(String no, {String module = 'mixer', String title = 'Produksi Mixer'}) =>
    MyWorkItem(
      id: '$module:$no',
      no: no,
      title: title,
      subtitle: 'Shift 1 · 08:00–11:49',
      date: '2026-11-21',
      module: module,
      meta: const [('Departemen', 'Mixer'), ('Shift', '1')],
    );

class FakeMyWorkRepository extends MyWorkRepository {
  FakeMyWorkRepository() : super(api: ApiClient());

  MyWorkSummary summaryResult = const MyWorkSummary(
    total: 3,
    queues: [
      MyWorkQueue(key: 'stock_opname', label: 'Stock Opname Berjalan', count: 0),
      MyWorkQueue(key: 'produksi_pending', label: 'Produksi Belum Diselesaikan', count: 2),
      MyWorkQueue(key: 'label_unprinted', label: 'Label Belum Dicetak', count: 1),
    ],
  );
  Object? summaryError;
  final Map<String, List<MyWorkItem>> data = {
    'produksi_pending': [item('I.01'), item('I.02')],
    'label_unprinted': [
      item('BB.01', module: 'label-packing', title: 'Label Barang Jadi'),
    ],
    'stock_opname': [],
  };
  final List<(String, String)> calls = [];

  @override
  Future<MyWorkSummary> summary() async {
    if (summaryError != null) throw summaryError!;
    return summaryResult;
  }

  @override
  Future<MyWorkItems> items(String key, {String search = ''}) async {
    calls.add((key, search));
    final all = data[key] ?? const [];
    final filtered = search.isEmpty
        ? all
        : all.where((i) => i.no.toLowerCase().contains(search.toLowerCase())).toList();
    return MyWorkItems(key: key, total: filtered.length, items: filtered);
  }
}

void main() {
  group('MyWorkViewModel', () {
    test('selects the first non-empty queue and loads its items', () async {
      final repo = FakeMyWorkRepository();
      final vm = MyWorkViewModel(repository: repo);
      await vm.load();
      expect(vm.selectedKey, 'produksi_pending');
      expect(vm.items!.items.map((i) => i.no), ['I.01', 'I.02']);
      vm.dispose();
    });

    test('switching queue clears the selected item', () async {
      final repo = FakeMyWorkRepository();
      final vm = MyWorkViewModel(repository: repo);
      await vm.load();
      vm.selectItem(vm.items!.items.first);
      await vm.selectQueue('label_unprinted');
      expect(vm.selectedItem, isNull);
      expect(vm.items!.items.single.no, 'BB.01');
      vm.dispose();
    });

    test('search is debounced and keeps the selection when still present', () async {
      final repo = FakeMyWorkRepository();
      final vm = MyWorkViewModel(
        repository: repo,
        searchDebounce: const Duration(milliseconds: 10),
      );
      await vm.load();
      vm.selectItem(vm.items!.items.last);
      vm.setSearch('I.0');
      vm.setSearch('I.02');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(repo.calls.last, ('produksi_pending', 'I.02'));
      expect(repo.calls.where((c) => c.$2 == 'I.0'), isEmpty);
      expect(vm.selectedItem?.no, 'I.02');
      vm.dispose();
    });

    test('summary failure surfaces a message', () async {
      final repo = FakeMyWorkRepository()..summaryError = ApiException(500, 'x');
      final vm = MyWorkViewModel(repository: repo);
      await vm.load();
      expect(vm.summary, isNull);
      expect(vm.summaryError, isNotEmpty);
      vm.dispose();
    });
  });

  group('MyWorkScreen', () {
    Future<List<(String, String)>> pump(
      WidgetTester tester,
      FakeMyWorkRepository repo, {
      bool allowed = true,
    }) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <(String, String)>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MyWorkScreen(
            repository: repo,
            onOpenRoute: (route, title) => opened.add((route, title)),
            canOpenRoute: (_) => allowed,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return opened;
    }

    testWidgets('shows queues, total, list and opens the module', (tester) async {
      final opened = await pump(tester, FakeMyWorkRepository());
      expect(find.text('Produksi Belum Diselesaikan'), findsWidgets);
      expect(find.text('3 total pekerjaan tertunda di seluruh kategori.'), findsOneWidget);
      expect(find.text('I.01'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-work-item-mixer:I.01')));
      await tester.pumpAndSettle();
      expect(find.text('Departemen'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('my-work-open')));
      expect(opened, [('/production/mixer', 'Proses Mixer')]);
    });

    testWidgets('hides the open button without access', (tester) async {
      await pump(tester, FakeMyWorkRepository(), allowed: false);
      await tester.tap(find.byKey(const ValueKey('my-work-item-mixer:I.01')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('my-work-open')), findsNothing);
      expect(find.text('Salin nomor'), findsOneWidget);
    });

    testWidgets('empty queue shows empty state', (tester) async {
      await pump(tester, FakeMyWorkRepository());
      await tester.tap(find.byKey(const ValueKey('my-work-queue-stock_opname')));
      await tester.pumpAndSettle();
      expect(find.text('Tidak ada pekerjaan'), findsOneWidget);
    });
  });

  test('every backend module maps to a tablet route', () {
    // Tiap tujuan harus ada di katalog, supaya cek izin menu ikut berlaku.
    for (final route in kMyWorkRoutes.values) {
      expect(PpsMenuCatalog.forRoute(route), isNotNull, reason: route);
    }
    expect(myWorkRouteFor('label-packing'), '/label/packing');
    expect(myWorkRouteFor('unknown'), isNull);
  });
}
