import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_formula/model/master_formula_models.dart';
import 'package:pps_tablet/features/master_formula/repository/master_formula_repository.dart';
import 'package:pps_tablet/features/master_formula/view/master_formula_screen.dart';
import 'package:pps_tablet/features/master_formula/view_model/master_formula_view_model.dart';

Map<String, dynamic> formulaRow({
  int idFormula = 7,
  int mainOutputKategoriId = 1,
  String mainKategori = 'Barang Jadi',
  int mainOutputId = 100,
  String mainOutputNama = 'BOX 20L',
  int jumlahInput = 2,
  int jumlahSecondary = 1,
}) => {
  'IdFormula': idFormula,
  'MainOutputKategoriId': mainOutputKategoriId,
  'MainKategori': mainKategori,
  'MainOutputId': mainOutputId,
  'MainOutputNama': mainOutputNama,
  'JumlahInput': jumlahInput,
  'JumlahSecondary': jumlahSecondary,
};

class FakeApi extends ApiClient {
  List<Map<String, dynamic>> rows = [
    formulaRow(),
    formulaRow(
      idFormula: 8,
      mainOutputId: 101,
      mainOutputNama: 'BOX 10L',
      jumlahInput: 1,
      jumlahSecondary: 0,
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
    if (path == '/api/mst-formula') {
      return {'success': true, 'totalData': rows.length, 'data': rows};
    }
    if (path == '/api/mst-formula/kategori') {
      return {
        'success': true,
        'data': [
          {
            'IdKategori': 1,
            'KodeKategori': 'barangjadi',
            'NamaKategori': 'Barang Jadi',
            'IsWaste': 0,
          },
          {
            'IdKategori': 2,
            'KodeKategori': 'reject',
            'NamaKategori': 'Reject',
            'IsWaste': 1,
          },
        ],
      };
    }
    if (path == '/api/mst-formula/items') {
      final id = int.tryParse('${query?['idKategori']}') ?? 0;
      return {
        'success': true,
        'data': id == 1
            ? [
                {'Id': 100, 'Nama': 'BOX 20L'},
                {'Id': 101, 'Nama': 'BOX 10L'},
              ]
            : [
                {'Id': 300, 'Nama': 'REJECT PCS'},
              ],
      };
    }
    if (path == '/api/mst-formula/detail') {
      return {
        'success': true,
        'data': {
          'IdFormula': 7,
          'MainOutputKategoriId': 1,
          'MainKategori': 'Barang Jadi',
          'MainOutputId': 100,
          'MainOutputNama': 'BOX 20L',
          'Inputs': [
            {
              'KategoriId': 1,
              'KategoriNama': 'Barang Jadi',
              'ItemId': 101,
              'ItemNama': 'BOX 10L',
            },
          ],
          'Secondarys': [
            {
              'KategoriId': 2,
              'KategoriNama': 'Reject',
              'ItemId': 300,
              'ItemNama': 'REJECT PCS',
            },
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
    return {'success': true, 'data': {'IdFormula': 9}};
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
            '{"success":false,"message":"Formula untuk kategori dan output ini sudah ada"}',
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

  test('detail parses inputs and secondarys', () {
    final detail = FormulaDetail.fromJson({
      'IdFormula': 7,
      'MainOutputKategoriId': 1,
      'MainKategori': 'Barang Jadi',
      'MainOutputId': 100,
      'MainOutputNama': 'BOX 20L',
      'Inputs': [
        {
          'KategoriId': 1,
          'KategoriNama': 'Barang Jadi',
          'ItemId': 101,
          'ItemNama': 'BOX 10L',
        },
      ],
      'Secondarys': [
        {
          'KategoriId': 2,
          'KategoriNama': 'Reject',
          'ItemId': 300,
          'ItemNama': 'REJECT PCS',
        },
      ],
    });
    expect(detail.inputs.single.itemNama, 'BOX 10L');
    expect(detail.secondarys.single.kategoriId, 2);
  });

  test('repository lists, writes and deletes via /api/mst-formula', () async {
    final api = FakeApi();
    final repo = MasterFormulaRepository(api: api);

    final items = await repo.fetchAll();
    expect(items.length, 2);
    expect(api.lastPath, '/api/mst-formula');

    final kategori = await repo.fetchKategori();
    expect(kategori.firstWhere((k) => k.isWaste).nama, 'Reject');
    expect(api.lastPath, '/api/mst-formula/kategori');

    final itemOptions = await repo.fetchItems(1);
    expect(itemOptions.length, 2);

    await repo.create(
      mainKategoriId: 1,
      mainOutputId: 100,
      inputs: const [
        {'kategoriId': 1, 'itemId': 101},
      ],
      secondarys: const [
        {'kategoriId': 2, 'itemId': 300},
      ],
    );
    expect(api.lastPath, '/api/mst-formula');
    expect(api.lastBody, {
      'mainKategoriId': 1,
      'mainOutputId': 100,
      'inputs': [
        {'kategoriId': 1, 'itemId': 101},
      ],
      'secondarys': [
        {'kategoriId': 2, 'itemId': 300},
      ],
    });

    await repo.update(
      idFormula: 7,
      mainKategoriId: 1,
      mainOutputId: 100,
      inputs: const [
        {'kategoriId': 1, 'itemId': 101},
      ],
      secondarys: const [],
    );
    expect(api.lastBody?['idFormula'], 7);

    await repo.delete(7);
    expect(api.lastPath, '/api/mst-formula');
    expect(api.lastQuery, {'idFormula': '7'});
  });

  test('view model filters client-side and reloads after save', () async {
    final api = FakeApi();
    final vm = MasterFormulaViewModel(MasterFormulaRepository(api: api));
    await vm.load();
    expect(vm.totalCount, 2);

    vm.setQuery('20l');
    expect(vm.items.single.idFormula, 7);
    vm.setQuery('barang');
    expect(vm.items.length, 2);
    vm.setQuery('');

    await vm.save(
      idFormula: 7,
      mainKategoriId: 1,
      mainOutputId: 100,
      inputs: const [
        {'kategoriId': 1, 'itemId': 101},
      ],
      secondarys: const [],
      label: 'Barang Jadi — BOX 20L',
    );
    expect(api.putCalls, 1);
    vm.dispose();
  });

  test('async load after dispose does not throw or notify', () async {
    final api = FakeApi();
    final vm = MasterFormulaViewModel(MasterFormulaRepository(api: api));
    vm.dispose();
    await vm.load();
    await vm.loadKategori();
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
      MasterFormulaScreen(repository: MasterFormulaRepository(api: api)),
    );
    expect(api.getCalls, 0);
    expect(
      find.text('Anda tidak memiliki akses ke Master Formula.'),
      findsOneWidget,
    );
  });

  testWidgets('lists rows; add hidden without create permission', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['masterformulaproduksi:read'],
      MasterFormulaScreen(repository: MasterFormulaRepository(api: api)),
    );
    expect(find.text('BOX 20L'), findsOneWidget);
    expect(find.text('BOX 10L'), findsOneWidget);
    expect(find.byKey(const ValueKey('formula-add')), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('formula-search')),
      '10l',
    );
    await tester.pumpAndSettle();
    expect(find.text('BOX 20L'), findsNothing);
    expect(find.text('BOX 10L'), findsOneWidget);
  });

  testWidgets('long-press row shows popover; 409 from server surfaces message', (
    tester,
  ) async {
    final api = FakeApi()..deleteConflict = true;
    await setup(
      tester,
      [
        'masterformulaproduksi:read',
        'masterformulaproduksi:update',
        'masterformulaproduksi:delete',
      ],
      MasterFormulaScreen(repository: MasterFormulaRepository(api: api)),
    );
    await tester.longPress(find.text('BOX 20L'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Formula'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    // Snackbar berisi pesan dari server.
    expect(find.textContaining('sudah ada'), findsOneWidget);
  });
}
