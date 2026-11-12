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
          .toList();

  test(
    'web order is preserved, only actual tablet screens have destinations',
    () {
      final items = PpsMenuCatalog.items.toList();
      expect(items.length, 63);
      expect(items.map((e) => e.id).toSet().length, 63);
      expect(items.where((e) => e.isAvailable).length, 63);
      expect(items.where((e) => !e.isAvailable).length, 0);
      expect(PpsMenuCatalog.sections.map((s) => s.title).toList(), [
        null,
        'Label',
        'Bahan Pendukung',
        'Proses Produksi',
        'Operasional',
        'SPK',
        'Laporan & Monitoring',
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
    expect(visible({}).map((e) => e.title), ['Dashboard', 'Favorit']);
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
        ['Dashboard', 'Favorit', 'Washing', 'Proses Washing', 'History'],
      );
    },
  );
  test('mixer and warehouse access remain isolated', () {
    expect(visible({'produksi_mixer:read'}).map((e) => e.title), [
      'Dashboard',
      'Favorit',
      'Proses Mixer',
    ]);
    expect(visible({'goods_transfer:read'}).map((e) => e.title), [
      'Dashboard',
      'Favorit',
      'Good Transfer',
      'In Transit',
    ]);
    expect(
      visible({'good_transfer:read'}).map((e) => e.title),
      ['Dashboard', 'Favorit'],
      reason:
          'legacy spelling must not imply a permission rejected by the current API',
    );
  });
  test('cetakan reader sees master cetakan with its tablet route', () {
    final items = visible({'datamastercetakan:read'});
    expect(items.map((e) => e.title), ['Dashboard', 'Favorit', 'Master Cetakan']);
    expect(items.last.isAvailable, isTrue);
    expect(items.last.route, '/master/cetakan');
  });
  test('formula reader sees master formula with its tablet route', () {
    final items = visible({'masterformulaproduksi:read'});
    expect(items.map((e) => e.title), ['Dashboard', 'Favorit', 'Master Formula']);
    expect(items.last.isAvailable, isTrue);
    expect(items.last.route, '/master/formula');
  });
  test('blok-lokasi reader sees blok & lokasi with its tablet route', () {
    final items = visible({'datamasterbloklokasi:read'});
    expect(items.map((e) => e.title), ['Dashboard', 'Favorit', 'Blok & Lokasi']);
    expect(items.last.isAvailable, isTrue);
    expect(items.last.route, '/master/blok-lokasi');
  });
  test('label bahan baku and receiving have separate backend permissions', () {
    expect(visible({'label_bahanbaku:read'}).map((e) => e.title), [
      'Dashboard',
      'Favorit',
      'Bahan Baku',
    ]);
    expect(visible({'penerimaanbahanbaku:read'}).map((e) => e.title), [
      'Dashboard',
      'Favorit',
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
        ['Dashboard', 'Favorit'],
      );
      expect(PermissionRules.allows({'*'}, ''), isFalse);
    },
  );
  test('global super-admin wildcard follows backend semantics', () {
    expect(visible({'*'}).length, 63);
    expect(PermissionRules.allows({'*'}, 'label_broker:read'), isTrue);
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
