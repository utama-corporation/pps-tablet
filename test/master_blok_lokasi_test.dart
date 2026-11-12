import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/master_blok_lokasi/repository/master_blok_lokasi_repository.dart';
import 'package:pps_tablet/features/master_blok_lokasi/view/master_blok_lokasi_screen.dart';
import 'package:pps_tablet/features/master_blok_lokasi/view_model/master_blok_lokasi_view_model.dart';

class FakeApi extends ApiClient {
  String lastPath = '';
  Map<String, dynamic>? lastQuery;
  Map<String, dynamic>? lastBody;
  int getCalls = 0, postCalls = 0, putCalls = 0, deleteCalls = 0;
  bool deleteBlokConflict = false;

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    getCalls++;
    lastPath = path;
    lastQuery = query;
    if (path == '/api/mst-blok-lokasi/master') {
      return {
        'success': true,
        'data': {
          'warehouses': [
            {'IdWarehouse': 1, 'NamaWarehouse': 'GUDANG A'},
          ],
          'kategoris': [
            {
              'IdKategori': 2,
              'KodeKategori': 'reject',
              'NamaKategori': 'Reject',
              'NamaTableJenis': 'MstReject',
              'NamaKolomIdJenis': 'IdReject',
              'NamaKolomNamaJenis': 'NamaReject',
            },
          ],
        },
      };
    }
    if (path == '/api/mst-blok-lokasi/blok') {
      return {
        'success': true,
        'data': [
          {'Blok': 'A', 'IdWarehouse': 1, 'NamaWarehouse': 'GUDANG A'},
          {'Blok': 'B', 'IdWarehouse': 1, 'NamaWarehouse': 'GUDANG A'},
        ],
      };
    }
    if (path == '/api/mst-blok-lokasi/lokasi') {
      if (query?['blok'] == 'A') {
        return {
          'success': true,
          'data': [
            {
              'IdLokasi': 1,
              'Blok': 'A',
              'Description': 'Rak A baris 1',
              'Enable': 1,
            },
          ],
        };
      }
      return {'success': true, 'data': <dynamic>[]};
    }
    if (path == '/api/mst-blok-lokasi/lokasi/next-id') {
      return {'success': true, 'data': {'nextId': 2}};
    }
    if (path == '/api/mst-blok-lokasi/jenis') {
      return {
        'success': true,
        'data': [
          {'Id': 55, 'Nama': 'REJECT PCS'},
        ],
      };
    }
    if (path == '/api/mst-blok-lokasi/lokasi-jenis') {
      return {
        'success': true,
        'data': [
          {
            'Blok': 'A',
            'IdLokasi': 1,
            'IdKategori': 2,
            'IdJenis': 55,
            'NamaKategori': 'Reject',
            'NamaJenis': 'REJECT PCS',
          },
        ],
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
    return {'success': true, 'data': {'Blok': 'C', 'IdWarehouse': 1}};
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
    if (deleteBlokConflict) {
      throw ApiException(
        409,
        'DELETE $path failed',
        responseBody:
            '{"success":false,"message":"Blok tidak bisa dihapus"}',
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

  test('repository blok & lokasi endpoints and cascade payloads', () async {
    final api = FakeApi();
    final repo = MasterBlokLokasiRepository(api: api);

    final master = await repo.fetchMaster();
    expect(master.warehouses.single.nama, 'GUDANG A');
    expect(master.jenisKategoris.single.nama, 'Reject');

    final bloks = await repo.fetchBloks();
    expect(bloks.length, 2);

    await repo.createBlok(blok: 'C', idWarehouse: 1);
    expect(api.lastPath, '/api/mst-blok-lokasi/blok');
    expect(api.lastBody, {'blok': 'C', 'idWarehouse': 1});

    await repo.updateBlok(blok: 'C', idWarehouse: 1);
    expect(api.lastPath, '/api/mst-blok-lokasi/blok/C');

    await repo.deleteBlok('C');
    expect(api.lastPath, '/api/mst-blok-lokasi/blok/C');

    final lokasis = await repo.fetchLokasi('A');
    expect(lokasis.single.description, 'Rak A baris 1');
    expect(api.lastQuery, {'blok': 'A'});

    final nextId = await repo.fetchNextIdLokasi('A');
    expect(nextId, 2);

    await repo.createLokasi(blok: 'A', description: 'Rak A baris 2', enable: true);
    expect(api.lastBody, {
      'blok': 'A',
      'description': 'Rak A baris 2',
      'enable': true,
    });

    await repo.updateLokasi(
      blok: 'A',
      idLokasi: 1,
      description: 'Rak A baris 1A',
      enable: false,
    );
    expect(api.lastPath, '/api/mst-blok-lokasi/lokasi/A/1');

    await repo.addLokasiJenis(
      blok: 'A',
      idLokasi: 1,
      idKategori: 2,
      idJenis: 55,
    );
    expect(api.lastBody, {
      'blok': 'A',
      'idLokasi': 1,
      'idKategori': 2,
      'idJenis': 55,
    });

    await repo.removeLokasiJenis(
      blok: 'A',
      idLokasi: 1,
      idKategori: 2,
      idJenis: 55,
    );
    expect(api.lastPath, '/api/mst-blok-lokasi/lokasi-jenis/A/1/2/55');
  });

  test('selectBlok loads lokasi; selezion lokasi loads jenis', () async {
    final api = FakeApi();
    final vm = MasterBlokLokasiViewModel(MasterBlokLokasiRepository(api: api));
    await vm.loadBloks();
    expect(vm.bloks.length, 2);

    await vm.selectBlok('A');
    expect(vm.lokasis.single.description, 'Rak A baris 1');

    await vm.selectLokasi(vm.lokasis.single);
    expect(vm.lokasiJenis.single.namaJenis, 'REJECT PCS');

    vm.dispose();
  });

  test('async load after dispose does not throw or notify', () async {
    final api = FakeApi();
    final vm = MasterBlokLokasiViewModel(MasterBlokLokasiRepository(api: api));
    vm.dispose();
    await vm.loadBloks();
    await vm.loadMaster();
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
      MasterBlokLokasiScreen(
        repository: MasterBlokLokasiRepository(api: api),
      ),
    );
    expect(api.getCalls, 0);
    expect(
      find.text('Anda tidak memiliki akses ke Blok & Lokasi.'),
      findsOneWidget,
    );
  });

  testWidgets('lists bloks; selecting one shows lokasinya; add hidden w/o create', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      ['datamasterbloklokasi:read'],
      MasterBlokLokasiScreen(
        repository: MasterBlokLokasiRepository(api: api),
      ),
    );
    expect(find.text('GUDANG A'), findsWidgets);
    expect(find.byKey(const ValueKey('blok-add')), findsNothing);

    // Belum memilih blok — panel kanan meminta memilih blok.
    expect(find.text('Pilih blok di kiri untuk melihat lokasinya'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('blok-tile-A')));
    await tester.pumpAndSettle();
    expect(find.text('Rak A baris 1'), findsOneWidget);

    // Ketuk baris lokasi — panel jenis menampilkan isi MstLokasiJenis.
    await tester.tap(find.text('Rak A baris 1'));
    await tester.pumpAndSettle();
    expect(find.text('Reject · REJECT PCS'), findsOneWidget);
  });

  testWidgets('long-press blok shows popover; delete confirm cascades', (
    tester,
  ) async {
    final api = FakeApi();
    await setup(
      tester,
      [
        'datamasterbloklokasi:read',
        'datamasterbloklokasi:update',
        'datamasterbloklokasi:delete',
      ],
      MasterBlokLokasiScreen(
        repository: MasterBlokLokasiRepository(api: api),
      ),
    );
    await tester.longPress(find.byKey(const ValueKey('blok-tile-B')));
    await tester.pumpAndSettle();
    expect(find.text('Blok B'), findsOneWidget);
    expect(find.text('Ubah'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Blok'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(api.deleteCalls, 1);
    expect(find.textContaining('berhasil dihapus'), findsOneWidget);
  });
}
