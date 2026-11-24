import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pps_tablet/core/navigation/pps_menu_catalog.dart';
import 'package:pps_tablet/core/services/permission_rules.dart';
import 'package:pps_tablet/core/services/permission_storage.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  bool checker(Set<String> grants, String permission) =>
      PermissionRules.allows(grants, permission);
  List<PpsMenuItem> visible(Set<String> grants) =>
      PpsMenuCatalog.visibleSections((p) => checker(grants, p))
          .expand((s) => s.entries)
          .expand((e) => e is PpsMenuGroup ? e.children : [e as PpsMenuItem])
          // Menu "SEGERA" tampil untuk semua user; yang diuji di sini hanya
          // layar yang benar-benar bisa dibuka.
          .where((e) => !e.comingSoon)
          .toList();

  test(
    'web order is preserved, only actual tablet screens have destinations',
    () {
      final items = PpsMenuCatalog.items.toList();
      expect(items.length, 69);
      expect(items.map((e) => e.id).toSet().length, 69);
      expect(items.where((e) => e.isAvailable).length, 66);
      expect(
        items.where((e) => !e.isAvailable).every((e) => e.comingSoon),
        isTrue,
      );
      expect(PpsMenuCatalog.sections.map((s) => s.title).toList(), [
        'Workspace & Analytics',
        'Label',
        'Bahan Pendukung',
        'Proses Produksi',
        'Operasional',
        'SPK',
        'Monitoring',
        'Master',
        'System',
      ]);
      final labels = (PpsMenuCatalog.sections[1].entries.single as PpsMenuGroup)
          .children
          .map((e) => e.title)
          .toList();
      expect(labels, [
        'Bahan Baku',
        'Washing',
        'Bonggolan',
        'Broker',
        'Crusher',
        'Furniture WIP',
        'Gilingan',
        'Mixer',
        'Packing',
        'Reject',
        'Bahan Pendukung',
        'Barang Dagang',
      ]);
    },
  );
  test('empty grants fail closed and hide empty groups and sections', () {
    expect(visible({}).map((e) => e.title), ['My Work', 'Dashboards', 'Manual']);
    expect(PpsMenuCatalog.visibleSections((_) => false).length, 1);
  });
  test(
    'washing operator sees only their label, process and backend-authorized history',
    () {
      expect(
        visible({
          'label_washing:read',
          'produksi_washing:read',
        }).map((e) => e.title),
        [
          'My Work',
          'Dashboards',
          'Audit Timeline',
          'KPI & Ratio',
          'Manual',
          'Washing',
          'Proses Washing',
        ],
      );
    },
  );
  test('mixer and warehouse access remain isolated', () {
    expect(visible({'produksi_mixer:read'}).map((e) => e.title), [
      'My Work', 'Dashboards',
      'KPI & Ratio',
      'Manual',
      'Proses Mixer',
    ]);
    expect(visible({'goods_transfer:read'}).map((e) => e.title), [
      'My Work', 'Dashboards',
      'Manual',
      'Good Transfer',
      'In Transit',
    ]);
    expect(
      visible({'good_transfer:read'}).map((e) => e.title),
      ['My Work', 'Dashboards', 'Manual'],
      reason:
          'legacy spelling must not imply a permission rejected by the current API',
    );
  });
  test('cetakan reader sees master cetakan with its tablet route', () {
    final items = visible({'datamastercetakan:read'});
    final cetakan = items.firstWhere((e) => e.id == '/master/cetakan');
    expect(items.map((e) => e.title), [
      'My Work', 'Dashboards', 'Manual', 'Master Cetakan',
    ]);
    expect(cetakan.isAvailable, isTrue);
    expect(cetakan.route, '/master/cetakan');
  });
  test('formula reader sees master formula with its tablet route', () {
    final items = visible({'masterformulaproduksi:read'});
    final formula = items.firstWhere((e) => e.id == '/master/formula');
    expect(items.map((e) => e.title), [
      'My Work', 'Dashboards', 'Manual', 'Master Formula',
    ]);
    expect(formula.isAvailable, isTrue);
    expect(formula.route, '/master/formula');
  });
  test('blok-lokasi reader sees blok & lokasi with its tablet route', () {
    final items = visible({'datamasterbloklokasi:read'});
    final blok = items.firstWhere((e) => e.id == '/master/blok-lokasi');
    expect(items.map((e) => e.title), [
      'My Work', 'Dashboards', 'Manual', 'Blok & Lokasi',
    ]);
    expect(blok.isAvailable, isTrue);
    expect(blok.route, '/master/blok-lokasi');
  });
  test('label bahan baku and receiving have separate backend permissions', () {
    expect(visible({'label_bahanbaku:read'}).map((e) => e.title), [
      'My Work', 'Dashboards', 'Manual',
      'Bahan Baku',
    ]);
    expect(visible({'penerimaanbahanbaku:read'}).map((e) => e.title), [
      'My Work', 'Dashboards', 'Manual',
      'Penerimaan Bahan Baku',
      'Stock',
    ]);
  });
  test(
    'create permission does not imply read and module wildcards are unsupported',
    () {
      expect(
        visible({
          'produksi_mixer:create',
          'datamasteruser:update',
          'label_broker:*',
        }).map((e) => e.title),
        ['My Work', 'Dashboards', 'Manual'],
      );
      expect(PermissionRules.allows({'*'}, ''), isFalse);
    },
  );
  test('global super-admin wildcard follows backend semantics', () {
    expect(visible({'*'}).length, 66);
    expect(PermissionRules.allows({'*'}, 'label_broker:read'), isTrue);
  });
  test('workspace & analytics follows the requested order', () {
    final workspace = PpsMenuCatalog.sections.first;
    expect(workspace.entries.map((e) => e.title).toList(), [
      'My Work',
      'Scheduler',
      'Dashboards',
      'Governance',
      'Reports',
      'KPI & Ratio',
      'Manual',
    ]);
    final soon = PpsMenuCatalog.items.where((e) => e.comingSoon);
    expect(soon.map((e) => e.title).toList(), [
      'Scheduler',
      'Approval Queue',
      'NCR & Corrective Action',
    ]);
    final manual = PpsMenuCatalog.forRoute('/shell/manual');
    expect(manual?.title, 'Manual');
    expect(manual?.isAvailable, isTrue);
    expect(PpsMenuCatalog.canOpenRoute('/shell/manual', (_) => false), isTrue);
    expect(PpsMenuCatalog.forRoute('/shell/kpi')?.title, 'KPI & Ratio');
    expect(
      PpsMenuCatalog.canOpenRoute('/shell/kpi', (p) => p == 'laporan:read'),
      isTrue,
    );
    expect(PpsMenuCatalog.canOpenRoute('/shell/kpi', (_) => false), isFalse);
    expect(soon.every((e) => !e.isAvailable && e.permissions.isEmpty), isTrue);
    expect(
      PpsMenuCatalog.forRoute('/shell/history')?.title,
      'Audit Timeline',
    );
    final myWork = PpsMenuCatalog.forRoute('/shell/my-work');
    expect(myWork?.title, 'My Work');
    expect(PpsMenuCatalog.canOpenRoute('/shell/my-work', (_) => false), isTrue);
  });
  test('route policy also guards legacy production aliases', () {
    bool noAccess(String p) => false;
    bool mixerOnly(String p) => p == 'produksi_mixer:read';
    expect(PpsMenuCatalog.canOpenRoute('/production/mixer', noAccess), isFalse);
    expect(PpsMenuCatalog.canOpenRoute('/production/mixer', mixerOnly), isTrue);
    expect(
      PpsMenuCatalog.canOpenRoute('/production/inject', mixerOnly),
      isFalse,
    );
    expect(
      PpsMenuCatalog.canOpenRoute(
        '/production/return',
        (p) => p == 'retur:read',
      ),
      isFalse,
    );
    expect(
      PpsMenuCatalog.canOpenRoute(
        '/production/return',
        (p) => p == 'retur_old:read',
      ),
      isTrue,
    );
    expect(PpsMenuCatalog.forRoute('/shell/retur-v2')?.title, 'Retur (Old)');
    expect(PpsMenuCatalog.canOpenRoute('/shell/welcome', noAccess), isTrue);
  });
  test(
    'refresh replaces role grants, permissions cannot be mutated externally',
    () async {
      SharedPreferences.setMockInitialValues({
        'permissions': ['produksi_mixer:read'],
      });
      final vm = PermissionViewModel();
      await vm.loadPermissions();
      expect(vm.can('produksi_mixer:read'), isTrue);
      expect(() => vm.permissions.add('*'), throwsUnsupportedError);
      await PermissionStorage.savePermissions(['goods_transfer:read']);
      await vm.loadPermissions();
      expect(vm.can('produksi_mixer:read'), isFalse);
      expect(vm.can('goods_transfer:read'), isTrue);
      await PermissionStorage.savePermissions(['*']);
      await vm.loadPermissions();
      expect(vm.can('label_broker:delete'), isTrue);
      expect(
        await PermissionStorage.hasPermission('label_broker:delete'),
        isTrue,
      );
      vm.clear();
      expect(vm.can('label_broker:delete'), isFalse);
      vm.dispose();
    },
  );
}
