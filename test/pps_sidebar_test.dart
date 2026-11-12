import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pps_tablet/core/services/permission_storage.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/home/view/widgets/home_sidebar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const previewFontDir = String.fromEnvironment('SIDEBAR_TEST_FONT_DIR');
  setUpAll(() async {
    if (previewFontDir.isEmpty) return;
    final roboto = FontLoader('Roboto');
    for (final name in [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]) {
      roboto.addFont(
        File('$previewFontDir/$name').readAsBytes().then(ByteData.sublistView),
      );
    }
    await roboto.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  Future<PermissionViewModel> setup(
    WidgetTester tester,
    List<String> permissions, {
    bool initiallyCollapsed = false,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'permissions': permissions});
    final vm = PermissionViewModel();
    await vm.loadPermissions();
    addTearDown(vm.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();
    var collapsed = initiallyCollapsed;
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(
          theme: ThemeData(
            fontFamily: previewFontDir.isEmpty ? null : 'Roboto',
          ),
          home: StatefulBuilder(
            builder: (context, setState) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: Row(
                  children: [
                    RepaintBoundary(
                      key: const ValueKey('sidebar-capture'),
                      child: HomeSidebar(
                        navigatorKey: navigatorKey,
                        isCollapsed: collapsed,
                        onToggleCollapse: () =>
                            setState(() => collapsed = !collapsed),
                        onNavigate: (title, {parentTitle}) {},
                      ),
                    ),
                    Expanded(
                      child: Navigator(
                        key: navigatorKey,
                        onGenerateRoute: (settings) => MaterialPageRoute(
                          settings: settings,
                          builder: (_) =>
                              Center(child: Text(settings.name ?? '/')),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        const AssetImage('assets/images/icon_without_bg.png'),
        tester.element(find.byType(HomeSidebar)),
      ),
    );
    await tester.pumpAndSettle();
    return vm;
  }

  Future<void> capture(WidgetTester tester, String name) async {
    const dir = String.fromEnvironment('SIDEBAR_SCREENSHOT_DIR');
    if (dir.isEmpty) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('sidebar-capture')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$dir/$name.png').writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'operator sidebar hides other roles and opens the permitted process',
    (tester) async {
      await setup(tester, ['produksi_mixer:read']);
      expect(find.text('Label'), findsNothing);
      expect(find.text('Warehouse'), findsNothing);
      expect(find.text('MASTER'), findsNothing);
      await tester.tap(find.text('Pin Hulu'));
      await tester.pumpAndSettle();
      expect(find.text('Proses Mixer'), findsOneWidget);
      expect(find.text('Proses Inject'), findsNothing);
      await capture(tester, 'pps-sidebar-operator');
      await tester.tap(find.text('Proses Mixer'));
      await tester.pumpAndSettle();
      expect(find.text('/production/mixer'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'authorized master opens its tablet screen',
    (tester) async {
      await setup(tester, ['datamastercetakan:read'], textScale: 1.3);
      await tester.tap(find.text('SDM & Produksi'));
      await tester.pumpAndSettle();
      expect(find.text('Master Cetakan'), findsOneWidget);
      expect(find.text('Master Barang'), findsNothing);
      expect(find.text('Belum tersedia di tablet'), findsNothing);
      await tester.tap(find.text('Master Cetakan'));
      await tester.pumpAndSettle();
      expect(find.text('/master/cetakan'), findsOneWidget);
      await capture(tester, 'pps-sidebar-master');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'role refresh removes prior group and exposes only the new role',
    (tester) async {
      final vm = await setup(tester, ['produksi_mixer:read']);
      expect(find.text('Pin Hulu'), findsOneWidget);
      await PermissionStorage.savePermissions(['goods_transfer:read']);
      await vm.loadPermissions();
      await tester.pumpAndSettle();
      expect(find.text('Pin Hulu'), findsNothing);
      expect(find.text('Warehouse'), findsOneWidget);
      await tester.tap(find.text('Warehouse'));
      await tester.pumpAndSettle();
      expect(find.text('Good Transfer'), findsOneWidget);
      expect(find.text('In Transit'), findsOneWidget);
      expect(find.text('Retur v3'), findsNothing);
    },
  );

  testWidgets(
    'collapsed group expands without layout errors and keeps role filtering',
    (tester) async {
      await setup(tester, ['produksi_mixer:read'], initiallyCollapsed: true);
      await capture(tester, 'pps-sidebar-collapsed');
      await tester.tap(find.byKey(const ValueKey('menu-group-Pin Hulu')));
      await tester.pumpAndSettle();
      expect(find.text('Proses Mixer'), findsOneWidget);
      expect(find.text('Proses Inject'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'admin label order matches web and unavailable labels stay disabled',
    (tester) async {
      await setup(tester, ['*']);
      await tester.tap(find.text('Label'));
      await tester.pumpAndSettle();
      final positions = [
        'Bonggolan',
        'Broker',
        'Crusher',
        'Furniture WIP',
        'Gilingan',
        'Mixer',
      ].map((name) => tester.getTopLeft(find.text(name)).dy).toList();
      expect(positions, orderedEquals(positions.toList()..sort()));
      await capture(tester, 'pps-sidebar-admin-label');
      expect(tester.takeException(), isNull);
    },
  );
}
