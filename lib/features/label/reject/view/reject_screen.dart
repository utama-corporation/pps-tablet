import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/interactive_popover.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../model/reject_header_model.dart';
import '../view_model/reject_view_model.dart';
import '../widgets/reject_action_bar.dart';
import '../widgets/reject_delete_dialog.dart';
import '../widgets/reject_form_dialog.dart';
import '../widgets/reject_header_table.dart';
import '../widgets/reject_partial_info_popover.dart';
import '../widgets/reject_row_popover.dart';

class RejectScreen extends StatefulWidget {
  const RejectScreen({super.key});

  @override
  State<RejectScreen> createState() => _RejectScreenState();
}

class _RejectScreenState extends State<RejectScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController _detailScrollController = ScrollController();
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;

  final InteractivePopover _popover = InteractivePopover();

  bool _isPartialHeader(RejectHeader h) {
    return h.isPartial == 1;
  }

  Future<void> _onEditHeader(RejectHeader header) async {
    if (_isPartialHeader(header)) {
      await DialogService.instance.showError(
        title: 'Edit Tidak Tersedia',
        message: 'Label ini tidak dapat diedit karena telah di partial.',
      );
      return;
    }

    _showFormDialog(header: header);
  }

  Future<void> _onDeleteHeader(RejectHeader header) async {
    if (_isPartialHeader(header)) {
      await DialogService.instance.showError(
        title: 'Delete Tidak Tersedia',
        message: 'Label ini tidak dapat dihapus karena telah di partial.',
      );
      return;
    }

    _confirmDelete(header);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<RejectViewModel>();
      vm.resetForScreen();
      vm.fetchHeaders();
      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor('reject');
      _syncQueue!.addListener(_onSyncQueueChanged);
    });
  }

  @override
  void dispose() {
    _syncQueue?.removeListener(_onSyncQueueChanged);
    _popover.dispose();
    _detailScrollController.dispose();
    searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSyncQueueChanged() {
    if (!mounted || _syncQueue == null) return;
    final now = _syncQueue!.pendingCountFor('reject');

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinkronisasi print reject tertunda ($now)')),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi print reject selesai')),
      );
    }

    _lastPendingCount = now;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<RejectViewModel>().fetchHeaders(search: query);
    });
  }

  void _showFormDialog({RejectHeader? header}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => RejectFormDialog(header: header),
    );
  }

  void _confirmDelete(RejectHeader header) {
    showDialog(
      context: context,
      builder: (_) => RejectDeleteDialog(
        header: header,
        onConfirm: () async {
          // showDialog di-push ke root Navigator (default useRootNavigator: true),
          // sedangkan layar ini hidup di shell Navigator milik AppShell yang hanya
          // punya SATU route - Navigator.of(context).pop() polos resolve ke shell
          // Navigator dan jadi no-op, sehingga dialog konfirmasi tidak pernah tertutup.
          Navigator.of(context, rootNavigator: true).pop();
          await _handleDelete(header);
        },
      ),
    );
  }

  Future<void> _handleDelete(RejectHeader header) async {
    final vm = context.read<RejectViewModel>();
    final no = header.noReject;

    try {
      DialogService.instance.showLoading(message: 'Deleting $no...');
      await vm.deleteReject(no);
      DialogService.instance.hideLoading();

      await DialogService.instance.showSuccess(
        title: 'Deleted',
        message: 'Label $no has been deleted.',
      );

      vm.setSelected(null);
      if (_detailScrollController.hasClients) {
        _detailScrollController.jumpTo(0);
      }
    } catch (e) {
      DialogService.instance.hideLoading();
      await DialogService.instance.showError(
        title: 'Failed',
        message: vm.errorMessage.isNotEmpty ? vm.errorMessage : e.toString(),
      );
    }
  }

  void _closeContextMenu() {
    _popover.hide();
  }

  Future<void> _onItemLongPress(
    RejectHeader header,
    Offset globalPosition,
  ) async {
    final vm = context.read<RejectViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(480.0, 820.0).toDouble();

    vm.setSelected(header.noReject);

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: RejectRowPopover(
        header: header,
        onClose: _closeContextMenu,
        onPartialInfo: () async {
          _closeContextMenu();
          await _showPartialInfoPopover(header);
        },
        onEdit: () async {
          _closeContextMenu();
          await _onEditHeader(header);
        },
        onDelete: () async {
          if (context.read<RejectViewModel>().isLoading) return;
          _closeContextMenu();
          await _onDeleteHeader(header);
        },
        onPrint: () {
          _closeContextMenu();
        },
        onAuditHistory: () {
          _closeContextMenu();
          _navigateToAuditHistory(header);
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

  void _navigateToAuditHistory(RejectHeader header) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AuditScreenWithPrefilledDoc(documentNo: header.noReject),
      ),
    );
  }

  Future<void> _showPartialInfoPopover(RejectHeader header) async {
    final vm = context.read<RejectViewModel>();

    final size = MediaQuery.of(context).size;
    final defaultPos = Offset(size.width * 0.5, size.height * 0.3);

    vm.setSelected(header.noReject);

    await showRejectPartialInfoPopover(
      context: context,
      vm: vm,
      noReject: header.noReject,
      popover: _popover,
      globalPosition: defaultPos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Consumer<LabelPrintSyncQueue>(
                    builder: (_, syncQueue, __) {
                      final pending = syncQueue.pendingCountFor('reject');
                      if (pending <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: 'Sinkronisasi print reject tertunda ($pending)',
                            child: const Icon(Icons.sync, color: Color(0xFFFFE082)),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<RejectViewModel>(
                    builder: (_, vm, __) => RejectActionBar(
                      controller: searchCtrl,
                      onSearchChanged: _onSearchChanged,
                      onClear: () {
                        searchCtrl.clear();
                        vm.fetchHeaders(search: '');
                      },
                      onAddPressed: _showFormDialog,
                      includeUsed: vm.includeUsed,
                      onIncludeUsedChanged: vm.setIncludeUsed,
                    ),
                  ),
                  Expanded(
                    child: Consumer<RejectViewModel>(
                      builder: (context, vm, _) {
                        return RejectHeaderTable(
                          pagingController: vm.pagingController,
                          selectedNoReject: vm.selectedNoReject,
                          onItemTap: (header) {
                            vm.setSelected(header.noReject);
                          },
                          onItemLongPress: _onItemLongPress,
                          onPartialTap: (header) {
                            vm.setSelected(header.noReject);
                          },
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
    );
  }
}
