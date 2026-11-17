import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_mesin/repository/master_mesin_repository.dart';
import 'package:pps_tablet/features/master_mesin/view/master_mesin_screen.dart';
import 'package:pps_tablet/features/master_mesin/view_model/master_mesin_view_model.dart';

const _slugToBagian = <String, int>{
  'broker': 2,
  'crusher': 3,
  'inject': 4,
  'mixer': 5,
  'packing': 6,
  'washing': 7,
  'hot-stamping': 8,
  'spanner': 9,
  'pasang-kunci': 10,
  'gilingan': 11,
};

Map<String, dynamic> mesinRow({
  required int id,
  required String nama,
  required int idBagianMesin,
  int enable = 1,
  num? kapasitas,
  int? idUom = 1,
}) => {
  'idMesin': id,
  'namaMesin': nama,
  'kapasitas': kapasitas ?? 100,
  'idUOM': idUom,
  'namaUOM': 'PCS',
  'enable': enable == 1,
  if (idBagianMesin == 4) ...{
    'shortWeightPS': 12.5,
    'klemLebar': 3.25,
    'klemTinggi': 4.5,
  },
};

class FakeApi extends ApiClient {
  final Map<int, List<Map<String, dynamic>>> perBagian = {
    2: [
      mesinRow(id: 3, nama: 'MESIN BROKER 1', idBagianMesin: 2, kapasitas: 120),
      mesinRow(id: 4, nama: 'MESIN BROKER 2', idBagianMesin: 2, kapasitas: 150),
    ],
    3: [
      mesinRow(id: 31, nama: 'CRUSHER 01', idBagianMesin: 3, kapasitas: 500),
    ],
    4: [
      mesinRow(id: 51, nama: 'INJECT 01', idBagianMesin: 4, kapasitas: 800),
      // Id yang sama boleh lintas jenis (IdMesin unik per tabel jenis).
      mesinRow(id: 41, nama: 'INJECT DUP', idBagianMesin: 4, kapasitas: 1200.5),
    ],
    5: [
      mesinRow(
        id: 41,
        nama: 'MIXER A',
        idBagianMesin: 5,
        enable: 0,
        kapasitas: 1200.5,
      ),
      mesinRow(id: 42, nama: 'MIXER B', idBagianMesin: 5, kapasitas: 900),
    ],
    6: const [],
    7: const [],
    8: const [],
    9: const [],
    10: const [],
    11: const [],
  };
  String lastPath = '';
  String? lastDeletePath;
  Map<String, dynamic>? lastBody;
  int getCalls = 0, postCalls = 0, putCalls = 0, deleteCalls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    lastPath = path;
    if (path == '/api/mst-mesin-produksi/meta') {
      return {
        'success': true,
        'data': {
          'types': <dynamic>[],
          'summary': <dynamic>[],
          'uom': [
            {'idUOM': 1, 'namaUOM': 'SAK'},
            {'idUOM': 2, 'namaUOM': 'KG'},
            {'idUOM': 3, 'namaUOM': 'UNIT'},
            {'idUOM': 5, 'namaUOM': 'PCS'},
            {'idUOM': 6, 'namaUOM': 'DUS'},
            {'idUOM': 7, 'namaUOM': 'LUSIN'},
            {'idUOM': 8, 'namaUOM': 'LITER'},
          ],
        },
      };
    }
    final match = RegExp(r'^/api/mst-mesin-produksi/([a-z-]+)$').firstMatch(path);
    if (match != null) {
      final bagianId = _slugToBagian[match.group(1)!];
      return {'data': perBagian[bagianId] ?? const <dynamic>[]};
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
    return {'success': true, 'data': {'idMesin': 99}};
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
    return {'success': true, 'data': {'idMesin': 42}};
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    deleteCalls++;
    lastPath = path;
    lastDeletePath = path;
    return {'success': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fetchByBagian returns one bagian, same IdMesin allowed across jenis', () async {
    final api = FakeApi();
    final repo = MasterMesinRepository(api: api);

    final inject = await repo.fetchByBagian(4);
    expect(inject.map((m) => m.namaMesin), ['INJECT 01', 'INJECT DUP']);
    expect(inject.map((m) => m.idBagianMesin).toSet(), {4});

    final mixer = await repo.fetchByBagian(5);
    expect(mixer.map((m) => m.namaMesin), ['MIXER A', 'MIXER B']);
    // IdMesin 41 boleh ada di bagian lain — IdMesin unik per tabel jenis.
    expect(mixer.map((m) => m.idMesin), contains(41));
    expect(mixer.first.bagian, 'Mixer');
  });

  test('repository writes use the expected path and camelCase payload', () async {
    final api = FakeApi();
    final repo = MasterMesinRepository(api: api);

    await repo.create(
      namaMesin: 'MIXER C',
      idBagianMesin: 5,
      kapasitas: 1300,
      idUom: 1,
      enable: true,
    );
    expect(api.lastPath, '/api/mst-mesin-produksi/mixer');
    expect(api.lastBody, {
      'namaMesin': 'MIXER C',
      'kapasitas': 1300,
      'idUOM': 1,
      'enable': true,
    });

    // Inject: kolom inject ikut terkirim saat create.
    await repo.create(
      namaMesin: 'INJECT 20',
      idBagianMesin: 4,
      kapasitas: 100,
      idUom: 5,
      enable: true,
      shortWeightPs: 12.5,
      klemLebar: 3.25,
      klemTinggi: 4.5,
    );
    expect(api.lastPath, '/api/mst-mesin-produksi/inject');
    expect(api.lastBody, {
      'namaMesin': 'INJECT 20',
      'kapasitas': 100,
      'idUOM': 5,
      'enable': true,
      'shortWeightPS': 12.5,
      'klemLebar': 3.25,
      'klemTinggi': 4.5,
    });

    await repo.update(
      idMesin: 42,
      namaMesin: 'MIXER B',
      idBagianMesin: 5,
      kapasitas: null,
      idUom: null,
      enable: false,
    );
    expect(api.lastPath, '/api/mst-mesin-produksi/mixer/42'); // PUT path
    expect(api.lastBody, {
      'namaMesin': 'MIXER B',
      'kapasitas': null,
      'idUOM': null,
      'enable': false,
    });

    // Inject: kolom khusus ikut terkirim supaya nilainya tidak di-nolkan server.
    await repo.update(
      idMesin: 51,
      namaMesin: 'INJECT 01',
      idBagianMesin: 4,
      kapasitas: 800,
      idUom: 1,
      enable: true,
      shortWeightPs: 12.5,
      klemLebar: 3.25,
      klemTinggi: 4.5,
    );
    expect(api.lastPath, '/api/mst-mesin-produksi/inject/51');
    expect(api.lastBody, {
      'namaMesin': 'INJECT 01',
      'kapasitas': 800,
      'idUOM': 1,
      'enable': true,
      'shortWeightPS': 12.5,
      'klemLebar': 3.25,
      'klemTinggi': 4.5,
    });

    await repo.delete(42, idBagianMesin: 5);
    expect(api.lastDeletePath, '/api/mst-mesin-produksi/mixer/42');
  });

  test('fetchUomOptions reads meta endpoint and labels uom', () async {
    final api = FakeApi();
    final repo = MasterMesinRepository(api: api);

    final options = await repo.fetchUomOptions();
    expect(api.lastPath, '/api/mst-mesin-produksi/meta');
    expect(options.map((o) => o.namaUom), [
      'SAK', 'KG', 'UNIT', 'PCS', 'DUS', 'LUSIN', 'LITER',
    ]);

    final vm = MasterMesinViewModel(repo);
    await vm.loadUom();
    expect(vm.uomOptions, hasLength(7));
    expect(vm.uomLabel(5), 'PCS');
    expect(vm.uomLabel(999), '999');
    expect(vm.uomLabel(null), '—');
    vm.dispose();
  });

  test('inject rows round-trip the inject-only columns', () async {
    final api = FakeApi();
    final repo = MasterMesinRepository(api: api);

    final items = await repo.fetchByBagian(4);
    final inject01 = items.firstWhere((m) => m.idMesin == 51);
    expect(inject01.shotWeightPs, 12.5);
    expect(inject01.klemLebar, 3.25);
    expect(inject01.klemPanjang, 4.5);
    expect(inject01.idBagianMesin, 4);
    expect(inject01.bagian, 'Inject');
    expect(inject01.namaUom, 'PCS');
  });

  test('view model defaults to broker, filters by bagian and search', () async {
    final api = FakeApi();
    final vm = MasterMesinViewModel(MasterMesinRepository(api: api));
    await vm.load();
    expect(vm.totalCount, 2);
    expect(vm.items.map((m) => m.namaMesin), ['MESIN BROKER 1', 'MESIN BROKER 2']);
    expect(vm.bagianFilter, 2);

    await vm.setBagianFilter(5);
    expect(vm.items.map((m) => m.namaMesin), ['MIXER A', 'MIXER B']);

    vm.setQuery('mixer b');
    expect(vm.items.single.idMesin, 42);

    await vm.setBagianFilter(3);
    vm.setQuery('');
    expect(vm.items.single.idMesin, 31);

    await vm.delete(42, idBagianMesin: 5);
    expect(api.deleteCalls, 1);
    expect(api.lastDeletePath, '/api/mst-mesin-produksi/mixer/42');
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
    // Default: Broker (bagian 2). Tidak ada opsi "Semua Bagian".
    expect(find.text('MESIN BROKER 1'), findsOneWidget);
    expect(find.text('MESIN BROKER 2'), findsOneWidget);
    expect(find.text('CRUSHER 01'), findsNothing);
    expect(find.text('MIXER A'), findsNothing);
    expect(find.text('Semua Bagian'), findsNothing);
    expect(find.byKey(const ValueKey('mesin-add')), findsNothing);
    expect(find.byTooltip('Ubah'), findsNothing);
    expect(find.byTooltip('Nonaktifkan'), findsNothing);

    // Filter bagian ke Inject.
    await tester.tap(find.byKey(const ValueKey('mesin-bagian-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inject').last);
    await tester.pumpAndSettle();
    expect(find.text('INJECT 01'), findsOneWidget);
    expect(find.text('MESIN BROKER 1'), findsNothing);
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
    // Ubah lewat popover -> dialog ubah -> tombol NONAKTIFKAN.
    await tester.longPress(find.text('MESIN BROKER 1'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.text('NONAKTIFKAN'), findsOneWidget);
    await tester.tap(find.text('NONAKTIFKAN'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 0);
    expect(find.text('Nonaktifkan Mesin'), findsOneWidget);
    expect(find.text('Nonaktifkan'), findsOneWidget);
    await tester.tap(find.text('Nonaktifkan'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    expect(api.lastDeletePath, '/api/mst-mesin-produksi/broker/3');
    expect(find.textContaining('dinonaktifkan'), findsOneWidget);
  });
}
