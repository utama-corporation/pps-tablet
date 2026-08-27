import 'package:flutter/material.dart';

class HomeSidebar extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final void Function(String title, {String? parentTitle}) onNavigate;

  const HomeSidebar({
    super.key,
    required this.navigatorKey,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onNavigate,
  });

  @override
  State<HomeSidebar> createState() => _HomeSidebarState();
}

class _HomeSidebarState extends State<HomeSidebar> {
  String? _selectedRoute;
  String? _expandedGroup;

  static const Color _primaryColor = Color(0xFF0D47A1);
  static const String _logoAsset = 'assets/images/icon_without_bg.png';

  static List<_MenuGroup> get _labelGroups => <_MenuGroup>[
    _MenuGroup(
      title: 'Label',
      icon: Icons.label_outlined,
      children: [
        _SubItem(
          title: 'Bahan Baku',
          icon: Icons.inventory_2_outlined,
          route: '/label/bahan-baku',
        ),
        _SubItem(
          title: 'Washing',
          icon: Icons.local_laundry_service_outlined,
          route: '/label/washing',
        ),
        _SubItem(
          title: 'Broker',
          icon: Icons.handshake_outlined,
          route: '/label/broker',
        ),
        _SubItem(
          title: 'Bonggolan',
          icon: Icons.category_outlined,
          route: '/label/bonggolan',
        ),
        _SubItem(
          title: 'Crusher',
          icon: Icons.construction_outlined,
          route: '/label/crusher',
        ),
        _SubItem(
          title: 'Gilingan',
          icon: Icons.settings_outlined,
          route: '/label/gilingan',
        ),
        _SubItem(
          title: 'Mixer',
          icon: Icons.blender_outlined,
          route: '/label/mixer',
        ),
        _SubItem(
          title: 'Furniture WIP',
          icon: Icons.chair_outlined,
          route: '/label/furniture_wip',
        ),
        _SubItem(
          title: 'Barang Jadi',
          icon: Icons.inventory_outlined,
          route: '/label/packing',
        ),
        _SubItem(
          title: 'Reject',
          icon: Icons.cancel_outlined,
          route: '/label/reject',
        ),
      ],
    ),
  ];

  static List<_MenuItem> get _bahanPendukungItems => <_MenuItem>[
    _MenuItem(
      title: 'Penerimaan Bahan Pendukung',
      subtitle: 'Input penerimaan bahan pendukung',
      icon: Icons.move_to_inbox_outlined,
      route: '/shell/penerimaan-bahan-pendukung',
    ),
  ];

  static List<_MenuGroup> get _divisiGroups => <_MenuGroup>[
    _MenuGroup(
      title: 'Washing & Broker',
      icon: Icons.water_outlined,
      children: [
        _SubItem(
          title: 'Penerimaan Bahan Baku',
          icon: Icons.move_to_inbox_outlined,
          route: '/shell/penerimaan-bahan-baku',
        ),
        _SubItem(
          title: 'Proses Washing',
          icon: Icons.local_laundry_service_outlined,
          route: '/production/washing',
        ),
        _SubItem(
          title: 'Proses Broker',
          icon: Icons.handshake_outlined,
          route: '/production/broker',
        ),
        _SubItem(
          title: 'Proses Crusher',
          icon: Icons.construction_outlined,
          route: '/production/crusher',
        ),
      ],
    ),
    _MenuGroup(
      title: 'Pin Hulu',
      icon: Icons.precision_manufacturing_outlined,
      children: [
        _SubItem(
          title: 'Proses Mixer',
          icon: Icons.blender_outlined,
          route: '/production/mixer',
        ),
        _SubItem(
          title: 'Proses Inject',
          icon: Icons.invert_colors_outlined,
          route: '/shell/inject',
        ),
        _SubItem(
          title: 'Proses Gilingan',
          icon: Icons.settings_outlined,
          route: '/production/gilingan',
        ),
      ],
    ),
    _MenuGroup(
      title: 'Pin Hilir',
      icon: Icons.account_tree_outlined,
      children: [
        _SubItem(
          title: 'Stamping',
          icon: Icons.local_fire_department_outlined,
          route: '/shell/hot-stamp',
        ),
        _SubItem(
          title: 'Pasang Kunci Long Door',
          icon: Icons.key_outlined,
          route: '/shell/key-fitting',
        ),
        _SubItem(
          title: 'Packing Spanner',
          icon: Icons.hardware_outlined,
          route: '/shell/spanner',
        ),
        _SubItem(
          title: 'Packing',
          icon: Icons.inventory_outlined,
          route: '/shell/packing',
        ),
      ],
    ),
    _MenuGroup(
      title: 'Warehouse',
      icon: Icons.warehouse_outlined,
      children: [
        _SubItem(
          title: 'Penerimaan Barang Dagang',
          icon: Icons.move_to_inbox_outlined,
          route: '/shell/penerimaan-barang-dagang',
        ),
        _SubItem(
          title: 'Retur',
          icon: Icons.assignment_return_outlined,
          route: '/shell/retur-v2',
        ),
        _SubItem(
          title: 'Retur v3',
          icon: Icons.assignment_return_rounded,
          route: '/shell/retur-v3',
        ),
        _SubItem(
          title: 'BJ Jual',
          icon: Icons.sell_outlined,
          route: '/shell/bj-jual',
        ),
        _SubItem(
          title: 'Penjualan',
          icon: Icons.point_of_sale_outlined,
          route: '/shell/penjualan',
        ),
        _SubItem(
          title: 'Trade-In',
          icon: Icons.swap_horiz_outlined,
          route: '/shell/trade-in',
        ),
        _SubItem(
          title: 'Goods Transfer',
          icon: Icons.local_shipping_outlined,
          route: '/shell/goods-transfer',
        ),
        _SubItem(
          title: 'In Transit',
          icon: Icons.move_to_inbox_outlined,
          route: '/shell/in-transit',
        ),
      ],
    ),
  ];

  static List<_MenuItem> get _operasionalItems => <_MenuItem>[
    _MenuItem(
      title: 'Stock',
      subtitle: 'Stock per proses',
      icon: Icons.assessment_outlined,
      route: '/shell/stock',
    ),
    _MenuItem(
      title: 'Bongkar Susun',
      subtitle: 'Input data Bongkar Susun',
      icon: Icons.layers_outlined,
      route: '/shell/bongkar-susun',
    ),
    _MenuItem(
      title: 'Sortir Reject',
      subtitle: 'Input data Sortir Reject',
      icon: Icons.filter_alt_outlined,
      route: '/shell/sortir-reject',
    ),
    _MenuItem(
      title: 'Stock Opname',
      subtitle: 'Stock opname per kategori',
      icon: Icons.fact_check_outlined,
      route: '/shell/stock-opname-v2',
    ),
    _MenuItem(
      title: 'Stock Opname (Old)',
      subtitle: 'Stock opname versi lama',
      icon: Icons.fact_check_outlined,
      route: '/stockopname',
    ),
    _MenuItem(
      title: 'Warehouse',
      subtitle: 'Kelompokkan warehouse satu site',
      icon: Icons.workspaces_outline,
      route: '/shell/warehouse-group',
    ),
  ];

  static List<_MenuItem> get _laporanItems => <_MenuItem>[
    _MenuItem(
      title: 'Laporan',
      subtitle: 'Lihat laporan',
      icon: Icons.bar_chart_outlined,
      route: '/shell/laporan',
    ),
    _MenuItem(
      title: 'History',
      subtitle: 'Lihat history aktivitas',
      icon: Icons.history,
      route: '/shell/history',
    ),
    _MenuItem(
      title: 'Mapping',
      subtitle: 'Monitoring lokasi label',
      icon: Icons.map_outlined,
      route: '/shell/mapping',
    ),
  ];

  void _navigateTo(String route, String title, {String? parentTitle}) {
    setState(() => _selectedRoute = route);
    widget.onNavigate(title, parentTitle: parentTitle);
    widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      route,
      (r) => false,
    );
  }

  void _toggleGroup(String title) {
    setState(() => _expandedGroup = _expandedGroup == title ? null : title);
  }

  void _handleGroupTap(String title) {
    if (_collapsed) {
      setState(() => _expandedGroup = title);
      widget.onToggleCollapse();
      return;
    }

    _toggleGroup(title);
  }

  bool get _collapsed => widget.isCollapsed;

  @override
  Widget build(BuildContext context) {
    final contentWidth = _collapsed ? 64.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: contentWidth,
      decoration: const BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 0)),
        ],
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: contentWidth,
          maxWidth: contentWidth,
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                _buildHeader(),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      _buildFlatItem(
                        _MenuItem(
                          title: 'Dashboard',
                          subtitle: 'Halaman utama',
                          icon: Icons.dashboard_outlined,
                          route: '/shell/welcome',
                        ),
                      ),
                      _buildSectionHeader('Label'),
                      for (int i = 0; i < _labelGroups.length; i++)
                        _buildGroup(i, _labelGroups),
                      _buildSectionHeader('Bahan Pendukung'),
                      for (final item in _bahanPendukungItems)
                        _buildFlatItem(item),
                      _buildSectionHeader('Proses Produksi'),
                      for (int i = 0; i < _divisiGroups.length; i++)
                        _buildGroup(i, _divisiGroups),
                      _buildSectionHeader('Operasional'),
                      for (final item in _operasionalItems)
                        _buildFlatItem(item),
                      _buildSectionHeader('Laporan & Monitoring'),
                      for (final item in _laporanItems) _buildFlatItem(item),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_collapsed) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Image.asset(_logoAsset, width: 30, height: 30),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Image.asset(_logoAsset, width: 24, height: 24),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'PPS Tablet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              'Plastic Production System',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    if (_collapsed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroup(int index, List<_MenuGroup> groups) {
    final group = groups[index];
    final isExpanded = _expandedGroup == group.title && !_collapsed;
    final hasActiveChild = group.children.any((c) => c.route == _selectedRoute);
    final isActive = isExpanded || hasActiveChild;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        children: [
          Tooltip(
            message: _collapsed ? group.title : '',
            preferBelow: false,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _handleGroupTap(group.title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: EdgeInsets.symmetric(
                    horizontal: _collapsed ? 0 : 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _collapsed
                      ? Center(
                          child: Icon(
                            group.icon,
                            color: isActive ? Colors.white : Colors.white70,
                            size: 20,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              group.icon,
                              color: isActive ? Colors.white : Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                group.title,
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: isExpanded ? 0.25 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: Icon(
                                Icons.chevron_right,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          // Sub items — hanya tampil saat expanded & tidak collapsed
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: isExpanded
                ? Column(
                    children: group.children
                        .map(
                          (sub) => _buildSubItem(sub, parentTitle: group.title),
                        )
                        .toList(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem(_SubItem sub, {required String parentTitle}) {
    final isSelected = _selectedRoute == sub.route;
    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              _navigateTo(sub.route, sub.title, parentTitle: parentTitle),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  sub.icon,
                  color: isSelected ? Colors.white : Colors.white60,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  sub.title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlatItem(_MenuItem item) {
    final isSelected = _selectedRoute == item.route;
    final isDisabled = !item.enabled;
    final tooltipMessage = isDisabled
        ? '${item.title} — Under Construction'
        : (_collapsed ? item.title : '');
    final iconColor = isDisabled
        ? Colors.white.withValues(alpha: 0.3)
        : (isSelected ? Colors.white : Colors.white70);
    final textColor = isDisabled
        ? Colors.white.withValues(alpha: 0.3)
        : (isSelected ? Colors.white : Colors.white70);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Tooltip(
        message: tooltipMessage,
        preferBelow: false,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: isDisabled
                ? null
                : () => _navigateTo(item.route, item.title),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: _collapsed ? 0 : 12,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: _collapsed
                  ? Center(child: Icon(item.icon, color: iconColor, size: 20))
                  : Row(
                      children: [
                        Icon(item.icon, color: iconColor, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isDisabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Under Construction',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          )
                        else if (isSelected)
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.white,
                            size: 16,
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Handle bulat untuk toggle collapse/expand [HomeSidebar] — dipakai oleh
/// pemanggil (mis. `AppShell`) di dalam `Stack` yang membungkus sidebar dan
/// area konten, diposisikan menempel di garis tepi sidebar (separuh di
/// dalam, separuh menonjol ke konten). Sengaja dirender dari luar
/// [HomeSidebar], bukan dari dalam — bila digambar di dalam sidebar sendiri
/// (sebagai sibling di `Row` bersama area konten), separuh yang menonjol
/// akan tertutup karena area konten digambar belakangan dalam urutan `Row`.
class SidebarToggleHandle extends StatelessWidget {
  const SidebarToggleHandle({
    super.key,
    required this.isCollapsed,
    required this.onTap,
  });

  final bool isCollapsed;
  final VoidCallback onTap;

  static const Color _primaryColor = Color(0xFF0D47A1);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isCollapsed ? 'Tampilkan Sidebar' : 'Sembunyikan Sidebar',
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: Colors.black38,
        shape: const CircleBorder(
          side: BorderSide(color: _primaryColor, width: 2),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 28,
            height: 28,
            child: Icon(
              isCollapsed ? Icons.chevron_right : Icons.chevron_left,
              size: 16,
              color: _primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuGroup {
  final String title;
  final IconData icon;
  final List<_SubItem> children;

  const _MenuGroup({
    required this.title,
    required this.icon,
    required this.children,
  });
}

class _SubItem {
  final String title;
  final IconData icon;
  final String route;

  const _SubItem({
    required this.title,
    required this.icon,
    required this.route,
  });
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final bool enabled;

  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    this.enabled = true,
  });
}
