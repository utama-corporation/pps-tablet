import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_mesin/repository/master_mesin_repository.dart';
import 'package:pps_tablet/features/master_mesin/view/master_mesin_screen.dart';
import 'package:pps_tablet/features/master_mesin/view_model/master_mesin_view_model.dart';

Map<String, dynamic> mesinRow({
  required int id,
  required String nama,
  required int idBagianMesin,
  String? bagian,
  int enable = 1,
  num? kapasitas,
  int? idUom = 1,
}) => {
  'IdMesin': id,
  'NamaMesin': nama,
  'Bagian': bagian ?? '',
  'IdBagianMesin': idBagianMesin,
  'Enable': enable,
  'Kapasitas': kapasitas,
  'IdUOM': idUom,
};

class FakeApi extends ApiClient {
  Map<int, List<Map<String, dynamic>>> perBagian = {
    2: [],
    3: [mesinRow(id: 31, nama: 'CRUSHER 01', idBagianMesin: 3, bagian: 'Crusher', kapasitas: 500)],
    4: [
      mesinRow(id: 51, nama: 'INJECT 01', idBagianMesin: 4, bagian: 'Inject', kapasitas: 800),
      // Duplikat lintas-bagian (proteksi double-count) — repo harus dedupe.
      mesinRow(id: 41, nama: 'MIXER A', idBagianMesin: 4, bagian: 'Inject', kapasitas: 1200.5),
    ],
    5: [
      mesinRow(id: 41, nama: 'MIXER A', idBagianMesin: 5, bagian: 'Mixer', enable: 0, kapasitas: 1200.5),
      mesinRow(id: 42, nama: 'MIXER B', idBagianMesin: 5, bagian: 'Mixer', kapasitas: 900),
    ],
    6: [],
    7: [],
    8: [],
    9: [],
    10: [],
    11: [],
  };
  String lastPath = '';
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastBody;
  Map<String, dynamic>? lastDeleteQuery;
  int getCalls = 0, postCalls = 0, putCalls = 0, deleteCalls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    lastPath = path;
    lastQuery = query;
    final match = RegExp(r'^/api/mst-mesin/(\d+)$').firstMatch(path);
    if (match != null) {
      final id = int.parse(match.group(1)!);
      return {'data': perBagian[id] ?? const <dynamic>[]};
    }
    return {'data': <dynamic>[]};
  }

  @override
  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    postCalls++;
    lastPath = path;
    lastBody = body is Map<String, dynamic> ? body : null;
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    putCalls++;
    lastPath = path;
    lastBody = body is Map<String, dynamic> ? body : null;
    return {'success': true};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    deleteCalls++;
    lastPath = path;
    lastQuery = query;
    lastDeleteQuery = query;
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fetchAll merges, dedupes and sorts mesin from all bagian', () async {
    final api = FakeApi();
    final repo = MasterMesinRepository(api: api);

    final items = await repo.fetchAll();
    expect(items.map((m) => m.idMesin).toSet(), {31, 41, 42, 51});
    expect(items.length, 4);
    final names = items.map((m) => m.namaMesin).toList();
    expect(names, List.of(names)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
  });

  test('repository writes use the expected payload and path', () async {
    final api = FakeApi();
    final repo = MasterMesinRepository(api: api);

    await repo.create(
      namaMesin: 'MIXER C',
      idBagianMesin: 5,
      kapasitas: 1300,
      idUom: 1,
      enable: true,
    );
    expect(api.lastPath, '/api/mst-mesin');
    expect(api.lastBody, {
      'NamaMesin': 'MIXER C',
      'Bagian': 'Mixer',
      'IdBagianMesin': 5,
      'Kapasitas': 1300,
      'IdUOM': 1,
      'Enable': 1,
    });

    await repo.update(
      idMesin: 42,
      namaMesin: 'MIXER B',
      idBagianMesin: 5,
      kapasitas: null,
      idUom: null,
      enable: false,
    );
    expect(api.lastBody, {
      'IdMesin': 42,
      'NamaMesin': 'MIXER B',
      'Bagian': 'Mixer',
      'IdBagianMesin': 5,
      'Kapasitas': null,
      'IdUOM': null,
      'Enable': 0,
    });

    await repo.delete(42);
    expect(api.lastPath, '/api/mst-mesin');
    expect(api.lastDeleteQuery, {'idMesin': 42});
  });

  test('view model filters by bagian and search query', () async {
    final api = FakeApi();
    final vm = MasterMesinViewModel(MasterMesinRepository(api: api));
    await vm.load();
    expect(vm.totalCount, 4);

    vm.setBagianFilter(5);
    expect(vm.items.map((m) => m.namaMesin), ['MIXER A', 'MIXER B']);

    vm.setBagianFilter(null);
    vm.setQuery('crusher');
    expect(vm.items.single.idMesin, 31);

    vm.setQuery('');
    await vm.delete(42);
    expect(api.deleteCalls, 1);
    vm.dispose();
  });

  Future<PermissionViewModel> setup(
    WidgetTester tester,
    List<String> grants,
    Widget child,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'permissions': grants});
    final permissions = PermissionViewModel();
    await permissions.loadPermissions();
    addTearDown(permissions.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: permissions)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return permissions;
  }

  testWidgets('no read permission shows gate and sends no requests', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      [],
      MasterMesinScreen(repository: MasterMesinRepository(api: api)),
    );
    expect(api.getCalls, 0);
    expect(
      find.text('Anda tidak memiliki akses ke Master Mesin Produksi.'),
      findsOneWidget,
    );
  });

  testWidgets('lists machines, add button follows create permission', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamastermesin:read'],
      MasterMesinScreen(repository: MasterMesinRepository(api: api)),
    );
    expect(find.text('MIXER A'), findsOneWidget);
    expect(find.text('MIXER B'), findsOneWidget);
    expect(find.text('CRUSHER 01'), findsOneWidget);
    expect(find.text('INJECT 01'), findsOneWidget);
    expect(find.byKey(const ValueKey('mesin-add')), findsNothing);

    // Filter bagian ke Inject.
    await tester.tap(find.byKey(const ValueKey('mesin-bagian-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inject').last);
    await tester.pumpAndSettle();
    expect(find.text('INJECT 01'), findsOneWidget);
    expect(find.text('CRUSHER 01'), findsNothing);
  });

  testWidgets('long-press row shows popover and delete confirms', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      [
        'datamastermesin:read',
        'datamastermesin:update',
        'datamastermesin:delete',
      ],
      MasterMesinScreen(repository: MasterMesinRepository(api: api)),
    );
    await tester.longPress(find.text('MIXER B'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 0);
    expect(find.text('Hapus Mesin'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    expect(api.lastDeleteQuery, {'idMesin': 42});
  });
}
