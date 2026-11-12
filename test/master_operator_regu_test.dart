import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_operator_regu/repository/master_operator_regu_repository.dart';
import 'package:pps_tablet/features/master_operator_regu/view/master_operator_regu_screen.dart';
import 'package:pps_tablet/features/master_operator_regu/view_model/master_operator_regu_view_model.dart';

Map<String, dynamic> operatorRow({
  int id = 1,
  String nama = 'ABDUL',
  int enable = 1,
  int idBagian = 3,
  String namaBagianMesin = 'INJECT',
}) => {
  'IdOperator': id,
  'NamaOperator': nama,
  'Enable': enable,
  'IdBagian': idBagian,
  'NamaBagianMesin': namaBagianMesin,
};

Map<String, dynamic> reguRow({
  int id = 10,
  String nama = 'REGU A',
  int idBagian = 4,
  int? kepalaRegu = 1,
  String? namaKepalaRegu = 'ABDUL',
}) => {
  'IdRegu': id,
  'NamaRegu': nama,
  'IdBagian': idBagian,
  'KepalaRegu': kepalaRegu,
  'NamaKepalaRegu': namaKepalaRegu,
};

class FakeApi extends ApiClient {
  List<Map<String, dynamic>> operators = [
    operatorRow(),
    operatorRow(id: 2, nama: 'BUDI', enable: 0),
  ];
  List<Map<String, dynamic>> regus = [
    reguRow(),
    reguRow(id: 11, nama: 'REGU B', idBagian: 5, kepalaRegu: null, namaKepalaRegu: null),
  ];
  String lastPath = '';
  String lastDeletePath = '';
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
    if (path == '/api/mst-operator') return {'data': operators};
    if (path == '/api/mst-operator/bagian') {
      return {
        'data': [
          {'IdBagianMesin': 3, 'NamaBagianMesin': 'INJECT'},
          {'IdBagianMesin': 4, 'NamaBagianMesin': 'PACKING'},
        ],
      };
    }
    if (path == '/api/mst/regu') {
      return {
        'data': [
          ...regus,
        ],
      };
    }
    if (path == '/api/mst/regu/1' || path == '/api/mst/regu/10') {
      return {
        'data': {
          'IdRegu': 1,
          'NamaRegu': 'REGU A',
          'IdBagian': 4,
          'NamaBagianMesin': 'PACKING',
          'KepalaRegu': 1,
          'NamaKepalaRegu': 'ABDUL',
          'JumlahOperator': 2,
          'operators': [
            {'IdOperator': 1, 'NamaOperator': 'ABDUL', 'Enable': 1},
            {'IdOperator': 2, 'NamaOperator': 'BUDI', 'Enable': 0},
          ],
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
    lastDeletePath = path;
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

  test('repository lists operators and regu from the expected endpoints', () async {
    final api = FakeApi();
    final repo = MasterOperatorReguRepository(api: api);

    final ops = await repo.fetchOperators();
    expect(ops.length, 2);
    expect(ops.first.namaOperator, 'ABDUL');
    expect(ops.first.enable, isTrue);
    expect(ops.first.idBagian, 3);
    expect(ops.first.namaBagianMesin, 'INJECT');
    expect(ops.last.enable, isFalse);
    expect(api.lastPath, '/api/mst-operator');
    expect(api.lastQuery, {'all': '1'});

    final bagian = await repo.fetchBagianOptions();
    expect(bagian.length, 2);
    expect(bagian.first.namaBagianMesin, 'INJECT');

    final regus = await repo.fetchRegu();
    expect(regus.length, 2);
    expect(regus.first.namaRegu, 'REGU A');
    expect(regus.first.kepalaRegu, 1);
    expect(regus.last.kepalaRegu, isNull);
    expect(api.lastPath, '/api/mst/regu');
  });

  test('repository posts and deletes with the documented payload', () async {
    final api = FakeApi();
    final repo = MasterOperatorReguRepository(api: api);

    await repo.createOperator(namaOperator: 'CITRA', idBagian: 3, enable: true);
    expect(api.lastPath, '/api/mst-operator');
    expect(api.lastBody, {'namaOperator': 'CITRA', 'idBagian': 3, 'enable': 1});

    await repo.updateOperator(
      idOperator: 7,
      namaOperator: 'CITRA',
      idBagian: 4,
      enable: false,
    );
    expect(api.lastPath, '/api/mst-operator/7');
    expect(api.lastBody, {'namaOperator': 'CITRA', 'idBagian': 4, 'enable': 0});

    await repo.deleteOperator(7);
    expect(api.lastPath, '/api/mst-operator/7');
    expect(api.lastQuery, isNull);

    await repo.createRegu(namaRegu: 'REGU C', idBagian: 6, operatorIds: [1, 2]);
    expect(api.lastPath, '/api/mst/regu');
    expect(api.lastBody, {
      'namaRegu': 'REGU C',
      'idBagian': 6,
      'operatorIds': [1, 2],
    });

    await repo.updateRegu(
      idRegu: 15,
      namaRegu: 'REGU C',
      idBagian: 6,
      operatorIds: [1],
    );
    expect(api.lastPath, '/api/mst/regu/15');
    expect(api.lastBody, {
      'namaRegu': 'REGU C',
      'idBagian': 6,
      'operatorIds': [1],
    });

    await repo.deleteRegu(15);
    expect(api.lastPath, '/api/mst/regu/15');
    expect(api.lastQuery, isNull);
  });

  test('view model filters client-side and reloads after save', () async {
    final api = FakeApi();
    final vm = MasterOperatorReguViewModel(
      MasterOperatorReguRepository(api: api),
    );
    await vm.load();
    expect(vm.operatorTotal, 2);
    expect(vm.reguTotal, 2);
    expect(vm.bagianOptions?.length, 2);

    vm.setOperatorQuery('budi');
    expect(vm.operators.single.namaOperator, 'BUDI');
    vm.setOperatorQuery('');

    vm.setReguQuery('regu b');
    expect(vm.regus.single.namaRegu, 'REGU B');
    vm.setReguQuery('');

    await vm.saveOperator(namaOperator: 'CITRA', idBagian: 3, enable: true);
    expect(api.postCalls, 1);
    expect(vm.operatorError, isEmpty);
    expect(api.lastBody?['idBagian'], 3);

    final detail = await vm.fetchReguDetail(1);
    expect(api.lastPath, '/api/mst/regu/1');
    expect(detail?.namaRegu, 'REGU A');
    expect(detail?.namaBagianMesin, 'PACKING');
    expect(detail?.operators.length, 2);
    expect(detail?.operators.first.namaOperator, 'ABDUL');

    await vm.saveRegu(namaRegu: 'REGU D', idBagian: 8, operatorIds: [1, 2]);
    expect(api.postCalls, 2);

    await vm.deleteOperator(1);
    expect(api.deleteCalls, 1);
    await vm.deleteRegu(10);
    expect(api.deleteCalls, 2);
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
      MasterOperatorReguScreen(
        repository: MasterOperatorReguRepository(api: api),
      ),
    );
    expect(api.getCalls, 0);
    expect(
      find.text('Anda tidak memiliki akses ke Master Operator & Regu.'),
      findsOneWidget,
    );
  });

  testWidgets('operator tab lists rows and search filters them', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasteroperator:read'],
      MasterOperatorReguScreen(
        repository: MasterOperatorReguRepository(api: api),
      ),
    );
    expect(find.text('ABDUL'), findsOneWidget);
    expect(find.text('BUDI'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'BUDI');
    await tester.pumpAndSettle();
    expect(find.text('ABDUL'), findsNothing);
    expect(find.text('BUDI'), findsWidgets);
  });

  testWidgets('long-press row shows popover and delete confirms', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      [
        'datamasteroperator:read',
        'datamasteroperator:update',
        'datamasteroperator:delete',
      ],
      MasterOperatorReguScreen(
        repository: MasterOperatorReguRepository(api: api),
      ),
    );
    await tester.longPress(find.text('ABDUL'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    // Confirm dialog muncul, baru setelah konfirmasi request dikirim.
    expect(api.deleteCalls, 0);
    expect(find.text('Hapus Operator'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    expect(api.lastDeletePath, '/api/mst-operator/1');
  });

  testWidgets('regu tab lists regu and add button is hidden without create', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasteroperator:read'],
      MasterOperatorReguScreen(
        repository: MasterOperatorReguRepository(api: api),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('master-operator-regu-tab-regu')));
    await tester.pumpAndSettle();
    expect(find.text('REGU A'), findsOneWidget);
    expect(find.text('REGU B'), findsOneWidget);
    expect(find.text('KEPALA REGU'), findsOneWidget);
    expect(find.byKey(const ValueKey('regu-add')), findsNothing);
  });
}
