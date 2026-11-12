import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_barang/repository/master_barang_repository.dart';
import 'package:pps_tablet/features/master_barang/view/master_barang_screen.dart';
import 'package:pps_tablet/features/master_barang/view_model/master_barang_view_model.dart';

Map<String, dynamic> metaFixture() => {
  'success': true,
  'data': {
    'types': [
      {
        'key': 'bonggolan',
        'label': 'Bonggolan',
        'nameLabel': 'Nama',
        'fields': [
          {
            'key': 'itemCode',
            'label': 'Item Code',
            'kind': 'text',
            'maxLength': 50,
            'list': true,
          },
        ],
      },
      {
        'key': 'barang-jadi',
        'label': 'Barang Jadi',
        'nameLabel': 'Nama',
        'fields': [
          {
            'key': 'itemCode',
            'label': 'Item Code',
            'kind': 'text',
            'maxLength': 50,
            'list': true,
          },
          {
            'key': 'idBJType',
            'label': 'Tipe BJ',
            'kind': 'select',
            'source': 'bjtype',
            'required': true,
            'list': true,
          },
          {
            'key': 'idTypeSubBarang',
            'label': 'Sub Tipe',
            'kind': 'select',
            'source': 'subbarang',
            'dependsOn': 'idBJType',
            'list': true,
          },
          {
            'key': 'idUOM',
            'label': 'UOM',
            'kind': 'select',
            'source': 'uom',
            'required': true,
            'list': true,
          },
          {'key': 'minStock', 'label': 'Min Stock', 'kind': 'decimal'},
        ],
      },
    ],
    'summary': [
      {'key': 'bonggolan', 'total': 3, 'aktif': 2},
      {'key': 'barang-jadi', 'total': 5, 'aktif': 4},
    ],
    'options': {
      'uom': [
        {'id': 1, 'label': 'PCS'},
        {'id': 2, 'label': 'KG'},
      ],
      'bjtype': [
        {'id': 11, 'label': 'Kursi'},
        {'id': 12, 'label': 'Meja'},
      ],
      'subbarang': [
        {'id': 21, 'label': 'Kursi Anak', 'parentId': 11},
        {'id': 22, 'label': 'Meja Tamu', 'parentId': 12},
      ],
    },
  },
};

class FakeApi extends ApiClient {
  Map<String, dynamic> meta = metaFixture();
  Map<String, List<Map<String, dynamic>>> lists = {
    'bonggolan': [
      {'id': 201, 'nama': 'Bonggolan A', 'enable': true, 'itemCode': 'BG.001'},
      {'id': 202, 'nama': 'Bonggolan Zeta', 'enable': false, 'itemCode': ''},
    ],
    'barang-jadi': [
      {
        'id': 101,
        'nama': 'Kursi Natural',
        'enable': true,
        'itemCode': 'BJ.101',
        'idBJType': 11,
        'idBJTypeLabel': 'Kursi',
        'idTypeSubBarang': 21,
        'idTypeSubBarangLabel': 'Kursi Anak',
        'idUOM': 1,
        'idUOMLabel': 'PCS',
        'minStock': 10,
      },
    ],
  };
  String lastPath = '';
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastBody;
  String? lastDeletePath;
  int getCalls = 0, postCalls = 0, putCalls = 0, deleteCalls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    lastPath = path;
    lastQuery = query;
    if (path == '/api/mst-barang/meta') return meta;
    final match = RegExp(r'^/api/mst-barang/([^/]+)$').firstMatch(path);
    if (match != null) return {'data': lists[match.group(1)] ?? const <dynamic>[]};
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
    return {'success': true, 'data': {'id': 999}};
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
    return {'success': true, 'data': {'id': 1}};
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
    lastDeletePath = path;
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('fetchMeta parses types, summary and options', () async {
    final api = FakeApi();
    final repo = MasterBarangRepository(api: api);
    final meta = await repo.fetchMeta();

    expect(meta.types.map((t) => t.key), ['bonggolan', 'barang-jadi']);
    expect(meta.typeFor('bonggolan')!.fields.single.kind, 'text');
    final bj = meta.typeFor('barang-jadi')!;
    expect(bj.fields.firstWhere((f) => f.key == 'idBJType').required, isTrue);
    expect(bj.fields.firstWhere((f) => f.key == 'idTypeSubBarang').dependsOn,
        'idBJType');
    expect(meta.summary['bonggolan']!.total, 3);
    expect(meta.summary['bonggolan']!.aktif, 2);
    expect(meta.optionsFor('subbarang', parentId: 11).single.label, 'Kursi Anak');
    expect(meta.optionsFor('subbarang', parentId: 12).single.label, 'Meja Tamu');
    expect(meta.optionsFor('uom').length, 2);
  });

  test('repository list uses :type path and optional search', () async {
    final api = FakeApi();
    final repo = MasterBarangRepository(api: api);

    final items = await repo.fetchList('bonggolan', search: 'a');
    expect(items.length, 2);
    expect(api.lastPath, '/api/mst-barang/bonggolan');
    expect(api.lastQuery, {'search': 'a'});
  });

  test('repository writes hit the REST endpoints', () async {
    final api = FakeApi();
    final repo = MasterBarangRepository(api: api);

    await repo.create('bonggolan', {'nama': 'Bonggolan C', 'enable': true, 'itemCode': 'BG.003'});
    expect(api.lastPath, '/api/mst-barang/bonggolan');
    expect(api.lastBody, {'nama': 'Bonggolan C', 'enable': true, 'itemCode': 'BG.003'});

    await repo.update('bonggolan', 202, {'nama': 'Bonggolan B2', 'enable': false});
    expect(api.lastPath, '/api/mst-barang/bonggolan/202');
    expect(api.lastBody?['nama'], 'Bonggolan B2');

    await repo.disable('bonggolan', 201);
    expect(api.lastPath, '/api/mst-barang/bonggolan/201');
    expect(api.deleteCalls, 1);
  });

  test('view model: selectType loads list, query filters, disable reloads', () async {
    final api = FakeApi();
    final vm = MasterBarangViewModel(MasterBarangRepository(api: api));
    await vm.loadMeta();
    await vm.selectType('bonggolan');
    expect(vm.items.map((i) => i.nama), ['Bonggolan A', 'Bonggolan Zeta']);

    vm.setQuery('a');
    expect(vm.items.length, 2);
    vm.setQuery('zeta');
    expect(vm.items.single.nama, 'Bonggolan Zeta');
    vm.setQuery('');

    await vm.disable(201);
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
      MasterBarangScreen(repository: MasterBarangRepository(api: api)),
    );
    expect(api.getCalls, 0);
    expect(find.text('Anda tidak memiliki akses ke Master Barang.'), findsOneWidget);
  });

  testWidgets('overview shows 11 jenis dari meta dengan ringkasan', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasterbarang:read'],
      MasterBarangScreen(repository: MasterBarangRepository(api: api)),
    );
    expect(find.text('Bonggolan'), findsOneWidget);
    expect(find.text('Barang Jadi'), findsOneWidget);
    expect(find.text('2 aktif dari 3'), findsOneWidget);
    expect(find.text('4 aktif dari 5'), findsOneWidget);
  });

  testWidgets('tap tile opens list; long-press disables row', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      [
        'datamasterbarang:read',
        'datamasterbarang:delete',
      ],
      MasterBarangScreen(repository: MasterBarangRepository(api: api)),
    );
    await tester.tap(find.byKey(const ValueKey('mb-tile-bonggolan')));
    await tester.pumpAndSettle();
    expect(find.text('Bonggolan A'), findsOneWidget);
    expect(find.text('Bonggolan Zeta'), findsOneWidget);

    await tester.longPress(find.text('Bonggolan A'));
    await tester.pumpAndSettle();
    expect(find.text('Ubah'), findsOneWidget);
    await tester.tap(find.text('Nonaktifkan'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 0);
    expect(find.text('Nonaktifkan Bonggolan'), findsOneWidget);
    await tester.tap(find.text('Nonaktifkan'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    expect(api.lastDeletePath, '/api/mst-barang/bonggolan/201');
  });

  testWidgets('dynamic columns render join labels and search filters rows', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasterbarang:read'],
      MasterBarangScreen(repository: MasterBarangRepository(api: api)),
    );
    await tester.tap(find.byKey(const ValueKey('mb-tile-barang-jadi')));
    await tester.pumpAndSettle();
    expect(find.text('Kursi Natural'), findsOneWidget);
    expect(find.text('BJ.101'), findsOneWidget);
    expect(find.text('Kursi'), findsOneWidget);
    expect(find.byKey(const ValueKey('mb-add')), findsNothing); // no create

    await tester.enterText(find.byKey(const ValueKey('mb-search')), 'natural');
    await tester.pumpAndSettle();
    expect(find.text('Kursi Natural'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('mb-search')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Kursi Natural'), findsNothing);
  });
}
