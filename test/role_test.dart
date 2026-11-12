import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/role/model/role_models.dart';
import 'package:pps_tablet/features/role/repository/role_repository.dart';
import 'package:pps_tablet/features/role/view_model/role_view_model.dart';
import 'package:pps_tablet/features/role/view/role_screen.dart';

Map<String, dynamic> roleRow({
  int id = 1,
  String name = 'GUDANG',
  int totalPermission = 3,
  int totalAllow = 2,
}) => {
  'IdUGroup': id,
  'UGroupName': name,
  'TotalPermission': totalPermission,
  'TotalAllow': totalAllow,
};

Map<String, dynamic> permissionRow(String no, String description) => {
  'NoPermission': no,
  'Permission': description,
};

class FakeApi extends ApiClient {
  Map<String, dynamic> response = {'data': <dynamic>[]};
  String? lastPath;
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastBody;
  int getCalls = 0, postCalls = 0, putCalls = 0, deleteCalls = 0;
  String? putPath;
  String? deletePath;

  final _roles = [
    roleRow(),
    roleRow(id: 2, name: 'PRODUKSI', totalPermission: 3, totalAllow: 1),
  ];

  final _permissions = [
    permissionRow('datamasteruser:read', 'Lihat data user'),
    permissionRow('datamasteruser:create', 'Tambah data user'),
    permissionRow('bongkarsusun:read', 'Lihat bongkar susun'),
  ];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    lastPath = path;
    lastQuery = query;
    if (path == '/api/master-permission-group') {
      return {'data': _roles};
    }
    if (path == '/api/master-permission-group/permissions') {
      return {'data': _permissions};
    }
    final detail = RegExp(
      r'^/api/master-permission-group/(\d+)$',
    ).firstMatch(path);
    if (detail != null) {
      return {
        'data': {
          'Permissions': [
            {'NoPermission': 'datamasteruser:read', 'Allow': true},
            {'NoPermission': 'datamasteruser:create', 'Allow': false},
            {'NoPermission': 'bongkarsusun:read', 'Allow': 1},
          ],
        },
      };
    }
    return response;
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
    putPath = path;
    lastBody = body is Map<String, dynamic> ? body : null;
    return response;
  }

  @override
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    deleteCalls++;
    lastPath = path;
    deletePath = path;
    lastQuery = query;
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('model parses roles and permission items', () {
    final role = RoleGroup.fromJson({
      'IdUGroup': '7',
      'UGroupName': 'QC',
      'TotalPermission': '4',
      'TotalAllow': '3',
    });
    expect(role.id, 7);
    expect(role.name, 'QC');
    expect(role.totalPermission, 4);
    expect(role.totalAllow, 3);
    expect(role.allowRatio, closeTo(0.75, 0.001));

    final item = PermissionItem.fromJson(permissionRow('modul:read', 'Ket'));
    expect(item.no, 'modul:read');
    expect(item.module, 'modul');
    expect(PermissionItem.fromJson({'NoPermission': 'nodusel'}).module,
        'nodusel');
  });

  test('repository targets server contract with encoded paths', () async {
    final api = FakeApi();
    final repo = RoleRepository(api: api);

    await repo.fetchRoles();
    expect(api.lastPath, '/api/master-permission-group');

    await repo.fetchPermissions();
    expect(api.lastPath, '/api/master-permission-group/permissions');

    final allows = await repo.fetchRoleAllows(3);
    expect(api.lastPath, '/api/master-permission-group/3');
    expect(allows, {
      'datamasteruser:read': true,
      'datamasteruser:create': false,
      'bongkarsusun:read': true,
    });

    const all = [
      PermissionItem(no: 'datamasteruser:read', description: ''),
      PermissionItem(no: 'datamasteruser:create', description: ''),
    ];
    await repo.createRole(
      name: 'QC',
      all: all,
      allow: {'datamasteruser:read': true},
    );
    expect(api.lastBody, {
      'uGroupName': 'QC',
      'permissions': [
        {'noPermission': 'datamasteruser:read', 'allow': true},
        {'noPermission': 'datamasteruser:create', 'allow': false},
      ],
    });

    await repo.updateRole(
      idUGroup: 5,
      name: 'QC',
      all: all,
      allow: {'datamasteruser:create': true},
    );
    expect(api.lastPath, '/api/master-permission-group/5');

    await repo.deleteRole(5);
    expect(api.lastPath, '/api/master-permission-group/5');
    expect(api.deleteCalls, 1);

    await repo.updatePermission('modul:read', 'Keterangan');
    expect(api.lastPath, '/api/master-permission-group/permissions/modul%3Aread');

    await repo.deletePermission('modul:read');
    expect(
      api.lastPath,
      '/api/master-permission-group/permissions/modul%3Aread',
    );
  });

  test('view model load, search filter and delete flow', () async {
    final api = FakeApi();
    final vm = RoleViewModel(RoleRepository(api: api));
    await vm.load();
    expect(vm.items.length, 2);
    expect(vm.permissions.length, 3);
    expect(vm.error, isEmpty);
    vm.setSearch('prod');
    expect(vm.items.length, 1);
    expect(vm.items.single.name, 'PRODUKSI');
    vm.setSearch('2');
    expect(vm.items.single.name, 'PRODUKSI');
    vm.setSearch('');
    await vm.deleteRole(1);
    expect(api.deleteCalls, 1);
    expect(vm.error, isEmpty);
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
      RoleScreen(repository: RoleRepository(api: api)),
    );
    expect(api.getCalls, 0);
    expect(
      find.text('Anda tidak memiliki akses ke menu Role.'),
      findsOneWidget,
    );
  });

  testWidgets('list renders roles and search filters rows', (tester) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasterpermissiongroup:read'],
      RoleScreen(repository: RoleRepository(api: api)),
    );
    expect(find.text('GUDANG'), findsOneWidget);
    expect(find.text('PRODUKSI'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'prod');
    await tester.pumpAndSettle();
    expect(find.text('PRODUKSI'), findsOneWidget);
    expect(find.text('GUDANG'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press opens quick actions and delete calls API', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      [
        'datamasterpermissiongroup:read',
        'datamasterpermissiongroup:delete',
      ],
      RoleScreen(repository: RoleRepository(api: api)),
    );
    await tester.longPress(find.text('GUDANG'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Role'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    expect(api.deletePath, '/api/master-permission-group/1');
    expect(tester.takeException(), isNull);
  });

  testWidgets('create dialog validates then submits with correct body', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      [
        'datamasterpermissiongroup:read',
        'datamasterpermissiongroup:create',
      ],
      RoleScreen(repository: RoleRepository(api: api)),
    );
    await tester.tap(find.text('Role Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Role'), findsOneWidget);

    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();
    expect(find.text('Nama Role harus diisi'), findsOneWidget);
    expect(api.postCalls, 0);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nama Role'),
      'SUPERVISOR',
    );
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();

    expect(api.postCalls, 1);
    expect(api.lastBody?['uGroupName'], 'SUPERVISOR');
    final permissions = api.lastBody?['permissions'] as List;
    expect(permissions.length, 3);
    expect(
      permissions.where((p) => p['allow'] == true),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('edit dialog loads current allow flags', (tester) async {
    final api = FakeApi();
    await setup(
      tester,
      [
        'datamasterpermissiongroup:read',
        'datamasterpermissiongroup:update',
      ],
      RoleScreen(repository: RoleRepository(api: api)),
    );
    await tester.longPress(find.text('GUDANG'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ubah'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah Role GUDANG'), findsOneWidget);
    expect(api.lastPath, '/api/master-permission-group/1');
    expect(find.text('2 dari 3 permission diizinkan'), findsOneWidget);

    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();
    expect(api.putCalls, 1);
    expect(api.putPath, '/api/master-permission-group/1');
    final permissions = api.lastBody?['permissions'] as List;
    expect(
      permissions.singleWhere(
        (p) => p['noPermission'] == 'bongkarsusun:read',
      )['allow'],
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}
