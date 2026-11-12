import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/interactive_popover.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../model/barang_dagang_label.dart';
import '../repository/barang_dagang_label_repository.dart';
import '../view_model/barang_dagang_label_view_model.dart';
import '../widgets/barang_dagang_action_bar.dart';
import '../widgets/barang_dagang_delete_dialog.dart';
import '../widgets/barang_dagang_detail_dialog.dart';
import '../widgets/barang_dagang_edit_dialog.dart';
import '../widgets/barang_dagang_header_table.dart';
import '../widgets/barang_dagang_row_popover.dart';

class BarangDagangScreen extends StatefulWidget {
  const BarangDagangScreen({super.key, this.repository});

  final BarangDagangLabelRepository? repository;

  @override
  State<BarangDagangScreen> createState() => _BarangDagangScreenState();
}

class _BarangDagangScreenState extends State<BarangDagangScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;

  final InteractivePopover _popover = InteractivePopover();

  late final BarangDagangLabelViewModel vm;

  bool _isDeleteBlocked(BarangDagangLabel item) => item.used;

  Future<void> _onEditLabel(BarangDagangLabel item) async {
    if (item.used) {
      await DialogService.instance.showError(
        title: 'Edit Tidak Tersedia',
        message:
            'Label ini tidak dapat diedit karena telah dipakai.',
      );
      return;
    }
    if (item.printCount > 0) {
      await DialogService.instance.showError(
        title: 'Edit Tidak Tersedia',
        message:
            'Label ini tidak dapat diedit karena sudah dicetak.',
      );
      return;
    }

    _showEditDialog(item);
  }

  Future<void> _onDeleteLabel(BarangDagangLabel item) async {
    if (_isDeleteBlocked(item)) {
      await DialogService.instance.showError(
        title: 'Delete Tidak Tersedia',
        message:
            'Label ini tidak dapat dihapus karena telah dipakai.',
      );
      return;
    }

    _confirmDelete(item);
  }

  @override
  void initState() {
    super.initState();
    vm = BarangDagangLabelViewModel(
      repository: widget.repository ??
          BarangDagangLabelRepository(api: context.read<ApiClient>()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<PermissionViewModel>().can('label_barangdagang:read')) {
        return;
      }
      vm.resetForScreen();
      unawaited(vm.fetchHeaders());
      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor('barang_dagang');
      _syncQueue!.addListener(_onSyncQueueChanged);
    });
  }

  @override
  void dispose() {
    _syncQueue?.removeListener(_onSyncQueueChanged);
    _popover.dispose();
    searchCtrl.dispose();
    _debounce?.cancel();
    vm.dispose();
    super.dispose();
  }

  void _onSyncQueueChanged() {
    if (!mounted || _syncQueue == null) return;
    final now = _syncQueue!.pendingCountFor('barang_dagang');

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sinkronisasi print barang dagang tertunda ($now)'),
        ),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi print barang dagang selesai')),
      );
    }

    _lastPendingCount = now;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) unawaited(vm.fetchHeaders(search: query));
    });
  }

  void _showEditDialog(BarangDagangLabel item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => BarangDagangEditDialog(item: item, viewModel: vm),
    );
  }

  void _showDetailDialog(BarangDagangLabel item) {
    if (!context.read<PermissionViewModel>().can('label_barangdagang:read')) {
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => BarangDagangDetailDialog(
        label: item,
        repository: vm.repository,
        onPrinted: () {
          if (mounted) unawaited(vm.refreshCurrent());
        },
      ),
    );
  }

  void _confirmDelete(BarangDagangLabel item) {
    showDialog(
      context: context,
      builder: (_) => BarangDagangDeleteDialog(
        item: item,
        onConfirm: () async {
          // showDialog di-push ke root Navigator (default useRootNavigator: true),
          // sedangkan layar ini hidup di shell Navigator milik AppShell yang hanya
          // punya SATU route - Navigator.of(context).pop() polos resolve ke shell
          // Navigator dan jadi no-op, sehingga dialog konfirmasi tidak pernah tertutup.
          Navigator.of(context, rootNavigator: true).pop();
          await _handleDelete(item);
        },
      ),
    );
  }

  Future<void> _handleDelete(BarangDagangLabel item) async {
    final code = item.code;

    try {
      DialogService.instance.showLoading(message: 'Deleting $code...');
      await vm.deleteBarangDagang(code);
      DialogService.instance.hideLoading();

      await DialogService.instance.showSuccess(
        title: 'Deleted',
        message: 'Label $code has been deleted.',
      );

      vm.setSelected(null);
    } catch (e) {
      DialogService.instance.hideLoading();
      await DialogService.instance.showError(
        title: 'Failed',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void _closeContextMenu() {
    _popover.hide();
  }

  Future<void> _onItemLongPress(
    BarangDagangLabel item,
    Offset globalPosition,
  ) async {
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(480.0, 820.0).toDouble();

    vm.setSelected(item.code);

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: BarangDagangRowPopover(
        item: item,
        onClose: _closeContextMenu,
        onDetail: () {
          _closeContextMenu();
          _showDetailDialog(item);
        },
        onEdit: () async {
          _closeContextMenu();
          await _onEditLabel(item);
        },
        onDelete: () async {
          if (vm.isLoading) return;
          _closeContextMenu();
          await _onDeleteLabel(item);
        },
        onAuditHistory: () {
          _closeContextMenu();
          _navigateToAuditHistory(item);
        },
        onPrinted: () {
          if (mounted) unawaited(vm.refreshCurrent());
        },
      ),
      preferAbove: true,
      verticalGap: 8,
      maxHeight: adaptiveMaxHeight,
      backdropOpacity: 0.06,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      startScale: 0.94,
    );
  }

  void _navigateToAuditHistory(BarangDagangLabel item) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AuditScreenWithPrefilledDoc(documentNo: item.code),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<PermissionViewModel>().can('label_barangdagang:read')) {
      return const Scaffold(
        body: Center(
          child: Text('Anda tidak memiliki akses ke Label Barang Dagang.'),
        ),
      );
    }
    return Scaffold(
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Container(
                color: Colors.white,
                child: Column(
                  children: [
                    Consumer<LabelPrintSyncQueue>(
                      builder: (_, syncQueue, __) {
                        final pending =
                            syncQueue.pendingCountFor('barang_dagang');
                        if (pending <= 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Tooltip(
                              message:
                                  'Sinkronisasi print barang dagang tertunda ($pending)',
                              child: const Icon(
                                Icons.sync,
                                color: Color(0xFFFFE082),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Consumer<BarangDagangLabelViewModel>(
                      builder: (_, vm, __) => BarangDagangActionBar(
                        controller: searchCtrl,
                        onSearchChanged: _onSearchChanged,
                        onClear: () {
                          searchCtrl.clear();
                          vm.fetchHeaders(search: '');
                        },
                        includeUsed: vm.includeUsed,
                        onIncludeUsedChanged: vm.setIncludeUsed,
                      ),
                    ),
                    Expanded(
                      child: Consumer<BarangDagangLabelViewModel>(
                        builder: (context, vm, _) {
                          return BarangDagangHeaderTable(
                            pagingController: vm.pagingController,
                            selectedNoLabel: vm.selectedNoLabel,
                            onItemTap: (item) {
                              vm.setSelected(item.code);
                            },
                            onItemLongPress: _onItemLongPress,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
