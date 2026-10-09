import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/interactive_popover.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../view_model/bonggolan_view_model.dart';
import '../model/bonggolan_header_model.dart';
import '../widgets/bonggolan_row_popover.dart';
import '../widgets/bonggolan_action_bar.dart';
import '../widgets/bonggolan_header_table.dart';
import '../widgets/bonggolan_form_dialog.dart';
import '../widgets/bonggolan_delete_dialog.dart';

class BonggolanScreen extends StatefulWidget {
  const BonggolanScreen({super.key});

  @override
  State<BonggolanScreen> createState() => _BonggolanScreenState();
}

class _BonggolanScreenState extends State<BonggolanScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  bool _isLoadingMore = false;
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;

  final InteractivePopover _popover = InteractivePopover();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BonggolanViewModel>().fetchHeaders();
      context.read<BonggolanViewModel>().resetForScreen();
      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor('bonggolan');
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
    final now = _syncQueue!.pendingCountFor('bonggolan');

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinkronisasi print bonggolan tertunda ($now)')),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi print bonggolan selesai')),
      );
    }

    _lastPendingCount = now;
  }

  void _onScroll() {
    if (_popover.isShown) {
      _popover.hide();
    }

    final vm = context.read<BonggolanViewModel>();
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
      context.read<BonggolanViewModel>().fetchHeaders(search: query);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _showFormDialog({BonggolanHeader? header}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => BonggolanFormDialog(
        header: header,
        onSave: (headerData) {
          if (header != null) {
            // vm.update
          } else {
            // vm.create
          }
        },
      ),
    );
  }

  void _confirmDelete(BonggolanHeader header) {
    showDialog(
      context: context,
      builder: (_) => BonggolanDeleteDialog(
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
    BonggolanHeader header,
    Offset globalPosition,
  ) async {
    final vm = context.read<BonggolanViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(480.0, 820.0).toDouble();

    vm.setSelected(header.noBonggolan);

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: BonggolanRowPopover(
        header: header,
        onClose: _closeContextMenu,
        onEdit: () {
          _closeContextMenu();
          _showFormDialog(header: header);
        },
        onDelete: () {
          if (context.read<BonggolanViewModel>().isLoading) return;
          _closeContextMenu();
          _confirmDelete(header);
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

  void _navigateToAuditHistory(BonggolanHeader header) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AuditScreenWithPrefilledDoc(documentNo: header.noBonggolan),
      ),
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
                      final pending = syncQueue.pendingCountFor('bonggolan');
                      if (pending <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: 'Sinkronisasi print bonggolan tertunda ($pending)',
                            child: const Icon(Icons.sync, color: Color(0xFFFFE082)),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<BonggolanViewModel>(
                    builder: (_, vm, __) => BonggolanActionBar(
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
                    child: BonggolanHeaderTable(
                      scrollController: _scrollController,
                      onItemTap: (header) {
                        final vm = context.read<BonggolanViewModel>();
                        vm.setSelected(header.noBonggolan);
                      },
                      onItemLongPress: _onItemLongPress,
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

  Future<void> _handleDelete(BonggolanHeader header) async {
    final vm = context.read<BonggolanViewModel>();
    final no = header.noBonggolan;

    try {
      DialogService.instance.showLoading(message: 'Menghapus $no...');
      await vm.deleteBonggolan(no);
      DialogService.instance.hideLoading();

      await DialogService.instance.showSuccess(
        title: 'Terhapus',
        message: 'Label $no berhasil dihapus.',
      );

      vm.setSelected(null);
      if (_detailScrollController.hasClients) {
        _detailScrollController.jumpTo(0);
      }
    } catch (e) {
      DialogService.instance.hideLoading();
      await DialogService.instance.showError(
        title: 'Gagal',
        message: vm.errorMessage.isNotEmpty ? vm.errorMessage : e.toString(),
      );
    }
  }
}
