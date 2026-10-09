import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/interactive_popover.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../model/gilingan_header_model.dart';
import '../view_model/gilingan_view_model.dart';
import '../widgets/gilingan_action_bar.dart';
import '../widgets/gilingan_delete_dialog.dart';
import '../widgets/gilingan_form_dialog.dart';
import '../widgets/gilingan_header_table.dart';
import '../widgets/gilingan_partial_info_popover.dart';
import '../widgets/gilingan_row_popover.dart';

class GilinganScreen extends StatefulWidget {
  const GilinganScreen({super.key});

  @override
  State<GilinganScreen> createState() => _GilinganScreenState();
}

class _GilinganScreenState extends State<GilinganScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  bool _isLoadingMore = false;
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;

  final InteractivePopover _popover = InteractivePopover();

  bool _isPartialHeader(GilinganHeader h) {
    return h.isPartial == 1;
  }

  Future<void> _onEditHeader(GilinganHeader header) async {
    if (_isPartialHeader(header)) {
      await DialogService.instance.showError(
        title: 'Edit Tidak Tersedia',
        message: 'Label ini tidak dapat diedit karena telah di partial.',
      );
      return;
    }

    _showFormDialog(header: header);
  }

  Future<void> _onDeleteHeader(GilinganHeader header) async {
    if (_isPartialHeader(header)) {
      await DialogService.instance.showError(
        title: 'Hapus Tidak Tersedia',
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
      final vm = context.read<GilinganViewModel>();
      vm.fetchHeaders();
      vm.resetForScreen();
      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor('gilingan');
      _syncQueue!.addListener(_onSyncQueueChanged);
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _syncQueue?.removeListener(_onSyncQueueChanged);
    _popover.dispose();
    _scrollController.dispose();
    _detailScrollController.dispose();
    searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSyncQueueChanged() {
    if (!mounted || _syncQueue == null) return;
    final now = _syncQueue!.pendingCountFor('gilingan');

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinkronisasi print gilingan tertunda ($now)')),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi print gilingan selesai')),
      );
    }

    _lastPendingCount = now;
  }

  void _onScroll() {
    if (_popover.isShown) {
      _popover.hide();
    }

    final vm = context.read<GilinganViewModel>();
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoadingMore && vm.hasMore) {
        _isLoadingMore = true;
        vm.loadMore().then((_) {
          if (mounted) {
            setState(() {
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<GilinganViewModel>().fetchHeaders(search: query);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _showFormDialog({GilinganHeader? header}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => GilinganFormDialog(header: header),
    );
  }

  void _confirmDelete(GilinganHeader header) {
    showDialog(
      context: context,
      builder: (_) => GilinganDeleteDialog(
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
    GilinganHeader header,
    Offset globalPosition,
  ) async {
    final vm = context.read<GilinganViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(480.0, 820.0).toDouble();

    vm.setSelected(header.noGilingan);

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: GilinganRowPopover(
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
          if (context.read<GilinganViewModel>().isLoading) return;
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

  void _navigateToAuditHistory(GilinganHeader header) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AuditScreenWithPrefilledDoc(documentNo: header.noGilingan),
      ),
    );
  }

  Future<void> _showPartialInfoPopover(
    GilinganHeader header,
  ) async {
    final vm = context.read<GilinganViewModel>();
    final size = MediaQuery.of(context).size;
    final defaultPos = Offset(size.width * 0.5, size.height * 0.3);

    vm.setSelected(header.noGilingan);

    await showGilinganPartialInfoPopover(
      context: context,
      vm: vm,
      noGilingan: header.noGilingan,
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
                      final pending = syncQueue.pendingCountFor('gilingan');
                      if (pending <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: 'Sinkronisasi print gilingan tertunda ($pending)',
                            child: const Icon(Icons.sync, color: Color(0xFFFFE082)),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<GilinganViewModel>(
                    builder: (_, vm, __) => GilinganActionBar(
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
                    child: GilinganHeaderTable(
                      scrollController: _scrollController,
                      onItemTap: (header) {
                        final vm = context.read<GilinganViewModel>();
                        vm.setSelected(header.noGilingan);
                      },
                      onItemLongPress: _onItemLongPress,
                      onPartialTap: (header, _) {
                        context.read<GilinganViewModel>().setSelected(
                          header.noGilingan,
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

  Future<void> _handleDelete(GilinganHeader header) async {
    final vm = context.read<GilinganViewModel>();
    final no = header.noGilingan;

    try {
      DialogService.instance.showLoading(message: 'Deleting $no...');
      await vm.deleteGilingan(no);
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
