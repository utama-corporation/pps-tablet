import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/interactive_popover.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/view_model/label_qc_socket_manager.dart';
import '../view_model/washing_view_model.dart';
import '../model/washing_header_model.dart';
import '../model/washing_detail_model.dart';
import '../widgets/washing_row_popover.dart';
import '../widgets/washing_action_bar.dart';
import '../widgets/washing_header_table.dart';
import '../widgets/washing_detail_table.dart';
import '../widgets/washing_form_dialog.dart';
import '../widgets/washing_delete_dialog.dart';
import '../widgets/washing_qc_dialog.dart';

class WashingTableScreen extends StatefulWidget {
  const WashingTableScreen({super.key});

  @override
  State<WashingTableScreen> createState() => _WashingTableScreenState();
}

class _WashingTableScreenState extends State<WashingTableScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  bool _isLoadingMore = false;
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;
  VoidCallback? _unsubscribeQcUpdated;

  // Popover animasi (custom)
  final InteractivePopover _popover = InteractivePopover();

  bool _isUsed(String? dateUsage) {
    final s = (dateUsage ?? '').trim();
    if (s.isEmpty) return false;
    if (s.toLowerCase() == 'null') return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vm = context.read<WashingViewModel>();
      vm.resetForScreen();
      vm.fetchWashingHeaders();

      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor('washing');
      _syncQueue!.addListener(_onSyncQueueChanged);

      _unsubscribeQcUpdated = context
          .read<LabelQcSocketManager>()
          .addQcUpdatedListener(_onQcRealtime);
    });
    _scrollController.addListener(_onScroll);
  }

  /// QC disimpan dari tablet lain — patch baris yang sedang tampil.
  void _onQcRealtime(LabelQcUpdatedEvent event) {
    if (!mounted) return;
    final applied = context.read<WashingViewModel>().applyQcRealtime(event);
    if (!applied) return;

    final by = (event.updatedBy ?? '').trim();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            'QC ${event.noLabel} diperbarui'
            '${by.isEmpty ? '' : ' oleh $by'}',
          ),
        ),
      );
  }

  @override
  void dispose() {
    _unsubscribeQcUpdated?.call();
    _syncQueue?.removeListener(_onSyncQueueChanged);
    _popover.dispose();
    _scrollController.dispose();
    _detailScrollController.dispose();
    searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _closeContextMenu() => _popover.hide();

  void _onSyncQueueChanged() {
    if (!mounted || _syncQueue == null) return;
    final now = _syncQueue!.pendingCountFor('washing');

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinkronisasi print tertunda ($now)')),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi print selesai')),
      );
    }

    _lastPendingCount = now;
  }

  void _onScroll() {
    if (_popover.isShown) _popover.hide();

    final vm = context.read<WashingViewModel>();
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 100) {
      if (!_isLoadingMore && vm.hasMore) {
        _isLoadingMore = true;
        vm.loadMore().then((_) {
          if (!mounted) return;
          setState(() => _isLoadingMore = false);
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<WashingViewModel>().fetchWashingHeaders(search: query);
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _showFormDialog({WashingHeader? header, List<WashingDetail>? details}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => WashingFormDialog(
        header: header,
        details: details,
        onSave: (headerData, detailsData) {},
      ),
    );
  }

  Future<void> _onEditHeader(WashingHeader header) async {
    final vm = context.read<WashingViewModel>();

    vm.setSelectedNoWashing(header.noWashing);

    DialogService.instance.showLoading(
      message: 'Cek detail ${header.noWashing}...',
    );
    await vm.fetchDetails(header.noWashing);
    DialogService.instance.hideLoading();

    if (!mounted) return;

    final hasUsed = vm.details.any((d) => _isUsed(d.dateUsage));
    if (hasUsed) {
      await DialogService.instance.showError(
        title: 'Edit tidak tersedia',
        message: 'Tidak bisa edit karena ada Sak yang sudah dipakai',
      );
      return;
    }

    _showFormDialog(header: header, details: vm.details);
  }

  Future<void> _onDeleteHeader(WashingHeader header) async {
    final vm = context.read<WashingViewModel>();

    vm.setSelectedNoWashing(header.noWashing);

    DialogService.instance.showLoading(
      message: 'Cek detail ${header.noWashing}...',
    );
    await vm.fetchDetails(header.noWashing);
    DialogService.instance.hideLoading();

    if (!mounted) return;

    final hasUsed = vm.details.any((d) => _isUsed(d.dateUsage));
    if (hasUsed) {
      await DialogService.instance.showError(
        title: 'Hapus tidak tersedia',
        message: 'Tidak bisa hapus karena ada Sak yang sudah dipakai',
      );
      return;
    }

    _confirmDelete(header);
  }

  Future<void> _onQcHeader(WashingHeader header) async {
    final vm = context.read<WashingViewModel>();
    vm.setSelectedNoWashing(header.noWashing);

    final qc = await showDialog<WashingQcResult>(
      context: context,
      builder: (_) => WashingQcDialog(header: header),
    );

    if (!mounted || qc == null) return;

    DialogService.instance.showLoading(
      message: 'Menyimpan QC ${header.noWashing}...',
    );

    final res = await vm.updateWashingQc(
      noWashing: header.noWashing,
      density1: qc.density1,
      density2: qc.density2,
      density3: qc.density3,
      moisture1: qc.moisture1,
      moisture2: qc.moisture2,
      moisture3: qc.moisture3,
      dateQc: qc.dateQc,
    );

    DialogService.instance.hideLoading();
    if (!mounted) return;

    if (res != null) {
      await DialogService.instance.showSuccess(
        title: 'QC Tersimpan',
        message:
            'Nilai QC untuk ${header.noWashing} berhasil diperbarui '
            '(tanggal ${formatDateToShortId(qc.dateQc)}).',
      );
    } else {
      await DialogService.instance.showError(
        title: 'Gagal',
        message: vm.errorMessage.isNotEmpty
            ? vm.errorMessage
            : 'Tidak dapat memperbarui data QC.',
      );
    }
  }

  void _confirmDelete(WashingHeader header) {
    showDialog(
      context: context,
      builder: (_) => WashingDeleteDialog(
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

  Future<void> _handleDelete(WashingHeader header) async {
    final vm = context.read<WashingViewModel>();
    final noWashing = header.noWashing;

    DialogService.instance.showLoading(message: 'Menghapus $noWashing...');
    final ok = await vm.deleteWashing(noWashing);
    DialogService.instance.hideLoading();

    if (!mounted) return;

    if (ok) {
      await DialogService.instance.showSuccess(
        title: 'Terhapus',
        message: 'Label $noWashing berhasil dihapus.',
      );
      vm.setSelectedNoWashing(null);
    } else {
      await DialogService.instance.showError(
        title: 'Gagal',
        message: vm.errorMessage.isNotEmpty
            ? vm.errorMessage
            : 'Tidak dapat menghapus label.',
      );
    }
  }

  /// Long-press handler: pindahkan highlight ke item & tampilkan popover.
  Future<void> _onItemLongPress(
    WashingHeader header,
    Offset globalPosition,
  ) async {
    final vm = context.read<WashingViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight = (screenHeight - 32)
        .clamp(480.0, 820.0)
        .toDouble();
    vm.setSelectedNoWashing(header.noWashing);

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: WashingRowPopover(
        header: header,
        onClose: _closeContextMenu,
        onEdit: () async {
          _closeContextMenu();
          await _onEditHeader(header);
        },
        onDelete: () async {
          if (context.read<WashingViewModel>().isLoading) return;
          _closeContextMenu();
          await _onDeleteHeader(header);
        },
        onPrint: () {
          _closeContextMenu();
          // TODO: print/preview
        },
        onAuditHistory: () {
          _closeContextMenu();
          _navigateToAuditHistory(header);
        },
        onQc: () async {
          _closeContextMenu();
          await _onQcHeader(header);
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

  void _navigateToAuditHistory(WashingHeader header) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AuditScreenWithPrefilledDoc(documentNo: header.noWashing),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Master Table
          Expanded(
            flex: 4,
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Consumer<LabelPrintSyncQueue>(
                    builder: (_, syncQueue, __) {
                      final pending = syncQueue.pendingCountFor('washing');
                      if (pending <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: 'Sinkronisasi print tertunda ($pending)',
                            child: const Icon(Icons.sync, color: Color(0xFFFFE082)),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<WashingViewModel>(
                    builder: (_, vm, __) => WashingActionBar(
                      controller: searchCtrl,
                      onSearchChanged: _onSearchChanged,
                      onClear: () {
                        searchCtrl.clear();
                        vm.fetchWashingHeaders(search: "");
                      },
                      onAddPressed: _showFormDialog,
                      includeUsed: vm.includeUsed,
                      onIncludeUsedChanged: vm.setIncludeUsed,
                    ),
                  ),
                  Expanded(
                    child: WashingHeaderTable(
                      scrollController: _scrollController,
                      onItemTap: (header) {
                        final vm = context.read<WashingViewModel>();
                        vm.setSelectedNoWashing(header.noWashing);
                        vm.fetchDetails(header.noWashing);
                      },
                      onItemLongPress: _onItemLongPress,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Container(width: 2, color: Colors.grey.shade300),

          // Detail Panel
          Expanded(
            flex: 1,
            child: WashingDetailTable(
              scrollController: _detailScrollController,
            ),
          ),
        ],
      ),
    );
  }
}
