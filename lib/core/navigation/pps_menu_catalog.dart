import 'package:flutter/material.dart';

typedef MenuPermissionCheck = bool Function(String permission);

sealed class PpsMenuEntry {
  const PpsMenuEntry({required this.title, required this.icon});
  final String title;
  final IconData icon;
}

class PpsMenuItem extends PpsMenuEntry {
  const PpsMenuItem({
    required this.id,
    required super.title,
    required super.icon,
    required this.webPath,
    required this.permissions,
    this.route,
    this.aliases = const [],
  });
  final String id;
  final String webPath;
  final String? route;
  final List<String> permissions;
  final List<String> aliases;
  bool get isAvailable => route != null;
  bool canView(MenuPermissionCheck can) =>
      permissions.isEmpty || permissions.any(can);
  bool matchesRoute(String? name) =>
      name != null && (route == name || aliases.contains(name));
}

class PpsMenuGroup extends PpsMenuEntry {
  const PpsMenuGroup({
    required super.title,
    required super.icon,
    required this.children,
  });
  final List<PpsMenuItem> children;
}

class PpsMenuSection {
  const PpsMenuSection({required this.title, required this.entries});
  final String? title;
  final List<PpsMenuEntry> entries;
}

/// Web menu order audited on 2026-11-09. Read permissions come from PPS
/// MstPermissionList and backend route guards, never role names or group IDs.
/// Trade-In has no dedicated read key: use the existing return-reader roles.
/// SPK uses the existing planning-reader role; its backend currently checks token only.
/// Stock uses the read key required by the current master-stock endpoints.
/// History uses label_washing:read as required by the current audit endpoints.
abstract final class PpsMenuCatalog {
  static const List<PpsMenuSection> sections = [
     PpsMenuSection(
       title: null,
       entries: [
         PpsMenuItem(
           id: "/",
           title: "Dashboard",
           icon: Icons.dashboard_outlined,
           webPath: "/",
           route: "/shell/welcome",
           permissions: [],
         ),
         PpsMenuItem(
           id: "/favorit",
           title: "Favorit",
           icon: Icons.star_rounded,
           webPath: "/favorit",
           route: "/shell/favorit",
           permissions: [],
         ),
       ],
     ),
    PpsMenuSection(
      title: "Label",
      entries: [
        PpsMenuGroup(
          title: 'Label',
          icon: Icons.label_outlined,
          children: [
            PpsMenuItem(
              id: "/label/bahan-baku",
              title: "Bahan Baku",
              icon: Icons.inventory_2_outlined,
              webPath: "/label/bahan-baku",
              route: "/label/bahan-baku",
              permissions: ["label_bahanbaku:read"],
            ),
            PpsMenuItem(
              id: "/label/washing",
              title: "Washing",
              icon: Icons.local_laundry_service_outlined,
              webPath: "/label/washing",
              route: "/label/washing",
              permissions: ["label_washing:read"],
            ),
            PpsMenuItem(
              id: "/label/bonggolan",
              title: "Bonggolan",
              icon: Icons.category_outlined,
              webPath: "/label/bonggolan",
              route: "/label/bonggolan",
              permissions: ["label_bonggolan:read"],
            ),
            PpsMenuItem(
              id: "/label/broker",
              title: "Broker",
              icon: Icons.handshake_outlined,
              webPath: "/label/broker",
              route: "/label/broker",
              permissions: ["label_broker:read"],
            ),
            PpsMenuItem(
              id: "/label/crusher",
              title: "Crusher",
              icon: Icons.construction_outlined,
              webPath: "/label/crusher",
              route: "/label/crusher",
              permissions: ["label_crusher:read"],
            ),
            PpsMenuItem(
              id: "/label/furniture-wip",
              title: "Furniture WIP",
              icon: Icons.chair_outlined,
              webPath: "/label/furniture-wip",
              route: "/label/furniture_wip",
              permissions: ["label_furniturewip:read"],
            ),
            PpsMenuItem(
              id: "/label/gilingan",
              title: "Gilingan",
              icon: Icons.settings_outlined,
              webPath: "/label/gilingan",
              route: "/label/gilingan",
              permissions: ["label_gilingan:read"],
            ),
            PpsMenuItem(
              id: "/label/mixer",
              title: "Mixer",
              icon: Icons.blender_outlined,
              webPath: "/label/mixer",
              route: "/label/mixer",
              permissions: ["label_mixer:read"],
            ),
            PpsMenuItem(
              id: "/label/packing",
              title: "Packing",
              icon: Icons.inventory_outlined,
              webPath: "/label/packing",
              route: "/label/packing",
              permissions: ["label_barangjadi:read"],
            ),
            PpsMenuItem(
              id: "/label/reject",
              title: "Reject",
              icon: Icons.cancel_outlined,
              webPath: "/label/reject",
              route: "/label/reject",
              permissions: ["label_reject:read"],
            ),
            PpsMenuItem(
              id: "label.bahan-pendukung",
              title: "Bahan Pendukung",
              icon: Icons.science_outlined,
              webPath: "#",
              route: "/label/bahan-pendukung",
              permissions: ["label_bahanpendukung:read"],
            ),
            PpsMenuItem(
              id: "/label/barang-dagang",
              title: "Barang Dagang",
              icon: Icons.shopping_bag_outlined,
              webPath: "/label/barang-dagang",
              route: "/label/barang-dagang",
              permissions: ["label_barangdagang:read"],
            ),
          ],
        ),
      ],
    ),
    PpsMenuSection(
      title: "Bahan Pendukung",
      entries: [
        PpsMenuItem(
          id: "/bahan-pendukung/penerimaan",
          title: "Penerimaan Bahan Pendukung",
          icon: Icons.move_to_inbox_outlined,
          webPath: "/bahan-pendukung/penerimaan",
          route: "/shell/penerimaan-bahan-pendukung",
          permissions: ["label_bahanpendukung:read"],
        ),
      ],
    ),
    PpsMenuSection(
      title: "Proses Produksi",
      entries: [
        PpsMenuGroup(
          title: "Washing & Broker",
          icon: Icons.water_outlined,
          children: [
            PpsMenuItem(
              id: "/production/penerimaan-bahan-baku",
              title: "Penerimaan Bahan Baku",
              icon: Icons.move_to_inbox_outlined,
              webPath: "/production/penerimaan-bahan-baku",
              route: "/shell/penerimaan-bahan-baku",
              permissions: ["penerimaanbahanbaku:read"],
            ),
            PpsMenuItem(
              id: "/production/washing",
              title: "Proses Washing",
              icon: Icons.local_laundry_service_outlined,
              webPath: "/production/washing",
              route: "/production/washing",
              permissions: ["produksi_washing:read"],
            ),
            PpsMenuItem(
              id: "/production/broker",
              title: "Proses Broker",
              icon: Icons.handshake_outlined,
              webPath: "/production/broker",
              route: "/production/broker",
              permissions: ["produksi_broker:read"],
            ),
            PpsMenuItem(
              id: "/production/crusher",
              title: "Proses Crusher",
              icon: Icons.construction_outlined,
              webPath: "/production/crusher",
              route: "/production/crusher",
              permissions: ["produksi_crusher:read"],
            ),
          ],
        ),
        PpsMenuGroup(
          title: "Pin Hulu",
          icon: Icons.precision_manufacturing_outlined,
          children: [
            PpsMenuItem(
              id: "/production/mixer",
              title: "Proses Mixer",
              icon: Icons.blender_outlined,
              webPath: "/production/mixer",
              route: "/production/mixer",
              permissions: ["produksi_mixer:read"],
            ),
            PpsMenuItem(
              id: "/production/inject",
              title: "Proses Inject",
              icon: Icons.invert_colors_outlined,
              webPath: "/production/inject",
              route: "/shell/inject",
              permissions: ["injectproduksi:read"],
              aliases: ["/production/inject"],
            ),
            PpsMenuItem(
              id: "/production/gilingan",
              title: "Proses Gilingan",
              icon: Icons.settings_outlined,
              webPath: "/production/gilingan",
              route: "/production/gilingan",
              permissions: ["produksi_gilingan:read"],
            ),
          ],
        ),
        PpsMenuGroup(
          title: "Pin Hilir",
          icon: Icons.account_tree_outlined,
          children: [
            PpsMenuItem(
              id: "/production/stamping",
              title: "Proses Stamping",
              icon: Icons.local_fire_department_outlined,
              webPath: "/production/stamping",
              route: "/shell/hot-stamp",
              permissions: ["hotstamping:read"],
              aliases: ["/production/hot-stamp"],
            ),
            PpsMenuItem(
              id: "/production/pasang-kunci",
              title: "Proses Pasang Kunci",
              icon: Icons.key_outlined,
              webPath: "/production/pasang-kunci",
              route: "/shell/key-fitting",
              permissions: ["pasangkunci:read"],
              aliases: ["/production/key-fitting"],
            ),
            PpsMenuItem(
              id: "/production/spanner",
              title: "Packing Spanner",
              icon: Icons.hardware_outlined,
              webPath: "/production/spanner",
              route: "/shell/spanner",
              permissions: ["spanner:read"],
              aliases: ["/production/spanner"],
            ),
            PpsMenuItem(
              id: "/production/packing",
              title: "Packing",
              icon: Icons.inventory_outlined,
              webPath: "/production/packing",
              route: "/shell/packing",
              permissions: ["packing:read"],
              aliases: ["/production/packing"],
            ),
          ],
        ),
        PpsMenuGroup(
          title: "Warehouse",
          icon: Icons.warehouse_outlined,
          children: [
            PpsMenuItem(
              id: "/warehouse/penjualan",
              title: "Penjualan",
              icon: Icons.point_of_sale_outlined,
              webPath: "/warehouse/penjualan",
              route: "/shell/penjualan",
              permissions: ["penjualan:read"],
            ),
            PpsMenuItem(
              id: "/warehouse/good-transfer",
              title: "Good Transfer",
              icon: Icons.local_shipping_outlined,
              webPath: "/warehouse/good-transfer",
              route: "/shell/goods-transfer",
              permissions: ["goods_transfer:read"],
            ),
            PpsMenuItem(
              id: "/warehouse/in-transit",
              title: "In Transit",
              icon: Icons.move_to_inbox_outlined,
              webPath: "/warehouse/in-transit",
              route: "/shell/in-transit",
              permissions: ["goods_transfer:read"],
            ),
            PpsMenuItem(
              id: "/warehouse/retur-v3",
              title: "Retur v3",
              icon: Icons.assignment_return_rounded,
              webPath: "/warehouse/retur-v3",
              route: "/shell/retur-v3",
              permissions: ["retur:read"],
            ),
            PpsMenuItem(
              id: "/warehouse/retur-old",
              title: "Retur (Old)",
              icon: Icons.assignment_return_outlined,
              webPath: "/warehouse/retur-old",
              route: "/shell/retur-v2",
              permissions: ["retur_old:read"],
              aliases: ["/shell/return", "/production/return"],
            ),
            PpsMenuItem(
              id: "/warehouse/trade-in",
              title: "Penerimaan Trade In",
              icon: Icons.swap_horiz_outlined,
              webPath: "/warehouse/trade-in",
              route: "/shell/trade-in",
              permissions: ["retur:read", "barangjadiretur:read"],
            ),
            PpsMenuItem(
              id: "/warehouse/penerimaan-barang-dagang",
              title: "Penerimaan Barang Dagang",
              icon: Icons.move_to_inbox_outlined,
              webPath: "/warehouse/penerimaan-barang-dagang",
              route: "/shell/penerimaan-barang-dagang",
              permissions: ["label_barangdagang:read"],
            ),
          ],
        ),
      ],
    ),
    PpsMenuSection(
      title: "Operasional",
      entries: [
        PpsMenuItem(
          id: "/operasional/stock",
          title: "Stock",
          icon: Icons.assessment_outlined,
          webPath: "/operasional/stock",
          route: "/shell/stock",
          permissions: ["penerimaanbahanbaku:read"],
        ),
        PpsMenuItem(
          id: "/operasional/bongkar-susun",
          title: "Bongkar Susun",
          icon: Icons.layers_outlined,
          webPath: "/operasional/bongkar-susun",
          route: "/shell/bongkar-susun",
          permissions: ["bongkarsusun:read"],
        ),
        PpsMenuItem(
          id: "/operasional/sortir-reject",
          title: "Sortir Reject",
          icon: Icons.filter_alt_outlined,
          webPath: "/operasional/sortir-reject",
          route: "/shell/sortir-reject",
          permissions: ["barangjadisortirreject:read"],
          aliases: ["/production/sortir-reject"],
        ),
        PpsMenuItem(
          id: "/operasional/stock-opname",
          title: "Stock Opname",
          icon: Icons.fact_check_outlined,
          webPath: "/operasional/stock-opname",
          route: "/shell/stock-opname-v2",
          permissions: ["stockopname:read"],
        ),
        PpsMenuItem(
          id: "/operasional/stock-opname-old",
          title: "Stock Opname (Old)",
          icon: Icons.fact_check_outlined,
          webPath: "/operasional/stock-opname-old",
          route: "/stockopname",
          permissions: ["stockopname:read"],
        ),
      ],
    ),
    PpsMenuSection(
      title: "SPK",
      entries: [
        PpsMenuItem(
          id: "/production/spk-barang-jadi",
          title: "SPK Produksi Barang Jadi",
          icon: Icons.assignment_outlined,
          webPath: "/production/spk-barang-jadi",
          route: "/production/spk-barang-jadi",
          permissions: ["datamasterplanning:read"],
        ),
      ],
    ),
    PpsMenuSection(
      title: "Laporan & Monitoring",
      entries: [
     PpsMenuGroup(
       title: "Laporan",
       icon: Icons.bar_chart_outlined,
       children: [
         PpsMenuItem(
           id: "/laporan/bahan-baku",
           title: "Bahan Baku",
           icon: Icons.warehouse_outlined,
           webPath: "/laporan",
           route: "/laporan/bahan-baku",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/washing",
           title: "Washing",
           icon: Icons.local_laundry_service_outlined,
           webPath: "/laporan",
           route: "/laporan/washing",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/broker",
           title: "Broker",
           icon: Icons.storefront_outlined,
           webPath: "/laporan",
           route: "/laporan/broker",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/bonggolan",
           title: "Bonggolan",
           icon: Icons.recycling_outlined,
           webPath: "/laporan",
           route: "/laporan/bonggolan",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/crusher",
           title: "Crusher",
           icon: Icons.hardware_outlined,
           webPath: "/laporan",
           route: "/laporan/crusher",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/gilingan",
           title: "Gilingan",
           icon: Icons.grass_outlined,
           webPath: "/laporan",
           route: "/laporan/gilingan",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/mixer",
           title: "Mixer",
           icon: Icons.blender_outlined,
           webPath: "/laporan",
           route: "/laporan/mixer",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/reject",
           title: "Reject",
           icon: Icons.remove_circle_outline_rounded,
           webPath: "/laporan",
           route: "/laporan/reject",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/furniture-wip",
           title: "Furniture WIP",
           icon: Icons.chair_outlined,
           webPath: "/laporan",
           route: "/laporan/furniture-wip",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/barang-jadi",
           title: "Barang Jadi",
           icon: Icons.inventory_2_outlined,
           webPath: "/laporan",
           route: "/laporan/barang-jadi",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/barang-dagang",
           title: "Barang Dagang",
           icon: Icons.local_shipping_outlined,
           webPath: "/laporan",
           route: "/laporan/barang-dagang",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/rekap-produksi",
           title: "Rekap Produksi",
           icon: Icons.summarize_outlined,
           webPath: "/laporan",
           route: "/laporan/rekap-produksi",
           permissions: ["laporan:read"],
         ),
         PpsMenuItem(
           id: "/laporan/semua",
           title: "Semua Laporan",
           icon: Icons.apps_rounded,
           webPath: "/laporan",
           route: "/laporan/semua",
           permissions: ["laporan:read"],
         ),
       ],
     ),
        PpsMenuItem(
          id: "laporan-monitoring.history",
          title: "History",
          icon: Icons.history,
          webPath: "#",
          route: "/shell/history",
          permissions: ["label_washing:read"],
        ),
        PpsMenuItem(
          id: "/mapping",
          title: "Mapping",
          icon: Icons.map_outlined,
          webPath: "/mapping",
          route: "/shell/mapping",
          permissions: ["mappinglokasi:read"],
        ),
      ],
    ),
    PpsMenuSection(
      title: "Master",
      entries: [
        PpsMenuGroup(
          title: "SDM & Produksi",
          icon: Icons.engineering_outlined,
          children: [
            PpsMenuItem(
              id: "/master/operator-regu",
              title: "Master Operator & Regu",
              icon: Icons.groups_outlined,
              webPath: "/master/operator-regu",
              route: "/master/operator-regu",
              permissions: ["datamasteroperator:read"],
            ),
            PpsMenuItem(
              id: "/master/mesin-produksi",
              title: "Master Mesin Produksi",
              icon: Icons.precision_manufacturing_outlined,
              webPath: "/master/mesin-produksi",
              route: "/master/mesin-produksi",
              permissions: ["datamastermesin:read"],
            ),
            PpsMenuItem(
              id: "/master/barang",
              title: "Master Barang",
              icon: Icons.inventory_2_outlined,
              webPath: "/master/barang",
              route: "/master/barang",
              permissions: ["datamasterbarang:read"],
            ),
            PpsMenuItem(
              id: "/master/supplier",
              title: "Master Supplier",
              icon: Icons.local_shipping_outlined,
              webPath: "/master/supplier",
              route: "/master/supplier",
              permissions: ["datamastersupplier:read"],
            ),
             PpsMenuItem(
               id: "/master/cetakan",
               title: "Master Cetakan",
               icon: Icons.widgets_outlined,
               webPath: "/master/cetakan",
               route: "/master/cetakan",
               permissions: ["datamastercetakan:read"],
             ),
             PpsMenuItem(
               id: "/master/formula",
               title: "Master Formula",
               icon: Icons.science_outlined,
               webPath: "/master/formula",
               route: "/master/formula",
               permissions: ["masterformulaproduksi:read"],
             ),
             PpsMenuItem(
               id: "/master/blok-lokasi",
               title: "Blok & Lokasi",
               icon: Icons.location_on_outlined,
               webPath: "/master/blok-lokasi",
               route: "/master/blok-lokasi",
               permissions: ["datamasterbloklokasi:read"],
             ),
          ],
        ),
      ],
    ),
    PpsMenuSection(
      title: "System",
      entries: [
        PpsMenuItem(
          id: "/user",
          title: "User",
          icon: Icons.person_outline,
          webPath: "/user",
          route: "/shell/user",
          permissions: ["datamasteruser:read"],
        ),
        PpsMenuItem(
          id: "/master/permission-group",
          title: "Role",
          icon: Icons.admin_panel_settings_outlined,
          webPath: "/master/permission-group",
          route: "/shell/role",
          permissions: ["datamasterpermissiongroup:read"],
        ),
      ],
    ),
  ];

  static Iterable<PpsMenuItem> get items sync* {
    for (final section in sections) {
      for (final entry in section.entries) {
        if (entry is PpsMenuItem) yield entry;
        if (entry is PpsMenuGroup) yield* entry.children;
      }
    }
  }

  static List<PpsMenuSection> visibleSections(MenuPermissionCheck can) {
    final result = <PpsMenuSection>[];
    for (final section in sections) {
      final entries = <PpsMenuEntry>[];
      for (final entry in section.entries) {
        if (entry is PpsMenuItem && entry.canView(can)) entries.add(entry);
        if (entry is PpsMenuGroup) {
          final children = entry.children
              .where((item) => item.canView(can))
              .toList();
          if (children.isNotEmpty) {
            entries.add(
              PpsMenuGroup(
                title: entry.title,
                icon: entry.icon,
                children: children,
              ),
            );
          }
        }
      }
      if (entries.isNotEmpty) {
        result.add(PpsMenuSection(title: section.title, entries: entries));
      }
    }
    return result;
  }

  static PpsMenuItem? forRoute(String? route) {
    for (final item in items) {
      if (item.matchesRoute(route)) return item;
    }
    return null;
  }

  // Non-menu routes keep their existing screen-level behavior. Menu targets
  // and their legacy aliases use the same policy as sidebar visibility.
  static bool canOpenRoute(String? route, MenuPermissionCheck can) {
    final item = forRoute(route);
    return item == null || (item.isAvailable && item.canView(can));
  }
}
