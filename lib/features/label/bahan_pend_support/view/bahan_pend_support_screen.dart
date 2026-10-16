// lib/features/label/bahan_pend_support/view/bahan_pend_support_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/interactive_popover.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';

import '../model/bahan_pend_support_header_model.dart';
import '../repository/bahan_pend_support_repository.dart';
import '../view_model/bahan_pend_support_view_model.dart';
import '../widgets/bahan_pend_support_action_bar.dart';
import '../widgets/bahan_pend_support_delete_dialog.dart';
import '../widgets/bahan_pend_support_header_table.dart';
import '../widgets/bahan_pend_support_row_popover.dart';

/// Layar Label Bahan Pendukung (`BP.`).
///
/// Backend tidak menyediakan endpoint create untuk BP., jadi layar ini tidak
/// punya tombol "Buat Baru" — label dibuat dari menu Penerimaan Bahan
/// Pendukung. Aksi yang tersedia: browse/search, print, dan delete.
class BahanPendukungScreen extends StatefulWidget {
  const BahanPendukungScreen({super.key});

  @override
  State<BahanPendukungScreen> createState() => _BahanPendukungScreenState();
}

class _BahanPendukungScreenState extends State<BahanPendukungScreen> {
  /// Key feature untuk LabelPrintSyncQueue.
  static const _queueFeature = 'bahan_pendukung';

  final TextEditingController searchCtrl = TextEditingController();
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;

  final InteractivePopover _popover = InteractivePopover();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final vm = context.read<BahanPendukungViewModel>();
      vm.resetForScreen();
      vm.fetchHeaders();
      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor(_queueFeature);
      _syncQueue!.addListener(_onSyncQueueChanged);
    });
  }

  @override
  void dispose() {
    _syncQueue?.removeListener(_onSyncQueueChanged);
    _popover.dispose();
    searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSyncQueueChanged() {
    if (!mounted || _syncQueue == null) return;
    final now = _syncQueue!.pendingCountFor(_queueFeature);

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sinkronisasi print bahan pendukung tertunda ($now)',
          ),
        ),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi print bahan pendukung selesai')),
      );
    }

    _lastPendingCount = now;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      context.read<BahanPendukungViewModel>().fetchHeaders(search: query);
    });
  }

  void _closeContextMenu() => _popover.hide();

  Future<void> _onItemLongPress(
    BahanPendukungHeader header,
    Offset globalPosition,
  ) async {
    final vm = context.read<BahanPendukungViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(480.0, 820.0).toDouble();

    vm.setSelected(header.noBahanPendukung);

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: BahanPendukungRowPopover(
        header: header,
        onClose: _closeContextMenu,
        onDelete: () {
          if (vm.isDeleting) return;
          _closeContextMenu();
          _confirmDelete(header);
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

  void _navigateToAuditHistory(BahanPendukungHeader header) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            AuditScreenWithPrefilledDoc(documentNo: header.noBahanPendukung),
      ),
    );
  }

  void _confirmDelete(BahanPendukungHeader header) {
    showDialog(
      context: context,
      builder: (_) => BahanPendukungDeleteDialog(
        header: header,
        onConfirm: () async {
          // Dialog ini dipush ke root Navigator, sedangkan layar ini hidup di
          // shell Navigator milik AppShell yang hanya punya SATU route —
          // Navigator.pop() polos akan resolve ke shell dan jadi no-op.
          Navigator.of(context, rootNavigator: true).pop();
          await _handleDelete(header);
        },
      ),
    );
  }

  Future<void> _handleDelete(BahanPendukungHeader header) async {
    final vm = context.read<BahanPendukungViewModel>();
    final no = header.noBahanPendukung;

    try {
      DialogService.instance.showLoading(message: 'Menghapus $no...');
      await vm.deleteLabel(no);
      DialogService.instance.hideLoading();

      await DialogService.instance.showSuccess(
        title: 'Terhapus',
        message: 'Label $no berhasil dihapus.',
      );
    } catch (e) {
      DialogService.instance.hideLoading();
      await DialogService.instance.showError(
        title: 'Gagal',
        message: vm.errorMessage.isNotEmpty
            ? vm.errorMessage
            : bahanPendukungDeleteErrorMessage(e),
      );
      // Muat ulang supaya baris yang gagal dihapus kembali ke posisi & flag
      // terpakainya yang benar.
      if (mounted) await vm.refreshCurrent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  Consumer<LabelPrintSyncQueue>(
                    builder: (_, syncQueue, __) {
                      final pending = syncQueue.pendingCountFor(_queueFeature);
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
                                'Sinkronisasi print bahan pendukung tertunda ($pending)',
                            child: const Icon(
                              Icons.sync,
                              color: Color(0xFFFFE082),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<BahanPendukungViewModel>(
                    builder: (_, vm, __) => BahanPendukungActionBar(
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
                    child: BahanPendukungHeaderTable(
                      onItemTap: (header) => context
                          .read<BahanPendukungViewModel>()
                          .setSelected(header.noBahanPendukung),
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
}