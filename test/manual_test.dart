import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/core/navigation/pps_menu_catalog.dart';
import 'package:pps_tablet/features/manual/manual_content.dart';
import 'package:pps_tablet/features/manual/manual_screen.dart';

Future<List<String>> _pump(
  WidgetTester tester, {
  Size size = const Size(1280, 1400),
  bool Function(String)? canOpen,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ManualScreen(
          onOpenRoute: opened.add,
          canOpenRoute: canOpen ?? (_) => true,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return opened;
}

void main() {
  test('isi manual: id unik, langkah ada, route tujuan ada di katalog', () {
    final ids = <String>{};
    for (final area in ppsManualAreas) {
      expect(area.sections, isNotEmpty, reason: area.key);
      for (final s in area.sections) {
        expect(ids.add(s.id), isTrue, reason: 'id ganda ${s.id}');
        expect(s.steps, isNotEmpty, reason: 'langkah kosong ${s.id}');
        if (s.openRoute != null) {
          expect(
            PpsMenuCatalog.forRoute(s.openRoute),
            isNotNull,
            reason: 'route ${s.openRoute} tidak ada (${s.id})',
          );
          expect(s.openLabel, isNotNull, reason: s.id);
        }
      }
    }
    expect(manualMenuKey, 'workspace.manual');
    expect(PpsMenuCatalog.forRoute('/shell/manual')?.title, 'Manual');
  });

  testWidgets('area pertama terbuka; ganti area dan buka-tutup bagian', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Manual PPS'), findsOneWidget);
    expect(find.text('1. My Work'), findsOneWidget);
    expect(find.text('Pilih kategori'), findsOneWidget);
    expect(find.textContaining('Kategori yang tampil mengikuti'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manual-area-gudang')));
    await tester.pumpAndSettle();
    expect(find.text('1. Penjualan'), findsOneWidget);
    // Bagian kedua tertutup sampai diketuk.
    expect(find.text('Simpan pengiriman'), findsNothing);
    await tester.tap(find.byKey(const Key('manual-toggle-gudang-transfer')));
    await tester.pumpAndSettle();
    expect(find.text('Simpan pengiriman'), findsOneWidget);

    await tester.tap(find.byKey(const Key('manual-area-workspace')));
    await tester.pumpAndSettle();
    expect(find.text('1. My Work'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pencarian lintas area dan pesan kosong', (tester) async {
    await _pump(tester);
    await tester.enterText(
      find.byKey(const Key('manual-search')),
      'stock opname',
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('panduan ditemukan'), findsOneWidget);
    // Hasil dari area lain ikut tampil, lengkap dengan label areanya.
    expect(find.text('Workspace'), findsWidgets);
    expect(find.text('Gudang & Operasional'), findsWidgets);
    expect(find.byKey(const Key('manual-area-workspace')), findsNothing);

    await tester.enterText(find.byKey(const Key('manual-search')), 'zzzz');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual-empty')), findsOneWidget);

    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('manual-area-workspace')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tombol Buka membuka route; disembunyikan bila tanpa akses', (
    tester,
  ) async {
    final opened = await _pump(tester);
    await tester.tap(find.byKey(const Key('manual-open-ws-my-work')));
    expect(opened, ['/shell/my-work']);

    await _pump(tester, canOpen: (_) => false);
    expect(
      find.byKey(const Key('manual-open-ws-my-work')),
      findsNothing,
    );
  });

  testWidgets('muat di layar ponsel', (tester) async {
    await _pump(tester, size: const Size(390, 844));
    await tester.tap(find.byKey(const Key('manual-area-master')));
    await tester.pumpAndSettle();
    expect(find.text('1. Master Data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
