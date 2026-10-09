import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/interactive_popover.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../model/furniture_wip_header_model.dart';
import '../view_model/furniture_wip_view_model.dart';
import '../widgets/furniture_wip_action_bar.dart';
import '../widgets/furniture_wip_delete_dialog.dart';
import '../widgets/furniture_wip_form_dialog.dart';
import '../widgets/furniture_wip_header_table.dart';
import '../widgets/furniture_wip_partial_info_popover.dart';
import '../widgets/furniture_wip_row_popover.dart';

class FurnitureWipScreen extends StatefulWidget {
  const FurnitureWipScreen({super.key});

  @override
  State<FurnitureWipScreen> createState() => _FurnitureWipScreenState();
}

class _FurnitureWipScreenState extends State<FurnitureWipScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController _detailScrollController = ScrollController();
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;

  final InteractivePopover _popover = InteractivePopover();

  bool _isPartialHeader(FurnitureWipHeader h) {
    return h.isPartial == 1;
  }

  Future<void> _onEditHeader(FurnitureWipHeader header) async {
    if (_isPartialHeader(header)) {
      await DialogService.instance.showError(
        title: 'Tidak bisa edit',
        message:
            'Label ${header.noFurnitureWip} tidak bisa diedit karena statusnya PARTIAL.',
      );
      return;
    }

    _showFormDialog(header: header);
  }

  Future<void> _onDeleteHeader(FurnitureWipHeader header) async {
    if (_isPartialHeader(header)) {
      await DialogService.instance.showError(
        title: 'Tidak bisa hapus',
        message:
            'Label ${header.noFurnitureWip} tidak bisa dihapus karena statusnya PARTIAL.',
      );
      return;
    }

    _confirmDelete(header);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<FurnitureWipViewModel>();
      vm.resetForScreen();
      vm.fetchHeaders();
      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor('furniture_wip');
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
    final now = _syncQueue!.pendingCountFor('furniture_wip');

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sinkronisasi print furniture wip tertunda ($now)'),
        ),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi print furniture wip selesai'),
        ),
      );
    }

    _lastPendingCount = now;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<FurnitureWipViewModel>().fetchHeaders(search: query);
    });
  }

  void _showFormDialog({FurnitureWipHeader? header}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => FurnitureWipFormDialog(header: header),
    );
  }

  void _confirmDelete(FurnitureWipHeader header) {
    showDialog(
      context: context,
      builder: (_) => FurnitureWipDeleteDialog(
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

  void _closeContextMenu() {
    _popover.hide();
  }

  Future<void> _onItemLongPress(
    FurnitureWipHeader header,
    Offset globalPosition,
  ) async {
    final vm = context.read<FurnitureWipViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight = (screenHeight - 32)
        .clamp(480.0, 820.0)
        .toDouble();

    vm.setSelected(header.noFurnitureWip);

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: FurnitureWipRowPopover(
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
          if (context.read<FurnitureWipViewModel>().isLoading) return;
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

  void _navigateToAuditHistory(FurnitureWipHeader header) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AuditScreenWithPrefilledDoc(documentNo: header.noFurnitureWip),
      ),
    );
  }

  Future<void> _showPartialInfoPopover(FurnitureWipHeader header) async {
    final vm = context.read<FurnitureWipViewModel>();

    vm.setSelected(header.noFurnitureWip);

    final size = MediaQuery.of(context).size;
    final defaultPos = Offset(size.width * 0.5, size.height * 0.3);

    await showFurnitureWipPartialInfoPopover(
      context: context,
      vm: vm,
      noFurnitureWip: header.noFurnitureWip,
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
                      final pending = syncQueue.pendingCountFor('furniture_wip');
                      if (pending <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: 'Sinkronisasi print furniture wip tertunda ($pending)',
                            child: const Icon(Icons.sync, color: Color(0xFFFFE082)),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<FurnitureWipViewModel>(
                    builder: (_, vm, __) => FurnitureWipActionBar(
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
                    child: Consumer<FurnitureWipViewModel>(
                      builder: (context, vm, _) {
                        return FurnitureWipHeaderTable(
                          pagingController: vm.pagingController,
                          selectedNoFurnitureWip: vm.selectedNoFurnitureWip,
                          onItemTap: (header) {
                            vm.setSelected(header.noFurnitureWip);
                          },
                          onItemLongPress: _onItemLongPress,
                          onPartialTap: (header) {
                            vm.setSelected(header.noFurnitureWip);
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

  Future<void> _handleDelete(FurnitureWipHeader header) async {
    final vm = context.read<FurnitureWipViewModel>();
    final no = header.noFurnitureWip;

    try {
      DialogService.instance.showLoading(message: 'Deleting $no...');
      await vm.deleteFurnitureWip(no);
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
}
