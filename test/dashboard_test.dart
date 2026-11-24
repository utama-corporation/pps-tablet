import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pps_tablet/core/network/api_client.dart';
import 'package:provider/provider.dart';
import 'package:pps_tablet/features/favorit/repository/favorit_repository.dart';
import 'package:pps_tablet/features/favorit/view_model/favorit_view_model.dart';
import 'package:pps_tablet/features/home/dashboard/dashboard_header.dart';
import 'package:pps_tablet/features/home/dashboard/home_dashboard.dart';
import 'package:pps_tablet/features/update/model/update_model.dart';
import 'package:pps_tablet/features/home/repository/dashboard_home_repository.dart';
import 'package:pps_tablet/features/home/view/home_screen.dart';

Map<String, dynamic> _payload({
  bool withProduksi = true,
  bool withPenjualan = true,
  List<Map<String, dynamic>>? activity,
  Object? trend = const [
    {'date': '2026-11-17', 'produksi': 5, 'penjualan': 2},
    {'date': '2026-11-18', 'produksi': 7, 'penjualan': 3},
  ],
}) => {
  'success': true,
  'data': {
    'range_days': 7,
    'from': '2026-11-12',
    'to': '2026-11-18',
    'generated_at': '2026-11-19T01:15:00.000Z',
    'domains': [
      if (withProduksi)
        {
          'key': 'produksi',
          'label': 'Produksi',
          'primary': {
            'label': 'Dokumen produksi',
            'value': 162,
            'unit': 'dokumen',
          },
          'delta': {'value': 100, 'unit': 'pct', 'direction': 'up'},
          'secondary': [
            {'label': 'Hari ini', 'value': 10, 'unit': 'dokumen'},
          ],
          'detail': 'produksi',
          'depts': [
            {'key': 'washing', 'label': 'Washing', 'value': 10, 'today': 1},
            {'key': 'mixer', 'label': 'Mixer', 'value': 30, 'today': 1},
          ],
        },
      if (withPenjualan)
        {
          'key': 'penjualan',
          'label': 'Penjualan',
          'primary': {
            'label': 'Dokumen BJ dikirim',
            'value': 8,
            'unit': 'dokumen',
          },
          'delta': {'value': 100, 'unit': 'pct', 'direction': 'up'},
          'secondary': [
            {'label': 'Hari ini', 'value': 2, 'unit': 'dokumen'},
          ],
          'detail': 'penjualan',
        },
      {
        'key': 'mesin',
        'label': 'Status Mesin',
        'primary': {'label': 'Mesin aktif', 'value': 10, 'unit': 'mesin'},
        'delta': null,
        'secondary': [
          {'label': 'Pending', 'value': 10, 'unit': 'mesin'},
          {'label': 'Idle', 'value': 10, 'unit': 'mesin'},
        ],
        'detail': 'mesin',
      },
    ],
    'trend': trend,
    'trend_error': null,
    'activity':
        activity ??
        [
          {
            'key': 'bongkar_susun',
            'label': 'Bongkar Susun',
            'value': 4,
            'error': null,
          },
          {
            'key': 'sortir_reject',
            'label': 'Sortir Reject',
            'value': 2,
            'error': null,
          },
        ],
  },
};

class FakeApi extends ApiClient {
  Map<String, dynamic> payload = _payload();
  Object? failWith;
  int calls = 0;
  final lastRanges = <String>[];

  /// Bila diisi, jawaban untuk range tsb ditahan sampai completer selesai.
  final hold = <String, Completer<void>>{};

  /// Isi `/api/favorit`.
  List<Map<String, dynamic>> favorites = [];

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    if (path == '/api/favorit') {
      return {'success': true, 'data': favorites};
    }
    calls++;
    final range = '${query?['range']}';
    lastRanges.add(range);
    final gate = hold[range];
    if (gate != null) await gate.future;
    final fail = failWith;
    if (fail != null) throw fail;
    final body = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
    (body['data'] as Map<String, dynamic>)['range_days'] = int.parse(range);
    return body;
  }
}

/// Payload dengan nilai utama kartu Produksi diganti [value].
Map<String, dynamic> _withProduksi(int value) {
  final p = _payload();
  ((p['data']['domains'] as List).first as Map)['primary']['value'] = value;
  return p;
}

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  Future<void> pump(
    WidgetTester tester,
    FakeApi api, {
    Size size = const Size(1280, 800),
    void Function(String route, String title)? onOpenRoute,
    UpdateInfo? update,
    bool withFavorit = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final screen = HomeScreen(
      repository: DashboardHomeRepository(api: api),
      onOpenRoute: onOpenRoute,
      loadUser: () async => const DashUser('Budi Santoso', 'Operator Mixer'),
      checkUpdate: () async => update,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: withFavorit
            ? ChangeNotifierProvider(
                create: (_) => FavoritViewModel(FavoritRepository(api: api)),
                child: screen,
              )
            : screen,
      ),
    );
    await tester.pumpAndSettle();
  }

  UpdateInfo updateInfo({bool force = false}) => UpdateInfo(
    latestVersion: '1.0.300',
    minVersion: '0.0.0',
    forceUpdate: force,
    fileName: 'app.apk',
    sha256: '',
    changelog: '\nPerbaikan dashboard\nLainnya',
  );

  testWidgets('dashboard menampilkan kartu domain, tren, dan aktivitas', (
    tester,
  ) async {
    final api = FakeApi();
    await pump(tester, api);
    expect(find.text('Produksi'), findsWidgets);
    expect(find.text('162'), findsOneWidget);
    expect(find.text('Penjualan'), findsWidgets);
    expect(find.text('Dokumen BJ dikirim'), findsOneWidget);
    expect(find.text('Status Mesin'), findsOneWidget);
    expect(find.text('Bongkar Susun'), findsOneWidget);
    expect(find.text('Sortir Reject'), findsOneWidget);
    expect(find.text('Produksi vs Penjualan'), findsOneWidget);
    expect(find.text('Washing · 10'), findsOneWidget);
    expect(find.text('Mixer · 30'), findsOneWidget);
    expect(api.calls, 1);

    await tester.tap(find.byKey(const Key('range-30')));
    await tester.pumpAndSettle();
    expect(api.lastRanges.last, '30');
    expect(find.byKey(const Key('range-30')), findsOneWidget);
  });

  testWidgets('dashboard error tampil pesan dan muat ulang pulih', (
    tester,
  ) async {
    final api = FakeApi()..failWith = ApiException(500, 'boom');
    await pump(tester, api);
    expect(
      find.text('Ringkasan dashboard belum dapat dimuat.'),
      findsOneWidget,
    );

    api.failWith = null;
    await tester.tap(find.text('Muat ulang'));
    await tester.pumpAndSettle();
    expect(find.text('Produksi'), findsWidgets);
    expect(find.text('Bongkar Susun'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kartu produksi/penjualan tersembunyi tanpa izin dari server', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final api = FakeApi()
      ..payload = _payload(
        withProduksi: false,
        withPenjualan: false,
        trend: null,
      );
    await pump(tester, api);
    expect(find.text('Produksi'), findsNothing);
    expect(find.text('Penjualan'), findsNothing);
    expect(find.text('Status Mesin'), findsOneWidget);
    expect(find.text('Bongkar Susun'), findsOneWidget);
    expect(find.text('Produksi vs Penjualan'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muat di layar sempit', (tester) async {
    final api = FakeApi();
    await pump(tester, api, size: const Size(390, 844));
    expect(find.text('Produksi'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ganti rentang saat masih memuat: data sesuai pilihan terakhir', (
    tester,
  ) async {
    final api = FakeApi();
    await pump(tester, api);
    final slow = Completer<void>();
    api.hold['14'] = slow;
    api.payload = _withProduksi(300);

    await tester.tap(find.byKey(const Key('range-14')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('range-30')));
    await tester.pumpAndSettle();
    expect(find.text('300'), findsOneWidget);
    expect(find.textContaining('dibandingkan 30 hari'), findsOneWidget);

    // Jawaban 14 hari yang telat tidak boleh menimpa data 30 hari.
    api.payload = _withProduksi(999);
    slow.complete();
    await tester.pumpAndSettle();
    expect(find.text('999'), findsNothing);
    expect(find.text('300'), findsOneWidget);
    expect(find.textContaining('dibandingkan 30 hari'), findsOneWidget);
  });

  testWidgets('muat ulang gagal: data lama tetap tampil dengan banner', (
    tester,
  ) async {
    final api = FakeApi();
    await pump(tester, api);
    api.failWith = ApiException(500, 'boom');
    await tester.tap(find.byKey(const Key('range-30')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dash-stale-error')), findsOneWidget);
    expect(find.text('162'), findsOneWidget);
    expect(find.textContaining('Menampilkan data 7 hari'), findsOneWidget);

    api.failWith = null;
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('dash-stale-error')),
        matching: find.text('Coba lagi'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dash-stale-error')), findsNothing);
    expect(find.textContaining('dibandingkan 30 hari'), findsOneWidget);
  });

  testWidgets('kartu domain dan chip departemen membuka route', (tester) async {
    final opened = <String>[];
    await pump(tester, FakeApi(), onOpenRoute: (r, _) => opened.add(r));
    expect(find.byKey(const Key('dash-range-info')), findsOneWidget);
    await tester.tap(find.text('Dokumen BJ dikirim'));
    await tester.tap(find.byKey(const Key('dash-dept-washing')));
    await tester.tap(find.text('Mesin aktif'));
    expect(opened, [
      '/shell/penjualan',
      '/production/washing',
      '/master/mesin-produksi',
    ]);
    expect(find.text('+1 hari ini'), findsNWidgets(2));
  });

  testWidgets('aktivitas tanpa angka tampil "Belum ada data", bukan 0', (
    tester,
  ) async {
    final api = FakeApi()
      ..payload = _payload(
        activity: [
          {'key': 'bongkar_susun', 'label': 'Bongkar Susun', 'value': null},
        ],
      );
    await pump(tester, api);
    expect(find.text('Belum ada data'), findsOneWidget);
    expect(find.text('0 transaksi'), findsNothing);
  });

  testWidgets('sapaan menampilkan nama dan grup pengguna', (tester) async {
    await pump(tester, FakeApi());
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.textContaining('Operator Mixer'), findsOneWidget);
    expect(find.byKey(const Key('dash-updated')), findsOneWidget);
    // Tanpa PermissionViewModel status akun disembunyikan.
    expect(find.byKey(const Key('dash-permissions')), findsNothing);
  });

  testWidgets('favorit tampil dan bisa dibuka; kosong tampil petunjuk', (
    tester,
  ) async {
    final api = FakeApi()
      ..favorites = [
        {'tipe': 'menu', 'kode': '/production/washing', 'urutan': 1},
        {'tipe': 'menu', 'kode': '/tidak/ada', 'urutan': 2},
      ];
    final opened = <String>[];
    await pump(
      tester,
      api,
      withFavorit: true,
      onOpenRoute: (r, _) => opened.add(r),
    );
    expect(find.byKey(const Key('dash-favorites')), findsOneWidget);
    expect(find.text('Belum tersedia di tablet'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('dash-fav-menu:/production/washing')),
    );
    await tester.tap(find.byKey(const Key('dash-fav-menu:/tidak/ada')));
    await tester.tap(find.byKey(const Key('dash-favorites-manage')));
    expect(opened, ['/production/washing', '/shell/favorit']);

    api.favorites = [];
    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dash-favorites-empty')), findsOneWidget);
  });

  testWidgets('tanpa FavoritViewModel kartu favorit tidak tampil', (
    tester,
  ) async {
    await pump(tester, FakeApi());
    expect(find.byKey(const Key('dash-favorites')), findsNothing);
  });

  testWidgets('banner update: bisa ditunda, wajib tidak bisa', (tester) async {
    await pump(tester, FakeApi(), update: updateInfo());
    expect(find.text('Versi 1.0.300 tersedia'), findsOneWidget);
    expect(find.text('Perbaikan dashboard'), findsOneWidget);
    await tester.tap(find.byKey(const Key('dash-update-later')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dash-update-banner')), findsNothing);
  });

  testWidgets('banner update wajib tidak bisa ditunda', (tester) async {
    await pump(tester, FakeApi(), update: updateInfo(force: true));
    expect(find.text('Versi 1.0.300 wajib dipasang'), findsOneWidget);
    expect(find.byKey(const Key('dash-update-later')), findsNothing);
  });

  testWidgets('tanpa versi baru banner update tidak tampil', (tester) async {
    await pump(tester, FakeApi());
    expect(find.byKey(const Key('dash-update-banner')), findsNothing);
  });

  test('dashNiceStep memberi langkah 1/2/5', () {
    expect(dashNiceStep(0.3), 1);
    expect(dashNiceStep(3), 5);
    expect(dashNiceStep(12), 20);
    expect(dashNiceStep(46), 50);
    expect(dashNiceStep(180), 200);
  });
}
