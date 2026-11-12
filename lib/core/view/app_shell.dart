import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pps_tablet/features/spk/view/spk_screen.dart';
import 'package:pps_tablet/features/label/barang_dagang/view/barang_dagang_screen.dart';
import 'package:pps_tablet/core/navigation/pps_menu_catalog.dart';
import 'package:pps_tablet/core/services/permission_storage.dart';
import 'package:pps_tablet/core/services/token_storage.dart';
import 'package:pps_tablet/core/services/user_session_storage.dart';
import 'package:pps_tablet/core/view_model/label_print_lock_socket_manager.dart';
import 'package:pps_tablet/core/view_model/permission_view_model.dart';
import 'package:pps_tablet/features/audit/view/audit_screen.dart';
import 'package:pps_tablet/features/bahan_pendukung/penerimaan/view/penerimaan_bahan_pendukung_screen.dart';
import 'package:pps_tablet/features/bj_jual/view/bj_jual_screen.dart';
import 'package:pps_tablet/features/bongkar_susun_v2/view/bs_v2_list_screen.dart';
import 'package:pps_tablet/features/favorit/view/favorit_screen.dart';
import 'package:pps_tablet/features/favorit/view_model/favorit_view_model.dart';
import 'package:pps_tablet/features/favorit/widgets/favorite_button.dart';
import 'package:pps_tablet/features/home/view/home_screen.dart';
import 'package:pps_tablet/features/home/view/widgets/account_info_dialog.dart';
import 'package:pps_tablet/features/home/view/widgets/home_sidebar.dart';
import 'package:pps_tablet/features/home/view/widgets/user_profile_dialog.dart';
import 'package:pps_tablet/features/label/bahan_baku/view/bahan_baku_screen.dart';
import 'package:pps_tablet/features/label/bahan_pend_support/view/bahan_pend_support_screen.dart';
import 'package:pps_tablet/features/label/bonggolan/view/bonggolan_screen.dart';
import 'package:pps_tablet/features/label/broker/view/broker_screen.dart';
import 'package:pps_tablet/features/label/crusher/view/crusher_screen.dart';
import 'package:pps_tablet/features/label/furniture_wip/view/furniture_wip_screen.dart';
import 'package:pps_tablet/features/label/gilingan/view/gilingan_screen.dart';
import 'package:pps_tablet/features/label/mixer/view/mixer_screen.dart';
import 'package:pps_tablet/features/label/packing/view/packing_screen.dart';
import 'package:pps_tablet/features/label/reject/view/reject_screen.dart';
import 'package:pps_tablet/features/label/selection/view/label_selection_screen.dart';
import 'package:pps_tablet/features/label/washing/view/washing_screen.dart';
import 'package:pps_tablet/features/mapping/view/mapping_screen.dart';
import 'package:pps_tablet/features/penjualan/view/penjualan_list_screen.dart';
import 'package:pps_tablet/features/goods_transfer/view/goods_transfer_list_screen.dart';
import 'package:pps_tablet/features/warehouse_group/view/warehouse_group_screen.dart';
import 'package:pps_tablet/features/in_transit/view/in_transit_list_screen.dart';
import 'package:pps_tablet/features/production/broker/view/broker_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/crusher/view/crusher_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/gilingan/view/gilingan_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/hot_stamp/view/hot_stamp_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/hot_stamp/view/hot_stamp_production_screen.dart';
import 'package:pps_tablet/features/production/inject/view/inject_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/inject/view/inject_production_screen.dart';
import 'package:pps_tablet/features/production/key_fitting/view/key_fitting_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/mixer/view/mixer_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/packing/view/packing_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/penerimaan_bahan_baku/view/penerimaan_bahan_baku_screen.dart';
import 'package:pps_tablet/features/production/return/view/return_production_screen.dart';
import 'package:pps_tablet/features/retur_v2/view/retur_v2_screen.dart';
import 'package:pps_tablet/features/retur_v3/view/retur_v3_list_screen.dart';
import 'package:pps_tablet/features/trade_in/view/trade_in_screen.dart';
import 'package:pps_tablet/features/production/selection/view/production_selection_screen.dart';
import 'package:pps_tablet/features/production/sortir_reject/view/sortir_reject_production_screen.dart';
import 'package:pps_tablet/features/production/spanner/view/spanner_production_mesin_screen.dart';
import 'package:pps_tablet/features/production/spanner/view/spanner_production_screen.dart';
import 'package:pps_tablet/features/production/washing/view/washing_production_mesin_screen.dart';
import 'package:pps_tablet/features/report/view/report_list_screen.dart';
import 'package:pps_tablet/features/sortir_reject_v2/view/sr_v2_list_screen.dart';
import 'package:pps_tablet/features/stock/view/stock_selection_screen.dart';
import 'package:pps_tablet/features/stock_opname/view/stock_opname_list_screen.dart';
import 'package:pps_tablet/features/stock_opname_v2/view/so_v2_kategori_list_screen.dart';
import 'package:pps_tablet/features/master_barang/view/master_barang_screen.dart';
import 'package:pps_tablet/features/master_cetakan/view/master_cetakan_screen.dart';
import 'package:pps_tablet/features/master_blok_lokasi/view/master_blok_lokasi_screen.dart';
import 'package:pps_tablet/features/master_formula/view/master_formula_screen.dart';
import 'package:pps_tablet/features/master_mesin/view/master_mesin_screen.dart';
import 'package:pps_tablet/features/master_supplier/view/master_supplier_screen.dart';
import 'package:pps_tablet/features/master_user/view/master_user_screen.dart';
import 'package:pps_tablet/features/master_operator_regu/view/master_operator_regu_screen.dart';
import 'package:pps_tablet/features/role/view/role_screen.dart';
import 'package:pps_tablet/features/penerimaan_barang_dagang/view/penerimaan_barang_dagang_screen.dart';
import 'package:provider/provider.dart';

class BreadcrumbSegment {
  final String label;
  final VoidCallback? onTap;
  const BreadcrumbSegment(this.label, {this.onTap});
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static final shellNavigatorKey = GlobalKey<NavigatorState>();

  /// Global breadcrumb — screens can push/pop segments to show navigation flow.
  static final breadcrumb = ValueNotifier<List<BreadcrumbSegment>>([
    const BreadcrumbSegment('Dashboard'),
  ]);

  /// Route layar yang sedang tampil di inner navigator (null bila tidak diketahui).
  static final currentRoute = ValueNotifier<String?>(null);

  /// Kode favorit laporan yang sedang terbuka (null bila bukan layar laporan).
  /// Saat terisi, bintang di app bar men-toggle favorit laporan, bukan menu.
  static final currentReport = ValueNotifier<String?>(null);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;
  String? _username;
  String? _ugroupName;

  @override
  void initState() {
    super.initState();
    AppShell.breadcrumb.addListener(_onBreadcrumbChanged);
    // Setelah frame pertama: load() memanggil notifyListeners, yang tidak
    // boleh terjadi di tengah build (di release membuat bintang favorit
    // berhenti ter-update).
    final favorit = context.read<FavoritViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(favorit.load());
    });
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final username = await UserSessionStorage.getUsername(fallback: '-');
    final fullName = await UserSessionStorage.getFullName();
    final ugroupName = await UserSessionStorage.getUGroupName();
    if (mounted) {
      setState(() {
        _username = _firstName(fullName) ?? username;
        _ugroupName = ugroupName;
      });
    }
  }

  /// Ambil nama depan saja dari fullname (kata pertama sebelum spasi).
  static String? _firstName(String? fullName) {
    final trimmed = fullName?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.split(RegExp(r'\s+')).first;
  }

  void _onBreadcrumbChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppShell.breadcrumb.removeListener(_onBreadcrumbChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (AppShell.shellNavigatorKey.currentState?.canPop() ?? false) {
          AppShell.shellNavigatorKey.currentState?.maybePop();
          return;
        }
        if (!context.mounted) return;
        final confirm = await _showExitDialog(context);
        if ((confirm ?? false) && context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                children: [
                  HomeSidebar(
                    navigatorKey: AppShell.shellNavigatorKey,
                    isCollapsed: _sidebarCollapsed,
                    onToggleCollapse: () =>
                        setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                    onNavigate: (title, {String? parentTitle}) {
                      if (parentTitle != null) {
                        AppShell.breadcrumb.value = [
                          BreadcrumbSegment(parentTitle),
                          BreadcrumbSegment(title),
                        ];
                      } else {
                        AppShell.breadcrumb.value = [BreadcrumbSegment(title)];
                      }
                    },
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _buildCompactAppBar(context),
                        Expanded(
                          child: ClipRect(
                            child: Navigator(
                              key: AppShell.shellNavigatorKey,
                              initialRoute: '/shell/welcome',
                              onGenerateRoute: _generateRoute,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // ── Toggle handle: menempel di garis tepi sidebar, separuh
              // di dalam & separuh menonjol ke konten. Dirender di sini
              // (bukan di dalam HomeSidebar) supaya tergambar di atas
              // area konten, tidak tertutup olehnya.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                left: (_sidebarCollapsed ? 64.0 : 260.0) - 14,
                top: 26,
                child: SidebarToggleHandle(
                  isCollapsed: _sidebarCollapsed,
                  onTap: () =>
                      setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactAppBar(BuildContext context) {
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final segments = AppShell.breadcrumb.value;
    final pageTitle = segments.isNotEmpty ? segments.last.label : 'Dashboard';
    final username = _username ?? '-';

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: title + breadcrumb
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                _BreadcrumbRow(segments: segments),
              ],
            ),
          ),

          _buildFavoriteAction(),
          _buildUserChip(context, username),
        ],
      ),
    );
  }

  /// Bintang favorit: laporan bila sedang membuka layar laporan,
  /// selain itu menu bernama rute (semua menu sidebar).
  Widget _buildFavoriteAction() {
    return ValueListenableBuilder<String?>(
      valueListenable: AppShell.currentReport,
      builder: (context, reportKode, _) {
        if (reportKode != null) {
          return FavoriteButton(
            tipe: 'laporan',
            kode: reportKode,
            iconSize: 20,
          );
        }
        return ValueListenableBuilder<String?>(
          valueListenable: AppShell.currentRoute,
          builder: (context, route, _) {
            if (route == null) return const SizedBox.shrink();
            if (route == '/shell/favorit') return const SizedBox.shrink();
            if (PpsMenuCatalog.forRoute(route) == null) {
              return const SizedBox.shrink();
            }
            return FavoriteButton(tipe: 'menu', kode: route, iconSize: 20);
          },
        );
      },
    );
  }

  Widget _buildUserChip(BuildContext context, String username) {
    return PopupMenuButton<_UserMenuAction>(
      tooltip: 'Akun',
      offset: const Offset(0, 44),
      color: Colors.white,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
      ),
      onSelected: (action) {
        switch (action) {
          case _UserMenuAction.account:
            _showAccountDialog();
            break;
          case _UserMenuAction.changePassword:
            _showChangePasswordDialog();
            break;
          case _UserMenuAction.logout:
            _handleLogout(context);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<_UserMenuAction>(
          enabled: false,
          height: 70,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF0D47A1),
                child: Text(
                  _initials(username),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Masuk sebagai',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1E293B),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((_ugroupName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        _ugroupName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.account,
          height: 44,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.manage_accounts_outlined,
                  color: Color(0xFF0D47A1),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Profile',
                style: TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.changePassword,
          height: 44,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_reset_outlined,
                  color: Color(0xFF0D47A1),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Ubah Password',
                style: TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<_UserMenuAction>(
          value: _UserMenuAction.logout,
          height: 44,
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.logout,
                  color: Color(0xFFDC2626),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Logout',
                style: TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF0D47A1),
            child: Text(
              _initials(username),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                (_ugroupName ?? '').isNotEmpty ? _ugroupName! : '-',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down,
            color: Color(0xFF64748B),
            size: 16,
          ),
        ],
      ),
    );
  }

  void _showAccountDialog() {
    showDialog(context: context, builder: (_) => const AccountInfoDialog());
  }

  void _showChangePasswordDialog() {
    showDialog(context: context, builder: (_) => const UserProfileDialog());
  }

  String _initials(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty || trimmed == '-') return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  Future<void> _handleLogout(BuildContext context) async {
    final socketMgr = context.read<LabelPrintLockSocketManager>();
    final permVm = context.read<PermissionViewModel>();

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    socketMgr.disconnect();
    await TokenStorage.clear();
    await PermissionStorage.clear();
    await UserSessionStorage.clear();

    if (context.mounted) {
      permVm.clear();
      Navigator.of(
        context,
        rootNavigator: true,
      ).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Route<dynamic> _generateRoute(RouteSettings settings) {
    AppShell.currentRoute.value = settings.name;
    final can = context.read<PermissionViewModel>().can;
    final Widget page = PpsMenuCatalog.canOpenRoute(settings.name, can)
        ? _pageForRoute(settings.name)
        : const Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 40),
                    SizedBox(height: 12),
                    Text(
                      'Akses ditolak',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Anda tidak memiliki akses ke menu ini. Hubungi administrator untuk informasi hak akses.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
    return MaterialPageRoute(builder: (_) => page, settings: settings);
  }

  Widget _pageForRoute(String? name) {
    switch (name) {
      case '/shell/welcome':
        return const HomeScreen();
      case '/label':
        return LabelSelectionScreen();
      case '/label/bahan-baku':
        return BahanBakuScreen();
      case '/label/washing':
        return WashingTableScreen();
      case '/label/broker':
        return BrokerScreen();
      case '/label/bonggolan':
        return BonggolanScreen();
      case '/label/crusher':
        return CrusherScreen();
      case '/label/gilingan':
        return GilinganScreen();
      case '/label/mixer':
        return MixerScreen();
      case '/label/furniture_wip':
        return FurnitureWipScreen();
      case '/label/packing':
        return PackingScreen();
      case '/label/reject':
        return RejectScreen();
      case '/label/barang-dagang':
        return const BarangDagangScreen();
      case '/production/spk-barang-jadi':
        return const SpkScreen();
      case '/label/bahan-pendukung':
        return BahanPendukungScreen();
      case '/production':
        return ProductionSelectionScreen();
      case '/production/washing':
        return const WashingProductionMesinScreen();
      case '/production/broker':
        return const BrokerProductionMesinScreen();
      case '/production/crusher':
        return const CrusherProductionMesinScreen();
      case '/production/gilingan':
        return const GilinganProductionMesinScreen();
      case '/production/mixer':
        return const MixerProductionMesinScreen();
      case '/shell/penerimaan-bahan-pendukung':
        return const PenerimaanBahanPendukungScreen();
      case '/shell/penerimaan-barang-dagang':
        return const PenerimaanBarangDagangScreen();
      case '/shell/penerimaan-bahan-baku':
        return const PenerimaanBahanBakuScreen();
      case '/shell/hot-stamp':
        return const HotStampProductionMesinScreen();
      case '/production/hot-stamp':
        return HotStampProductionScreen();
      case '/shell/inject':
        return const InjectProductionMesinScreen();
      case '/production/inject':
        return InjectProductionScreen();
      case '/shell/key-fitting':
      case '/production/key-fitting':
        return KeyFittingProductionMesinScreen();
      case '/shell/spanner':
        return const SpannerProductionMesinScreen();
      case '/production/spanner':
        return SpannerProductionScreen();
      case '/shell/packing':
      case '/production/packing':
        return PackingProductionMesinScreen();
      case '/production/sortir-reject':
        return SortirRejectProductionScreen();
      case '/shell/return':
      case '/production/return':
        return ReturnProductionScreen();
      case '/shell/retur-v2':
        return const ReturV2Screen();
      case '/shell/retur-v3':
        return const ReturV3ListScreen();
      case '/shell/trade-in':
        return const TradeInScreen();
      case '/stockopname':
        return StockOpnameListScreen();
      case '/shell/bongkar-susun':
        return const BsV2ListScreen();
      case '/shell/sortir-reject':
        return const SrV2ListScreen();
      case '/shell/stock':
        return const StockSelectionScreen();
      case '/shell/stock-opname-v2':
        return const SoV2KategoriListScreen();
      case '/shell/bj-jual':
        return const BJJualScreen();
      case '/shell/penjualan':
        return const PenjualanListScreen();
      case '/shell/laporan':
        return const ReportListScreen();
      case '/laporan/bahan-baku':
        return const ReportListScreen(categoryKey: 'bahan-baku');
      case '/laporan/washing':
        return const ReportListScreen(categoryKey: 'washing');
      case '/laporan/broker':
        return const ReportListScreen(categoryKey: 'broker');
      case '/laporan/bonggolan':
        return const ReportListScreen(categoryKey: 'bonggolan');
      case '/laporan/crusher':
        return const ReportListScreen(categoryKey: 'crusher');
      case '/laporan/gilingan':
        return const ReportListScreen(categoryKey: 'gilingan');
      case '/laporan/mixer':
        return const ReportListScreen(categoryKey: 'mixer');
      case '/laporan/reject':
        return const ReportListScreen(categoryKey: 'reject');
      case '/laporan/furniture-wip':
        return const ReportListScreen(categoryKey: 'furniture-wip');
      case '/laporan/barang-jadi':
        return const ReportListScreen(categoryKey: 'barang-jadi');
      case '/laporan/barang-dagang':
        return const ReportListScreen(categoryKey: 'barang-dagang');
      case '/laporan/rekap-produksi':
        return const ReportListScreen(categoryKey: 'rekap-produksi');
      case '/laporan/semua':
        return const ReportListScreen(categoryKey: 'semua');
      case '/shell/history':
        return const AuditScreen();
      case '/shell/user':
        return const MasterUserScreen();
      case '/master/operator-regu':
        return const MasterOperatorReguScreen();
      case '/master/mesin-produksi':
        return const MasterMesinScreen();
      case '/master/barang':
        return const MasterBarangScreen();
      case '/master/supplier':
        return const MasterSupplierScreen();
      case '/master/cetakan':
        return const MasterCetakanScreen();
      case '/master/formula':
        return const MasterFormulaScreen();
      case '/master/blok-lokasi':
        return const MasterBlokLokasiScreen();
      case '/shell/favorit':
        return const FavoritScreen();
      case '/shell/role':
        return const RoleScreen();
      case '/shell/mapping':
        return const MappingScreen();
      case '/shell/goods-transfer':
        return const GoodsTransferListScreen();
      case '/shell/warehouse-group':
        return const WarehouseGroupScreen();
      case '/shell/in-transit':
        return const InTransitListScreen();
      default:
        return const HomeScreen();
    }
  }

  Future<bool?> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Tidak'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7a1b0c),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Ya', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

enum _UserMenuAction { account, changePassword, logout }

class _BreadcrumbRow extends StatelessWidget {
  final List<BreadcrumbSegment> segments;
  const _BreadcrumbRow({required this.segments});

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) return const SizedBox.shrink();

    final items = <Widget>[];
    for (var i = 0; i < segments.length; i++) {
      final seg = segments[i];
      final isLast = i == segments.length - 1;
      final label = Text(
        seg.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isLast ? const Color(0xFF374151) : const Color(0xFF9CA3AF),
          fontSize: 11,
          fontWeight: isLast ? FontWeight.w600 : FontWeight.w400,
        ),
      );

      items.add(
        !isLast && seg.onTap != null
            ? InkWell(
                onTap: seg.onTap,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: label,
                ),
              )
            : label,
      );

      if (!isLast) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 12,
              color: Color(0xFFD1D5DB),
            ),
          ),
        );
      }
    }

    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }
}
