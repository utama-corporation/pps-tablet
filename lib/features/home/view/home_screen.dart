import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/pps_menu_catalog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/user_session_storage.dart';
import '../../../core/view/app_shell.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../../favorit/view_model/favorit_view_model.dart';
import '../../report/view/report_open_helper.dart';
import '../../update/model/update_model.dart';
import '../../update/view/widgets/update_auto_sheet.dart';
import '../../update/view_model/update_view_model.dart';
import '../dashboard/dashboard_header.dart';
import '../dashboard/home_dashboard.dart';
import '../repository/dashboard_home_repository.dart';

/// Halaman Dashboard utama (shell `/shell/welcome`).
///
/// Semua dependensi bisa di-override (untuk test); default-nya memakai
/// sesi lokal, provider global, dan server update.
class HomeScreen extends StatelessWidget {
  final DashboardHomeRepository? repository;
  final DashOpenRoute? onOpenRoute;
  final Future<DashUser?> Function()? loadUser;
  final Future<UpdateInfo?> Function()? checkUpdate;

  const HomeScreen({
    super.key,
    this.repository,
    this.onOpenRoute,
    this.loadUser,
    this.checkUpdate,
  });

  static void _openInShell(String route, String title) {
    AppShell.breadcrumb.value = [BreadcrumbSegment(title)];
    AppShell.currentRoute.value = route;
    // Sama seperti sidebar/favorit: layar tujuan menggantikan dashboard.
    AppShell.shellNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      route,
      (_) => false,
    );
  }

  static Future<DashUser?> _sessionUser() async {
    final name =
        await UserSessionStorage.getFullName() ??
        await UserSessionStorage.getUsername(fallback: '');
    final group = await UserSessionStorage.getUGroupName() ?? '';
    return name.isEmpty ? null : DashUser(name, group);
  }

  static T? _maybe<T>(BuildContext context, {bool listen = true}) {
    try {
      return Provider.of<T>(context, listen: listen);
    } on ProviderNotFoundException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final perms = _maybe<PermissionViewModel>(context);
    // Kartu favorit mendengarkan VM sendiri; layar tidak perlu ikut rebuild.
    final favorit = _maybe<FavoritViewModel>(context, listen: false);
    // Satu instance: dipakai untuk cek di dashboard dan dialog update.
    final updater = checkUpdate == null ? UpdateViewModel() : null;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: DashboardBody(
          repository: repository ?? DashboardHomeRepository(api: ApiClient()),
          onOpenRoute: onOpenRoute ?? _openInShell,
          canOpenRoute: perms == null
              ? null
              : (route) => PpsMenuCatalog.canOpenRoute(route, perms.can),
          loadUser: loadUser ?? _sessionUser,
          permissionCount: perms?.permissions.length,
          favorit: favorit,
          onOpenReport: (report) => openReportItem(context, report),
          checkUpdate: checkUpdate ?? updater!.checkForUpdate,
          onUpdate: (_) =>
              UpdateDialog.show(context, vm: updater ?? UpdateViewModel()),
        ),
      ),
    );
  }
}
