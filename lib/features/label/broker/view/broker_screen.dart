import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/view_model/label_qc_socket_manager.dart';
import '../view_model/broker_view_model.dart';
import '../model/broker_header_model.dart';
import '../model/broker_detail_model.dart';
import '../widgets/broker_action_dialog.dart';
import '../widgets/broker_action_bar.dart';
import '../widgets/broker_header_table.dart';
import '../widgets/broker_detail_table.dart';
import '../widgets/broker_form_dialog.dart';
import '../widgets/broker_delete_dialog.dart';
import '../widgets/broker_qc_dialog.dart';

class BrokerScreen extends StatefulWidget {
  const BrokerScreen({super.key});

  @override
  State<BrokerScreen> createState() => _BrokerScreenState();
}

class _BrokerScreenState extends State<BrokerScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  bool _isLoadingMore = false;
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;
  VoidCallback? _unsubscribeQcUpdated;

  bool _isUsed(String? dateUsage) {
    final s = (dateUsage ?? '').trim();
    if (s.isEmpty) return false;
    if (s.toLowerCase() == 'null') return false;
    return true;
  }

  Future<void> _onEditHeader(BrokerHeader header) async {
    final vm = context.read<BrokerViewModel>();

    // pastikan selection benar
    vm.setSelectedNoBroker(header.noBroker);

    // fetch detail terbaru untuk header ini
    DialogService.instance.showLoading(
      message: 'Cek detail ${header.noBroker}...',
    );
    await vm.fetchDetails(header.noBroker);
    DialogService.instance.hideLoading();

    if (!mounted) return;

    // RULE: tidak boleh edit jika ada DateUsage terisi atau ada isPartial = true
    final hasUsed = vm.details.any((d) => _isUsed(d.dateUsage));
    final hasPartial = vm.details.any((d) => d.isPartial == true);

    if (hasUsed || hasPartial) {
      final reason = [
        if (hasUsed) 'ada Sak yang sudah dipakai',
        if (hasPartial) 'ada Sak yang telah dipartial',
      ].join(' dan ');

      await DialogService.instance.showError(
        title: 'Edit ditolak',
        message: 'Tidak bisa edit karena $reason.',
      );
      return;
    }

    // aman -> buka form edit
    _showFormDialog(header: header, details: vm.details);
  }

  Future<void> _onDeleteHeader(BrokerHeader header) async {
    final vm = context.read<BrokerViewModel>();

    // pastikan selection benar
    vm.setSelectedNoBroker(header.noBroker);

    // fetch detail terbaru untuk header ini
    DialogService.instance.showLoading(
      message: 'Cek detail ${header.noBroker}...',
    );
    await vm.fetchDetails(header.noBroker);
    DialogService.instance.hideLoading();

    if (!mounted) return;

    // RULE: tidak boleh delete jika ada DateUsage terisi atau ada isPartial = true
    final hasUsed = vm.details.any((d) => _isUsed(d.dateUsage));
    final hasPartial = vm.details.any((d) => d.isPartial == true);

    if (hasUsed || hasPartial) {
      final reason = [
        if (hasUsed) 'ada Sak yang sudah dipakai',
        if (hasPartial) 'ada Sak yang telah dipartial',
      ].join(' dan ');

      await DialogService.instance.showError(
        title: 'Hapus ditolak',
        message: 'Tidak bisa hapus karena $reason.',
      );
      return;
    }

    // aman -> tampilkan konfirmasi delete
    _confirmDelete(header);
  }

  Future<void> _onQcHeader(BrokerHeader header) async {
    final vm = context.read<BrokerViewModel>();
    vm.setSelectedNoBroker(header.noBroker);

    final qc = await showDialog<BrokerQcResult>(
      context: context,
      builder: (_) => BrokerQcDialog(header: header),
    );

    if (!mounted || qc == null) return;

    DialogService.instance.showLoading(
      message: 'Menyimpan QC ${header.noBroker}...',
    );

    final res = await vm.updateBrokerQc(
      noBroker: header.noBroker,
      density1: qc.density1,
      density2: qc.density2,
      density3: qc.density3,
      moisture1: qc.moisture1,
      moisture2: qc.moisture2,
      moisture3: qc.moisture3,
      maxMeltTemp: qc.maxMeltTemp,
      minMeltTemp: qc.minMeltTemp,
      mfi: qc.mfi,
      visualNote: qc.visualNote,
      dateQc: qc.dateQc,
    );

    DialogService.instance.hideLoading();

    if (!mounted) return;
    if (res != null) {
      await DialogService.instance.showSuccess(
        title: 'QC Tersimpan',
        message:
            'Nilai QC untuk ${header.noBroker} berhasil diperbarui '
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


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BrokerViewModel>().fetchBrokerHeaders();
      context.read<BrokerViewModel>().resetForScreen();
      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor('broker');
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
    final applied = context.read<BrokerViewModel>().applyQcRealtime(event);
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
    _scrollController.dispose();
    _detailScrollController.dispose();
    searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSyncQueueChanged() {
    if (!mounted || _syncQueue == null) return;
    final now = _syncQueue!.pendingCountFor('broker');

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinkronisasi print broker tertunda ($now)')),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi print broker selesai')),
      );
    }

    _lastPendingCount = now;
  }

  void _onScroll() {
    final vm = context.read<BrokerViewModel>();
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
      context.read<BrokerViewModel>().fetchBrokerHeaders(search: query);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _showFormDialog({BrokerHeader? header, List<BrokerDetail>? details}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => BrokerFormDialog(
        header: header,
        details: details,
        onSave: (headerData, detailsData) {
          context.read<BrokerViewModel>();
          if (header != null) {
            // vm.updateWashing(headerData, detailsData);
          } else {
            // vm.createWashing(headerData, detailsData);
          }
        },
      ),
    );
  }

  void _confirmDelete(BrokerHeader header) {
    showDialog(
      context: context,
      builder: (_) => BrokerDeleteDialog(
        header: header,
        onConfirm: () async {
          // Tutup dialog dahulu. showDialog di-push ke root Navigator
          // (default useRootNavigator: true), sedangkan layar ini hidup di
          // shell Navigator milik AppShell yang hanya punya SATU route -
          // Navigator.of(context).pop() polos resolve ke shell Navigator dan
          // jadi no-op, sehingga dialog konfirmasi tidak pernah tertutup.
          Navigator.of(context, rootNavigator: true).pop();

          // Lanjut eksekusi delete
          await _handleDelete(header);
        },
      ),
    );
  }

  Future<void> _onItemLongPress(
    BrokerHeader header,
    Offset globalPosition,
  ) async {
    context.read<BrokerViewModel>().setSelectedNoBroker(header.noBroker);

    await showDialog(
      context: context,
      builder: (_) => BrokerActionDialog(
        header: header,
        onEdit: () => _onEditHeader(header),
        onDelete: () => _onDeleteHeader(header),
        onAuditHistory: () => _navigateToAuditHistory(header),
        onQc: () => _onQcHeader(header),
      ),
    );
  }

  void _navigateToAuditHistory(BrokerHeader header) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AuditScreenWithPrefilledDoc(documentNo: header.noBroker),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
                      final pending = syncQueue.pendingCountFor('broker');
                      if (pending <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: 'Sinkronisasi print broker tertunda ($pending)',
                            child: const Icon(Icons.sync, color: Color(0xFFFFE082)),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<BrokerViewModel>(
                    builder: (_, vm, __) => BrokerActionBar(
                      controller: searchCtrl,
                      onSearchChanged: _onSearchChanged,
                      onClear: () {
                        searchCtrl.clear();
                        vm.fetchBrokerHeaders(search: "");
                      },
                      onAddPressed: _showFormDialog,
                      includeUsed: vm.includeUsed,
                      onIncludeUsedChanged: vm.setIncludeUsed,
                    ),
                  ),
                  Expanded(
                    child: BrokerHeaderTable(
                      scrollController: _scrollController,
                      onItemTap: (header) {
                        final vm = context.read<BrokerViewModel>();
                        // Klik: pindahkan highlight & (opsional) load detail
                        vm.setSelectedNoBroker(header.noBroker);
                        vm.fetchDetails(header.noBroker);
                      },
                      // Long-press: pindahkan highlight & tampilkan popover
                      onItemLongPress: _onItemLongPress,
                      // ⚠️ Tidak perlu highlightedNoWashing lagi
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
            child: BrokerDetailTable(scrollController: _detailScrollController),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BrokerHeader header) async {
    final vm = context.read<BrokerViewModel>();
    final noBroker = header.noBroker;

    DialogService.instance.showLoading(message: 'Menghapus $noBroker...');
    final ok = await vm.deleteWashing(noBroker);
    DialogService.instance.hideLoading();

    if (ok) {
      await DialogService.instance.showSuccess(
        title: 'Terhapus',
        message: 'Label $noBroker berhasil dihapus.',
      );

      // Selalu bersihkan panel detail & selection
      vm.setSelectedNoBroker(null);

      // (Opsional) scroll panel detail ke atas
      // _detailScrollController.jumpTo(0);
    } else {
      await DialogService.instance.showError(
        title: 'Gagal',
        message: vm.errorMessage,
      );
    }
  }
}
