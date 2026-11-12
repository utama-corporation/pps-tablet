import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_user/model/master_user_models.dart';
import 'package:pps_tablet/features/master_user/repository/master_user_repository.dart';
import 'package:pps_tablet/features/master_user/view_model/master_user_view_model.dart';
import 'package:pps_tablet/features/master_user/view/master_user_screen.dart';

Map<String, dynamic> userRow({
  int id = 1,
  String username = 'budi',
  String fname = 'Budi',
  String lname = 'Santoso',
  String groupNames = 'GUDANG',
  int isEnable = 1,
}) => {
  'IdUsername': id,
  'Username': username,
  'FName': fname,
  'LName': lname,
  'Nik': '1234567',
  'EmployeeID': 1001,
  'CompanyID': 'AS_GSU',
  'IsEnable': isEnable,
  'GroupName': groupNames,
  'Status': 'OFFLINE',
};

Map<String, dynamic> groupRow(int id, String name) => {
  'IdUGroup': id,
  'UGroupName': name,
};

class FakeApi extends ApiClient {
  Map<String, dynamic> response = {'data': <dynamic>[]};
  String lastPath = '';
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastBody;
  int getCalls = 0, postCalls = 0, putCalls = 0, deleteCalls = 0;

  // When true, the list endpoint omits GroupName (simulates deployments
  // whose list response does not include roles).
  bool omitGroupNames = false;

  List<Map<String, dynamic>> get _users => [
    userRow(),
    userRow(
      id: 2,
      username: 'siti',
      fname: 'Siti',
      lname: 'Aminah',
      groupNames: 'PRODUKSI',
    ),
  ];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    lastPath = path;
    lastQuery = query;
    if (path == '/api/mst-user') {
      if (omitGroupNames) {
        return {
          'data': [
            for (final row in _users)
              {...row}..remove('GroupName'),
          ],
        };
      }
      return {'data': _users};
    }
    if (path == '/api/mst-user/groups') {
      return {'data': [groupRow(1, 'GUDANG'), groupRow(2, 'PRODUKSI')]};
    }
    if (path.endsWith('/group')) {
      final match = RegExp(r'/(\d+)/group$').firstMatch(path);
      final id = int.tryParse(match?.group(1) ?? '1') ?? 1;
      return {
        'data': [groupRow(id, id == 2 ? 'PRODUKSI' : 'GUDANG')],
      };
    }
    if (path.endsWith('/employees')) {
      return {
        'data': [
          {'EmployeeID': 1001, 'EmployeeCode': '1234567', 'FullName': 'Budi Santoso', 'CompanyID': 'AS_GSU'},
        ],
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
    lastQuery = query;
    return response;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const fontDir = String.fromEnvironment('SIDEBAR_TEST_FONT_DIR');
  const screenshotDir = String.fromEnvironment('USER_SCREENSHOT_DIR');
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
    SharedPreferences.setMockInitialValues({});
  });

  test('model parses active and disabled users and group names', () {
    final active = MasterUser.fromJson(userRow());
    expect(active.id, 1);
    expect(active.username, 'budi');
    expect(active.fullName, 'Budi Santoso');
    expect(active.employeeId, 1001);
    expect(active.groupNames, ['GUDANG']);
    expect(active.active, isTrue);

    final disabled = MasterUser.fromJson(userRow(isEnable: 0));
    expect(disabled.active, isFalse);

    final minimal = MasterUser.fromJson({
      'IdUsername': 'x',
      'IsEnable': 'true',
      'GroupName': 'A, B ,',
    });
    expect(minimal.employeeId, isNull);
    expect(minimal.groupNames, ['A', 'B']);
    expect(minimal.active, isTrue);
  });

  test('repository builds query and delete params correctly', () async {
    final api = FakeApi();
    final repo = MasterUserRepository(api: api);
    await repo.fetchUsers(search: '  budi  ');
    expect(api.lastPath, '/api/mst-user');
    expect(api.lastQuery, {'q': 'budi'});
    await repo.fetchUsers();
    expect(api.lastQuery, isNull);
    await repo.searchEmployees(db: 'as_gsu', query: 'budi');
    expect(api.lastQuery, {'db': 'as_gsu', 'q': 'budi'});
    await repo.create({'username': 'x'});
    expect(api.postCalls, 1);
    expect(api.lastBody, {'username': 'x'});
    await repo.update({'idUsername': 1});
    expect(api.putCalls, 1);
    await repo.delete(7);
    expect(api.deleteCalls, 1);
    expect(api.lastPath, '/api/mst-user');
    expect(api.lastQuery, {'idUsername': 7});
  });

  test('view model backfills roles when list GroupName is missing', () async {
    final api = FakeApi()..omitGroupNames = true;
    final vm = MasterUserViewModel(MasterUserRepository(api: api));
    await vm.load();
    final byName = {for (final u in vm.items) u.username: u};
    expect(byName['budi']!.groupNames, ['GUDANG']);
    expect(byName['siti']!.groupNames, ['PRODUKSI']);
    vm.dispose();
  });

  test('view model load, search filter and delete flow', () async {
    final api = FakeApi();
    final vm = MasterUserViewModel(MasterUserRepository(api: api));
    await vm.load();
    expect(vm.items.length, 2);
    expect(vm.groups.length, 2);
    expect(vm.error, isEmpty);
    vm.setSearch('siti');
    expect(vm.items.length, 1);
    expect(vm.items.single.username, 'siti');
    vm.setSearch('PRODUKSI');
    expect(vm.items.single.username, 'siti');
    vm.setSearch('');
    await vm.deleteUser(1);
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
        child: RepaintBoundary(
          key: const ValueKey('capture'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(fontFamily: fontDir.isEmpty ? null : 'Roboto'),
            home: child,
          ),
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
      MasterUserScreen(repository: MasterUserRepository(api: api)),
    );
    expect(api.getCalls, 0);
    expect(find.text('Anda tidak memiliki akses ke menu User.'), findsOneWidget);
  });

  testWidgets('list renders users and search filters rows', (tester) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasteruser:read'],
      MasterUserScreen(repository: MasterUserRepository(api: api)),
    );
    expect(find.text('budi'), findsOneWidget);
    expect(find.text('siti'), findsOneWidget);
    expect(find.text('GUDANG'), findsOneWidget);
    await capture(tester, 'pps-user-screen');
    await tester.enterText(find.byType(TextField), 'siti');
    await tester.pumpAndSettle();
    expect(find.text('siti'), findsWidgets);
    expect(find.text('budi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press opens quick actions and delete calls API', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasteruser:read', 'datamasteruser:delete'],
      MasterUserScreen(repository: MasterUserRepository(api: api)),
    );
    expect(find.text('budi'), findsOneWidget);
    await tester.longPress(find.text('budi'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus User'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('create dialog validates then submits with correct body', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasteruser:read', 'datamasteruser:create'],
      MasterUserScreen(repository: MasterUserRepository(api: api)),
    );
    await tester.tap(find.text('User Baru'));
    await tester.pumpAndSettle();
    expect(find.text('Tambah User'), findsOneWidget);
    await capture(tester, 'pps-user-create-dialog');

    // submit without data -> validation error, no API call
    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Data user belum lengkap'), findsOneWidget);
    expect(api.postCalls, 0);

    // pick employee via the picker
    await tester.enterText(find.widgetWithText(TextField, 'Nama / ID / kode karyawan…'), 'budi');
    await tester.tap(find.text('Cari'));
    await tester.pumpAndSettle();
    final pickerResult = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('Budi Santoso'),
    );
    expect(pickerResult, findsOneWidget);
    await tester.tap(pickerResult);
    await tester.pumpAndSettle();

    // fill username + password
    await tester.enterText(find.widgetWithText(TextField, 'Username'), 'budi2');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'Utama1234');
    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('GUDANG'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('SIMPAN'));
    await tester.pumpAndSettle();

    expect(api.postCalls, 1);
    expect(api.lastBody?['username'], 'budi2');
    expect(api.lastBody?['idUGroup'], isNotEmpty);
    expect(api.lastBody?['employeeId'], 1001);
    expect(tester.takeException(), isNull);
  });
}
