import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pps_tablet/features/audit/view/audit_screen_with_prefilled.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/interactive_popover.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../model/mixer_detail_model.dart';
import '../model/mixer_header_model.dart';
import '../view_model/mixer_view_model.dart';
import '../widgets/mixer_action_bar.dart';
import '../widgets/mixer_delete_dialog.dart';
import '../widgets/mixer_detail_table.dart';
import '../widgets/mixer_form_dialog.dart';
import '../widgets/mixer_header_table.dart';
import '../widgets/mixer_qc_dialog.dart';
import '../widgets/mixer_row_popover.dart';

class MixerScreen extends StatefulWidget {
  const MixerScreen({super.key});

  @override
  State<MixerScreen> createState() => _MixerScreenState();
}

class _MixerScreenState extends State<MixerScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _detailScrollController = ScrollController();
  bool _isLoadingMore = false;
  Timer? _debounce;
  LabelPrintSyncQueue? _syncQueue;
  int _lastPendingCount = 0;

  final InteractivePopover _popover = InteractivePopover();

  bool _isUsed(String? dateUsage) {
    final s = (dateUsage ?? '').trim();
    if (s.isEmpty) return false;
    if (s.toLowerCase() == 'null') return false;
    return true;
  }

  Future<void> _onEditHeader(MixerHeader header) async {
    final vm = context.read<MixerViewModel>();

    vm.setSelectedNoMixer(header.noMixer);

    DialogService.instance.showLoading(
      message: 'Cek detail ${header.noMixer}...',
    );
    await vm.fetchDetails(header.noMixer);
    DialogService.instance.hideLoading();

    if (!mounted) return;

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

    _showFormDialog(header: header, details: vm.details);
  }

  Future<void> _onDeleteHeader(MixerHeader header) async {
    final vm = context.read<MixerViewModel>();

    vm.setSelectedNoMixer(header.noMixer);

    DialogService.instance.showLoading(
      message: 'Cek detail ${header.noMixer}...',
    );
    await vm.fetchDetails(header.noMixer);
    DialogService.instance.hideLoading();

    if (!mounted) return;

    final hasUsed = vm.details.any((d) => _isUsed(d.dateUsage));
    final hasPartial = vm.details.any((d) => d.isPartial == true);

    if (hasUsed || hasPartial) {
      final reason = [
        if (hasUsed) 'ada Sak yang sudah dipakai',
        if (hasPartial) 'ada Sak yang telah dipartial',
      ].join(' dan ');

      await DialogService.instance.showError(
        title: 'Delete ditolak',
        message: 'Tidak bisa delete karena $reason.',
      );
      return;
    }

    _confirmDelete(header);
  }

  Future<void> _onQcHeader(MixerHeader header) async {
    final vm = context.read<MixerViewModel>();
    vm.setSelectedNoMixer(header.noMixer);

    final qc = await showDialog<MixerQcResult>(
      context: context,
      builder: (_) => MixerQcDialog(header: header),
    );

    if (!mounted || qc == null) return;

    DialogService.instance.showLoading(
      message: 'Menyimpan QC ${header.noMixer}...',
    );

    final res = await vm.updateMixerQc(
      noMixer: header.noMixer,
      moisture1: qc.moisture1,
      moisture2: qc.moisture2,
      moisture3: qc.moisture3,
      minMeltTemp: qc.minMeltTemp,
      maxMeltTemp: qc.maxMeltTemp,
      mfi: qc.mfi,
    );

    DialogService.instance.hideLoading();
    if (!mounted) return;

    if (res != null) {
      await DialogService.instance.showSuccess(
        title: 'QC Tersimpan',
        message: 'Nilai QC untuk ${header.noMixer} berhasil diperbarui.',
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
      context.read<MixerViewModel>().fetchHeaders();
      context.read<MixerViewModel>().resetForScreen();
      _syncQueue = context.read<LabelPrintSyncQueue>();
      _lastPendingCount = _syncQueue!.pendingCountFor('mixer');
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
    final now = _syncQueue!.pendingCountFor('mixer');

    if (_lastPendingCount == 0 && now > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sinkronisasi print mixer tertunda ($now)')),
      );
    } else if (_lastPendingCount > 0 && now == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sinkronisasi print mixer selesai')),
      );
    }

    _lastPendingCount = now;
  }

  void _onScroll() {
    if (_popover.isShown) {
      _popover.hide();
    }

    final vm = context.read<MixerViewModel>();
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
      context.read<MixerViewModel>().fetchHeaders(search: query);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  void _showFormDialog({MixerHeader? header, List<MixerDetail>? details}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useSafeArea: false,
      builder: (_) => MixerFormDialog(
        header: header,
        details: details,
        onSave: (headerData, detailsData) {
          if (header != null) {
            // vm.update
          } else {
            // vm.create
          }
        },
      ),
    );
  }

  void _confirmDelete(MixerHeader header) {
    showDialog(
      context: context,
      builder: (_) => MixerDeleteDialog(
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
    MixerHeader header,
    Offset globalPosition,
  ) async {
    final vm = context.read<MixerViewModel>();
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(480.0, 820.0).toDouble();

    vm.setSelectedNoMixer(header.noMixer);

    _popover.show(
      context: context,
      globalPosition: globalPosition,
      child: MixerRowPopover(
        header: header,
        onClose: _closeContextMenu,
        onEdit: () async {
          _closeContextMenu();
          await _onEditHeader(header);
        },
        onDelete: () async {
          if (context.read<MixerViewModel>().isLoading) return;
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

  void _navigateToAuditHistory(MixerHeader header) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            AuditScreenWithPrefilledDoc(documentNo: header.noMixer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
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
                      final pending = syncQueue.pendingCountFor('mixer');
                      if (pending <= 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: 'Sinkronisasi print mixer tertunda ($pending)',
                            child: const Icon(Icons.sync, color: Color(0xFFFFE082)),
                          ),
                        ),
                      );
                    },
                  ),
                  Consumer<MixerViewModel>(
                    builder: (_, vm, __) => MixerActionBar(
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
                    child: MixerHeaderTable(
                      scrollController: _scrollController,
                      onItemTap: (header) {
                        final vm = context.read<MixerViewModel>();
                        vm.setSelectedNoMixer(header.noMixer);
                        vm.fetchDetails(header.noMixer);
                      },
                      onItemLongPress: _onItemLongPress,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(width: 2, color: Colors.grey.shade300),
          Expanded(
            flex: 1,
            child: MixerDetailTable(scrollController: _detailScrollController),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(MixerHeader header) async {
    final vm = context.read<MixerViewModel>();
    final noMixer = header.noMixer;

    DialogService.instance.showLoading(message: 'Menghapus $noMixer...');
    final ok = await vm.deleteMixer(noMixer);
    DialogService.instance.hideLoading();

    if (ok) {
      await DialogService.instance.showSuccess(
        title: 'Terhapus',
        message: 'Label $noMixer berhasil dihapus.',
      );

      vm.setSelectedNoMixer(null);
    } else {
      await DialogService.instance.showError(
        title: 'Gagal',
        message: vm.errorMessage.isNotEmpty
            ? vm.errorMessage
            : 'Tidak dapat menghapus label.',
      );
    }
  }
}
