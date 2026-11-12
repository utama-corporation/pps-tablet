import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/favorit/model/favorit_row.dart';
import 'package:pps_tablet/features/favorit/repository/favorit_repository.dart';
import 'package:pps_tablet/features/favorit/view/favorit_screen.dart';
import 'package:pps_tablet/features/favorit/view_model/favorit_view_model.dart';
import 'package:pps_tablet/features/favorit/widgets/favorite_button.dart';

Map<String, dynamic> favoritRow({
  String tipe = 'menu',
  String kode = '/master/barang',
  int urutan = 1,
  String komentar = '',
}) =>
    {
      'tipe': tipe,
      'kode': kode,
      'urutan': urutan,
      'komentar': komentar,
    };

class FakeApi extends ApiClient {
  List<Map<String, dynamic>> rows = [
    favoritRow(),
    favoritRow(
      tipe: 'laporan',
      kode: '/api/laporan/mutasi/washing',
      urutan: 2,
      komentar: 'cabut bulanan',
    ),
  ];
  String lastPath = '';
  Map<String, dynamic>? lastBody;
  int getCalls = 0, postCalls = 0, putCalls = 0, deleteCalls = 0;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    lastPath = path;
    if (path == '/api/favorit') return {'success': true, 'data': rows};
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
    final map = body is Map<String, dynamic> ? body : <String, dynamic>{};
    rows = [
      ...rows,
      {
        'tipe': map['tipe'],
        'kode': map['kode'],
        'urutan': rows.length + 1,
        'komentar': map['komentar'] ?? '',
      },
    ];
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
    final parts = path.split('/');
    if (parts.length >= 4 && parts[1] == 'api' && parts[2] == 'favorit') {
      final tipe = Uri.decodeComponent(parts[3]);
      final kode = Uri.decodeComponent(parts.sublist(4).join('/'));
      rows = rows
          .where((r) => !(r['tipe'] == tipe && r['kode'] == kode))
          .toList();
    }
    return {};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('repository lists, adds, removes and reorders via /api/favorit', () async {
    final api = FakeApi();
    final repo = FavoritRepository(api: api);

    final items = await repo.fetchAll();
    expect(items.length, 2);
    expect(api.lastPath, '/api/favorit');

    await repo.add(tipe: 'menu', kode: '/master/mesin', komentar: 'sering');
    expect(api.lastBody, {'tipe': 'menu', 'kode': '/master/mesin', 'komentar': 'sering'});
    expect(api.postCalls, 1);

    await repo.remove(tipe: 'menu', kode: '/master/barang');
    expect(api.lastPath, '/api/favorit/menu/%2Fmaster%2Fbarang');
    expect(api.deleteCalls, 1);

    await repo.reorder([
      FavoritRow(tipe: 'laporan', kode: '/api/laporan/mutasi/washing', urutan: 2, komentar: ''),
      FavoritRow(tipe: 'menu', kode: '/master/barang', urutan: 1, komentar: ''),
    ]);
    expect(api.lastPath, '/api/favorit/urutan');
    expect(api.lastBody?['items'], [
      {'tipe': 'laporan', 'kode': '/api/laporan/mutasi/washing'},
      {'tipe': 'menu', 'kode': '/master/barang'},
    ]);
    expect(api.putCalls, 1);
  });

  test('view model toggle, isFavorite, remove and reorder', () async {
    final api = FakeApi();
    final vm = FavoritViewModel(FavoritRepository(api: api));

    await vm.load();
    expect(vm.rows.length, 2);
    expect(vm.isFavorite('menu', '/master/barang'), isTrue);

    // Toggle entri yang sudah ada → dihapus
    await vm.toggle(tipe: 'menu', kode: '/master/barang');
    expect(vm.isFavorite('menu', '/master/barang'), isFalse);

    // Toggle entri baru → ditambahkan (list di-reload)
    await vm.toggle(tipe: 'menu', kode: '/master/mesin', komentar: 'cek');
    expect(vm.isFavorite('menu', '/master/mesin'), isTrue);

    final before = vm.rows.length;
    await vm.reorder(before - 1, 0);
    expect(vm.rows.first.kode, '/master/mesin');
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
    // Pastikan VM favorit ikut root provider seperti di main.dart.
    final favorit = FavoritViewModel(
      FavoritRepository(api: FakeApi()),
    );
    await favorit.load();
    addTearDown(favorit.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: permissions),
          ChangeNotifierProvider.value(value: favorit),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return permissions;
  }

  testWidgets('favorit screen lists rows with comment and delete action', (
    tester,
  ) async {
    await setup(tester, [], const FavoritScreen());
    expect(find.text('Master Barang'), findsOneWidget);
    expect(find.textContaining('cabut bulanan'), findsOneWidget);
    expect(find.byKey(const ValueKey('favorit-list')), findsOneWidget);
  });

  testWidgets('favorite button toggles with comment dialog', (tester) async {
    await setup(
      tester,
      [],
      const Center(
        child: FavoriteButton(tipe: 'menu', kode: '/master/mesin'),
      ),
    );
    await tester.tap(find.byType(IconButton));
    await tester.pumpAndSettle();
    expect(find.text('Tambah Favorit'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'cek mesin');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
  });
}
