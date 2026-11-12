import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/navigation/pps_menu_catalog.dart';
import '../../../../core/view_model/permission_view_model.dart';

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
  String _selectedRoute = '/shell/welcome';
  String? _expandedGroup;
  static const Color _primaryColor = Color(0xFF0D47A1);
  static const String _logoAsset = 'assets/images/icon_without_bg.png';
  bool get _collapsed => widget.isCollapsed;

  void _navigateTo(PpsMenuItem item, {String? parentTitle}) {
    if (!item.isAvailable ||
        !item.canView(context.read<PermissionViewModel>().can)) {
      return;
    }
    setState(() => _selectedRoute = item.route!);
    widget.onNavigate(item.title, parentTitle: parentTitle);
    widget.navigatorKey.currentState?.pushNamedAndRemoveUntil(
      item.route!,
      (route) => false,
    );
  }

  void _handleGroupTap(String title) {
    setState(
      () =>
          _expandedGroup = _collapsed || _expandedGroup != title ? title : null,
    );
    if (_collapsed) widget.onToggleCollapse();
  }

  @override
  Widget build(BuildContext context) {
    final sections = PpsMenuCatalog.visibleSections(
      context.watch<PermissionViewModel>().can,
    );
    return AnimatedContainer(
      key: const ValueKey('pps-sidebar'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _collapsed ? 64 : 260,
      decoration: const BoxDecoration(
        color: _primaryColor,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 0)),
        ],
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: _collapsed ? 64 : 260,
          maxWidth: _collapsed ? 64 : 260,
          child: SizedBox(
            width: _collapsed ? 64 : 260,
            child: Column(
              children: [
                _buildHeader(),
                const Divider(color: Colors.white24, height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      for (final section in sections) ...[
                        if (section.title != null)
                          _buildSectionHeader(section.title!),
                        for (final entry in section.entries)
                          if (entry is PpsMenuGroup)
                            _buildGroup(entry)
                          else if (entry is PpsMenuItem)
                            _buildItem(
                              entry,
                              parentTitle: section.title == 'System'
                                  ? section.title
                                  : null,
                            ),
                      ],
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
                  'PPS Mobile',
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
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroup(PpsMenuGroup group) {
    final expanded = _expandedGroup == group.title && !_collapsed;
    final active =
        expanded ||
        group.children.any((item) => item.matchesRoute(_selectedRoute));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        children: [
          Tooltip(
            message: _collapsed ? group.title : '',
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('menu-group-${group.title}'),
                borderRadius: BorderRadius.circular(10),
                onTap: () => _handleGroupTap(group.title),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: EdgeInsets.symmetric(
                    horizontal: _collapsed ? 0 : 12,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _collapsed
                      ? Center(
                          child: Icon(
                            group.icon,
                            color: Colors.white70,
                            size: 20,
                          ),
                        )
                      : Row(
                          children: [
                            Icon(
                              group.icon,
                              color: active ? Colors.white : Colors.white70,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                group.title,
                                style: TextStyle(
                                  color: active ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: active
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                            AnimatedRotation(
                              turns: expanded ? 0.25 : 0,
                              duration: const Duration(milliseconds: 180),
                              child: const Icon(
                                Icons.chevron_right,
                                color: Colors.white70,
                                size: 16,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: expanded
                ? Column(
                    children: [
                      for (final item in group.children)
                        _buildItem(item, parentTitle: group.title),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(PpsMenuItem item, {String? parentTitle}) {
    final selected = item.isAvailable && item.matchesRoute(_selectedRoute);
    final enabled = item.isAvailable;
    final color = selected ? Colors.white : Colors.white70;
    final tooltip = !enabled
        ? '${item.title} — Belum tersedia di tablet'
        : (_collapsed ? item.title : '');
    return Padding(
      padding: EdgeInsets.only(
        left: parentTitle == null ? 8 : 16,
        right: parentTitle == null ? 8 : 0,
        top: 2,
        bottom: parentTitle == null ? 2 : 0,
      ),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('menu-item-${item.id}'),
            borderRadius: BorderRadius.circular(parentTitle == null ? 10 : 8),
            onTap: enabled
                ? () => _navigateTo(item, parentTitle: parentTitle)
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 44),
              padding: EdgeInsets.symmetric(
                horizontal: _collapsed ? 0 : (parentTitle == null ? 12 : 10),
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(
                  parentTitle == null ? 10 : 8,
                ),
              ),
              child: _collapsed
                  ? Center(child: Icon(item.icon, color: color, size: 20))
                  : Row(
                      children: [
                        Icon(
                          item.icon,
                          color: color,
                          size: parentTitle == null ? 20 : 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(
                                  color: color,
                                  fontSize: parentTitle == null ? 13 : 12,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                              if (!enabled)
                                const Padding(
                                  padding: EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Belum tersedia di tablet',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (!enabled)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.schedule_outlined,
                              color: Colors.white70,
                              size: 14,
                            ),
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
