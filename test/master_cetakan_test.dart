import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_cetakan/repository/master_cetakan_repository.dart';
import 'package:pps_tablet/features/master_cetakan/view/master_cetakan_screen.dart';
import 'package:pps_tablet/features/master_cetakan/view_model/master_cetakan_view_model.dart';

Map<String, dynamic> cetakanRow({
  int idCetakan = 1,
  int idWarna = 10,
  int idMaterial = 0,
  String namaCetakan = 'MOULD A',
  String warna = 'MERAH',
  String namaMaterial = '',
}) => {
  'IdCetakan': idCetakan,
  'IdWarna': idWarna,
  'IdMaterial': idMaterial,
  'NamaCetakan': namaCetakan,
  'Warna': warna,
  'NamaMaterial': namaMaterial,
};

class FakeApi extends ApiClient {
  List<Map<String, dynamic>> rows = [
    cetakanRow(),
    cetakanRow(
      idCetakan: 2,
      idWarna: 11,
      idMaterial: 5,
      namaCetakan: 'MOULD B',
      warna: 'BIRU',
      namaMaterial: 'ABS PUTIH',
    ),
  ];
  String lastPath = '';
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastBody;
  int getCalls = 0, postCalls = 0, putCalls = 0, deleteCalls = 0;
  bool deleteConflict = false;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    lastPath = path;
    lastQuery = query;
    if (path == '/api/mst-cetakan/warna-material') {
      return {'success': true, 'totalData': rows.length, 'data': rows};
    }
    if (path == '/api/mst-cetakan/warna-material/options') {
      return {
        'success': true,
        'data': {
          'cetakan': [
            {'IdCetakan': 1, 'NamaCetakan': 'MOULD A'},
            {'IdCetakan': 2, 'NamaCetakan': 'MOULD B'},
          ],
          'warna': [
            {'IdWarna': 10, 'Warna': 'MERAH'},
            {'IdWarna': 11, 'Warna': 'BIRU'},
          ],
          'barangJadi': [
            {'IdBJ': 100, 'NamaBJ': 'BOX 20L'},
          ],
          'furnitureWip': [
            {'IdCabinetWIP': 200, 'Nama': 'PANEL SAMPING'},
          ],
          'materials': [
            {'IdCabinetMaterial': 5, 'Nama': 'ABS PUTIH'},
          ],
        },
      };
    }
    if (path == '/api/mst-cetakan/warna-material/detail') {
      return {
        'success': true,
        'data': {
          'barangJadi': [
            {'IdBJ': 100, 'NamaBJ': 'BOX 20L'},
          ],
          'furnitureWip': <dynamic>[],
        },
      };
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
    return {'success': true, 'data': {'idCetakan': 3, 'namaCetakan': 'BARU'}};
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
    return {'success': true, 'data': body};
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
    if (deleteConflict) {
      throw ApiException(
        409,
        'DELETE $path failed',
        responseBody:
            '{"success":false,"message":"Data Cetakan + Warna + Material tujuan sudah ada"}',
      );
    }
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('repository lists, writes and quick-adds via /api/mst-cetakan', () async {
    final api = FakeApi();
    final repo = MasterCetakanRepository(api: api);

    final items = await repo.fetchAll();
    expect(items.length, 2);
    expect(api.lastPath, '/api/mst-cetakan/warna-material');
    expect(api.lastQuery, {'top': '500'});

    await repo.create(
      idCetakan: 1,
      idWarna: 10,
      idMaterial: 0,
      barangJadi: [100],
      furnitureWip: const [],
    );
    expect(api.lastPath, '/api/mst-cetakan/warna-material');
    expect(api.lastBody, {
      'idCetakan': 1,
      'idWarna': 10,
      'idMaterial': 0,
      'barangJadi': [100],
      'furnitureWip': <int>[],
    });

    final oldRow = items.first;
    await repo.update(
      oldKey: oldRow,
      idCetakan: 1,
      idWarna: 12,
      idMaterial: 5,
      barangJadi: const [],
      furnitureWip: [200, 201],
    );
    expect(api.lastPath, '/api/mst-cetakan/warna-material');
    expect(api.lastBody?['oldKey'], {
      'idCetakan': 1,
      'idWarna': 10,
      'idMaterial': 0,
    });
    expect(api.lastBody?['furnitureWip'], [200, 201]);

    await repo.delete(idCetakan: 1, idWarna: 10, idMaterial: 0);
    expect(api.lastPath, '/api/mst-cetakan/warna-material');
    expect(api.lastQuery, {'idCetakan': '1', 'idWarna': '10', 'idMaterial': '0'});

    await repo.createCetakan('MOULD C');
    expect(api.lastPath, '/api/mst-cetakan/new-cetakan');
    expect(api.lastBody, {'namaCetakan': 'MOULD C'});

    await repo.createWarna('HIJAU');
    expect(api.lastPath, '/api/mst-cetakan/new-warna');
    expect(api.lastBody, {'warna': 'HIJAU'});
  });

  test('view model filters client-side and reloads after save', () async {
    final api = FakeApi();
    final vm = MasterCetakanViewModel(MasterCetakanRepository(api: api));
    await vm.load();
    expect(vm.totalCount, 2);

    vm.setQuery('biru');
    expect(vm.items.single.namaCetakan, 'MOULD B');
    vm.setQuery('abs');
    expect(vm.items.single.namaCetakan, 'MOULD B');
    vm.setQuery('');

    await vm.save(
      edit: vm.items.first,
      idCetakan: 1,
      idWarna: 10,
      idMaterial: 5,
      barangJadi: const [],
      furnitureWip: [200],
      label: 'MOULD A — MERAH',
    );
    expect(api.putCalls, 1);
    vm.dispose();
  });

  test('async load after dispose does not throw or notify', () async {
    final api = FakeApi();
    final vm = MasterCetakanViewModel(MasterCetakanRepository(api: api));
    vm.dispose();
    await vm.load();
    await vm.loadOptions();
    expect(api.getCalls, 0);
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
      MasterCetakanScreen(repository: MasterCetakanRepository(api: api)),
    );
    expect(api.getCalls, 0);
    expect(
      find.text('Anda tidak memiliki akses ke Master Cetakan.'),
      findsOneWidget,
    );
  });

  testWidgets('lists rows; add hidden without create permission', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamastercetakan:read'],
      MasterCetakanScreen(repository: MasterCetakanRepository(api: api)),
    );
    expect(find.text('MOULD A'), findsOneWidget);
    expect(find.text('MOULD B'), findsOneWidget);
    expect(find.text('ABS PUTIH'), findsOneWidget);
    expect(find.byKey(const ValueKey('cetakan-add')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('cetakan-search')),
      'biru',
    );
    await tester.pumpAndSettle();
    expect(find.text('MOULD A'), findsNothing);
    expect(find.text('MOULD B'), findsOneWidget);
  });

  testWidgets('long-press row shows popover; 409 from server surfaces message', (
    tester,
  ) async {
    final api = FakeApi()..deleteConflict = true;
    await setup(
      tester,
      [
        'datamastercetakan:read',
        'datamastercetakan:update',
        'datamastercetakan:delete',
      ],
      MasterCetakanScreen(repository: MasterCetakanRepository(api: api)),
    );
    await tester.longPress(find.text('MOULD A'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Cetakan'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    // Snackbar berisi pesan dari server.
    expect(find.textContaining('tujuan sudah ada'), findsOneWidget);
  });
}
