import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_supplier/repository/master_supplier_repository.dart';
import 'package:pps_tablet/features/master_supplier/view/master_supplier_screen.dart';
import 'package:pps_tablet/features/master_supplier/view_model/master_supplier_view_model.dart';

Map<String, dynamic> supplierRow({
  int id = 1,
  String nama = 'PT SUMBER PLASTIK',
  String initial = 'SP',
  String noTlp = '0812-3456',
  int enable = 1,
}) => {
  'IdSupplier': id,
  'NmSupplier': nama,
  'Initial': initial,
  'NoTlp': noTlp,
  'Enable': enable,
};

class FakeApi extends ApiClient {
  List<Map<String, dynamic>> suppliers = [
    supplierRow(),
    supplierRow(id: 2, nama: 'CV MAJU BERSAMA', initial: 'MB', noTlp: '0856-7890', enable: 0),
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
    if (path == '/api/mst-supplier') return {'success': true, 'totalData': suppliers.length, 'data': suppliers};
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
    return {'success': true, 'data': supplierRow(id: 3, nama: 'BARU')};
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
    return {'success': true, 'data': supplierRow()};
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
            '{"success":false,"message":"Supplier sudah dipakai di transaksi dan tidak bisa dihapus. Nonaktifkan saja."}',
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

  test('repository lists with status filter and writes to /api/mst-supplier', () async {
    final api = FakeApi();
    final repo = MasterSupplierRepository(api: api);

    final items = await repo.fetchAll();
    expect(items.length, 2);
    expect(api.lastQuery, {'status': 'all'});

    await repo.create(namaSupplier: 'PT BARU', initial: 'PB', noTlp: '0811', enable: true);
    expect(api.lastPath, '/api/mst-supplier');
    expect(api.lastBody, {
      'namaSupplier': 'PT BARU',
      'initial': 'PB',
      'noTlp': '0811',
      'enable': 1,
    });

    await repo.update(id: 1, namaSupplier: 'SP', initial: '', noTlp: '', enable: false);
    expect(api.lastPath, '/api/mst-supplier/1');
    expect(api.lastBody?['enable'], 0);

    await repo.delete(1);
    expect(api.lastPath, '/api/mst-supplier/1');
    expect(api.deleteCalls, 1);
  });

  test('view model filters client-side and reloads after save', () async {
    final api = FakeApi();
    final vm = MasterSupplierViewModel(MasterSupplierRepository(api: api));
    await vm.load();
    expect(vm.totalCount, 2);

    vm.setQuery('maju');
    expect(vm.items.single.namaSupplier, 'CV MAJU BERSAMA');
    vm.setQuery('');

    await vm.save(id: 2, namaSupplier: 'CV MAJU LAGI', initial: 'MB', noTlp: '', enable: false);
    expect(api.putCalls, 1);
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
      MasterSupplierScreen(repository: MasterSupplierRepository(api: api)),
    );
    expect(api.getCalls, 0);
    expect(find.text('Anda tidak memiliki akses ke Master Supplier.'), findsOneWidget);
  });

  testWidgets('lists suppliers; add hidden without create permission', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamastersupplier:read'],
      MasterSupplierScreen(repository: MasterSupplierRepository(api: api)),
    );
    expect(find.text('PT SUMBER PLASTIK'), findsOneWidget);
    expect(find.text('CV MAJU BERSAMA'), findsOneWidget);
    expect(find.byKey(const ValueKey('supplier-add')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('supplier-search')), 'maju');
    await tester.pumpAndSettle();
    expect(find.text('PT SUMBER PLASTIK'), findsNothing);
    expect(find.text('CV MAJU BERSAMA'), findsOneWidget);
  });

  testWidgets('long-press row shows popover; 409 from server surfaces message', (
    tester,
  ) async {
    final api = FakeApi()..deleteConflict = true;
    await setup(
      tester,
      [
        'datamastersupplier:read',
        'datamastersupplier:update',
        'datamastersupplier:delete',
      ],
      MasterSupplierScreen(repository: MasterSupplierRepository(api: api)),
    );
    await tester.longPress(find.text('PT SUMBER PLASTIK'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Supplier'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    // Snackbar berisi pesan dari server (supplier dipakai transaksi).
    expect(find.textContaining('sudah dipakai di transaksi'), findsOneWidget);
  });
}
