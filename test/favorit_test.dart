import 'dart:async';

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
}) => {'tipe': tipe, 'kode': kode, 'urutan': urutan, 'komentar': komentar};

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
  bool failWrites = false;

  /// Simulasi: POST sukses, tapi GET berikutnya belum memuat entri baru.
  bool ignorePostInList = false;

  Exception _writeError() => ApiException(
    500,
    'boom',
    responseBody: '{"success":false,"message":"boom"}',
  );

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
    if (failWrites) throw _writeError();
    if (ignorePostInList) return {"success": true};
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
    if (failWrites) throw _writeError();
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

  test(
    'repository lists, adds, removes and reorders via /api/favorit',
    () async {
      final api = FakeApi();
      final repo = FavoritRepository(api: api);

      final items = await repo.fetchAll();
      expect(items.length, 2);
      expect(api.lastPath, '/api/favorit');

      await repo.add(tipe: 'menu', kode: '/master/mesin', komentar: 'sering');
      expect(api.lastBody, {
        'tipe': 'menu',
        'kode': '/master/mesin',
        'komentar': 'sering',
      });
      expect(api.postCalls, 1);

      await repo.remove(tipe: 'menu', kode: '/master/barang');
      expect(api.lastPath, '/api/favorit/menu/%2Fmaster%2Fbarang');
      expect(api.deleteCalls, 1);

      await repo.reorder([
        FavoritRow(
          tipe: 'laporan',
          kode: '/api/laporan/mutasi/washing',
          urutan: 2,
          komentar: '',
        ),
        FavoritRow(
          tipe: 'menu',
          kode: '/master/barang',
          urutan: 1,
          komentar: '',
        ),
      ]);
      expect(api.lastPath, '/api/favorit/urutan');
      expect(api.lastBody?['items'], [
        {'tipe': 'laporan', 'kode': '/api/laporan/mutasi/washing'},
        {'tipe': 'menu', 'kode': '/master/barang'},
      ]);
      expect(api.putCalls, 1);
    },
  );

  test('toggle rolls back and rethrows when the server write fails', () async {
    final api = FakeApi()..failWrites = true;
    final vm = FavoritViewModel(FavoritRepository(api: api));

    await vm.load();
    final before = vm.rows.length;
    expect(vm.isFavorite('menu', '/master/barang'), isTrue);

    // Gagal menambahkan -> rollback, bintang tetap tidak kuning
    await expectLater(
      vm.toggle(tipe: 'menu', kode: '/master/mesin', komentar: 'x'),
      throwsA(isA<ApiException>()),
    );
    expect(vm.rows.length, before);
    expect(vm.isFavorite('menu', '/master/mesin'), isFalse);

    // Gagal menghapus -> rollback, entri lama tetap ada
    final row = vm.rows.first;
    await expectLater(vm.removeItem(row), throwsA(isA<ApiException>()));
    expect(vm.rows.length, before);
    expect(vm.isFavorite(row.tipe, row.kode), isTrue);

    // Gagal toggle keluar -> rollback, entri lama tetap ada
    await expectLater(
      vm.toggle(tipe: 'menu', kode: '/master/barang'),
      throwsA(isA<ApiException>()),
    );
    expect(vm.rows.length, before);
    expect(vm.isFavorite('menu', '/master/barang'), isTrue);

    vm.dispose();
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
    final favorit = FavoritViewModel(FavoritRepository(api: FakeApi()));
    await favorit.load();
    addTearDown(favorit.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: permissions),
          ChangeNotifierProvider.value(value: favorit),
        ],
        child: MaterialApp(debugShowCheckedModeBanner: false, home: child),
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

  testWidgets(
    'favorite button shows snackbar and rolls back when server write fails',
    (tester) async {
      final api = FakeApi()..failWrites = true;
      final favorit = FavoritViewModel(FavoritRepository(api: api));
      await favorit.load();
      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider.value(value: favorit)],
          child: const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              body: Center(
                child: FavoriteButton(tipe: 'menu', kode: '/master/mesin'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'cek mesin');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Gagal mengubah favorit'), findsOneWidget);
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);
      favorit.dispose();
    },
  );

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

  // --- Production: ikon tidak menjadi kuning walau data masuk DB ----------

  test('kolom CHAR ber-padding / alias PascalCase tetap dianggap favorit', () {
    final row = FavoritRow.fromJson({
      'Tipe': 'menu                ',
      'Kode': '/master/barang      ',
      'Urutan': '3',
      'Komentar': null,
    });
    expect(row.tipe, 'menu');
    expect(row.kode, '/master/barang');
    expect(row.urutan, 3);
    expect(row.komentar, '');
    expect(row.matches('menu', '/master/barang'), isTrue);
  });

  test(
    'reload setelah tambah tidak memakai fetch lama yang masih berjalan',
    () async {
      final api = SlowFirstGetApi();
      final vm = FavoritViewModel(FavoritRepository(api: api));
      addTearDown(vm.dispose);

      // Fetch awal app shell masih jalan (jaringan production lambat) dan
      // sudah membaca daftar SEBELUM favorit baru disimpan.
      final initial = vm.load();
      final toggle = vm.toggle(tipe: 'menu', kode: '/master/mesin');
      await Future<void>.delayed(Duration.zero);
      expect(vm.isFavorite('menu', '/master/mesin'), isTrue);

      api.releaseFirstGet();
      await initial;
      await toggle;

      expect(api.postCalls, 1);
      expect(api.getCalls, 2, reason: 'harus ada fetch baru setelah POST');
      expect(vm.isFavorite('menu', '/master/mesin'), isTrue);
    },
  );

  test(
    'server menerima POST tapi daftar reload belum memuatnya → tetap kuning',
    () async {
      final api = FakeApi()..ignorePostInList = true;
      final vm = FavoritViewModel(FavoritRepository(api: api));
      addTearDown(vm.dispose);
      await vm.load();
      await vm.toggle(tipe: 'menu', kode: '/master/mesin', komentar: 'x');
      expect(api.postCalls, 1);
      expect(vm.isFavorite('menu', '/master/mesin'), isTrue);
    },
  );

  testWidgets(
    'load() dari initState tidak notify di tengah build dan bintang tetap ter-update',
    (tester) async {
      final api = FakeApi();
      final favorit = FavoritViewModel(FavoritRepository(api: api));
      addTearDown(favorit.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: favorit,
          child: const MaterialApp(
            home: Scaffold(
              body: _LoadsFavoritInInitState(
                child: Center(
                  child: FavoriteButton(tipe: 'menu', kode: '/master/mesin'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Dulu: "setState() or markNeedsBuild() called during build".
      expect(tester.takeException(), isNull);
      expect(api.getCalls, 1);
      expect(find.byIcon(Icons.star_border_rounded), findsOneWidget);

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(api.postCalls, 1);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

/// GET pertama tertahan sampai [releaseFirstGet]; hasilnya daftar lama
/// (dibaca sebelum POST). GET berikutnya langsung mengembalikan data terbaru.
class SlowFirstGetApi extends FakeApi {
  final _gate = Completer<void>();
  late final List<Map<String, dynamic>> _before = List.of(rows);

  void releaseFirstGet() => _gate.complete();

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    if (getCalls == 1) {
      final snapshot = List.of(_before);
      await _gate.future;
      return {'success': true, 'data': snapshot};
    }
    return {'success': true, 'data': rows};
  }
}

/// Meniru AppShell lama: memanggil load() langsung dari initState.
class _LoadsFavoritInInitState extends StatefulWidget {
  const _LoadsFavoritInInitState({required this.child});
  final Widget child;

  @override
  State<_LoadsFavoritInInitState> createState() =>
      _LoadsFavoritInInitStateState();
}

class _LoadsFavoritInInitStateState extends State<_LoadsFavoritInInitState> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<FavoritViewModel>().load());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
