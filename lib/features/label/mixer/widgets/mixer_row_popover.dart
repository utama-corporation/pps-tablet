import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/label_popover_widgets.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/label_print_lock_api.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../../core/view_model/label_print_lock_socket_manager.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../model/mixer_header_model.dart';
import '../repository/mixer_repository.dart';

class MixerRowPopover extends StatefulWidget {
  final MixerHeader header;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPrint;
  final VoidCallback onAuditHistory;
  final VoidCallback onQc;

  const MixerRowPopover({
    super.key,
    required this.header,
    required this.onClose,
    required this.onEdit,
    required this.onDelete,
    required this.onPrint,
    required this.onAuditHistory,
    required this.onQc,
  });

  @override
  State<MixerRowPopover> createState() => _MixerRowPopoverState();
}

class _MixerRowPopoverState extends State<MixerRowPopover> {
  static const _copyFeedbackDuration = Duration(milliseconds: 1200);

  bool _copied = false;
  Timer? _copiedResetTimer;

  void _runAndClose(VoidCallback action) {
    widget.onClose();
    action();
  }

  Future<void> _copyOnly() async {
    await Clipboard.setData(ClipboardData(text: widget.header.noMixer));
    if (!mounted) return;

    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(_copyFeedbackDuration, () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }

  bool _isBongkarSusunLabel() {
    final noBongkarSusun = (widget.header.noBongkarSusun ?? '').trim();
    return noBongkarSusun.isNotEmpty;
  }

  Future<void> _handleEdit() async {
    if (_isBongkarSusunLabel()) {
      widget.onClose();
      await DialogService.instance.showError(
        title: 'Tidak Dapat Diedit',
        message:
            'Label yang berasal dari Bongkar Susun tidak dapat diedit. Silakan buat label baru jika diperlukan perubahan.',
      );
      return;
    }
    _runAndClose(widget.onEdit);
  }

  @override
  void dispose() {
    _copiedResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const atlasBlue = Color(0xFF0C66E4);
    const atlasBlueSubtle = Color(0xFFE9F2FF);
    const atlasSurface = Color(0xFFF7F8F9);
    const atlasBorder = Color(0xFFDCDFE4);
    const atlasText = Color(0xFF172B4D);
    const atlasSubtleText = Color(0xFF44546F);

    final divider = const Divider(
      height: 0,
      thickness: 0.8,
      color: atlasBorder,
    );

    final perm = context.watch<PermissionViewModel>();
    final canEdit = perm.can('label_mixer:update');
    final canDelete = perm.can('label_mixer:delete');
    final canQC = perm.can('qc_label:update');

    final statusText = widget.header.statusText.trim().isEmpty
        ? '-'
        : widget.header.statusText.trim().toUpperCase();
    final isPass = statusText == 'PASS';
    final statusColor = isPass
        ? const Color(0xFF1F845A)
        : const Color(0xFFC9372C);
    final blokText = (widget.header.blok ?? '').trim().isEmpty
        ? null
        : widget.header.blok!.trim();

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: Material(
        color: Colors.white,
        elevation: 10,
        shadowColor: const Color(0xFF091E42).withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: const BoxDecoration(
                  color: atlasBlueSubtle,
                  border: Border(bottom: BorderSide(color: atlasBorder)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: atlasBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: atlasBlue.withOpacity(0.24)),
                      ),
                      child: const Icon(
                        Icons.blender_outlined,
                        color: atlasBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.header.noMixer,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: atlasText,
                              height: 1.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.header.namaMixer,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: atlasSubtleText,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Salin',
                      onPressed: _copyOnly,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          _copied ? Icons.check_rounded : Icons.copy_rounded,
                          key: ValueKey(_copied),
                          color: atlasBlue,
                          size: 18,
                        ),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: atlasBorder),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Status + QC panel ──
              Container(
                width: double.infinity,
                color: atlasSurface,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQCDataCard(),
                    const SizedBox(height: 6),
                    _buildVisualNoteItem(widget.header.visualNote),
                  ],
                ),
              ),
              divider,
              LabelPopoverMenuTile(
                icon: Icons.history_rounded,
                label: 'History',
                enabled: true,
                onTap: () => _runAndClose(widget.onAuditHistory),
              ),
              divider,
              LabelPopoverMenuTile(
                icon: Icons.edit_outlined,
                label: 'Edit',
                enabled: canEdit,
                tooltipWhenDisabled: 'Tidak punya izin edit',
                onTap: _handleEdit,
              ),
              divider,
              LabelPopoverMenuTile(
                icon: Icons.science_outlined,
                label: 'Input QC',
                enabled: canQC,
                tooltipWhenDisabled: 'Tidak punya izin update QC',
                onTap: () => _runAndClose(widget.onQc),
              ),
              divider,
              LabelPopoverMenuTile(
                icon: Icons.print_outlined,
                label: 'Print',
                enabled: true,
                onTap: () => _runAndClose(() async {
                  final rootCtx = Navigator.of(
                    context,
                    rootNavigator: true,
                  ).context;

                  final noMixer = widget.header.noMixer;
                  final lockApi = LabelPrintLockApi();
                  final repo = MixerRepository();
                  final lockVm = context.read<LabelPrintLockSocketManager>();
                  final queue = context.read<LabelPrintSyncQueue>();
                  var isLockAcquired = false;
                  var isPrinted = false;

                  try {
                    await lockApi.acquire(noMixer);
                    isLockAcquired = true;

                    await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
                      context: rootCtx,
                      pdfUrl: Uri.parse(ApiConstants.mixerLabelPdf(noMixer)),
                      title: noMixer,
                      onPrinted: () {
                        isPrinted = true;
                        () async {
                          var needsIncrement = false;
                          var needsRelease = false;

                          try {
                            final count = await repo.markAsPrinted(noMixer);
                            if (count != null) {
                              lockVm.setPrintCount(noMixer, count);
                            }
                          } catch (_) {
                            needsIncrement = true;
                          }

                          try {
                            await lockApi.release(noMixer);
                          } catch (_) {
                            needsRelease = true;
                          }

                          if (needsIncrement || needsRelease) {
                            await queue.enqueue(
                              feature: 'mixer',
                              noLabel: noMixer,
                              needsIncrement: needsIncrement,
                              needsReleaseLock: needsRelease,
                            );
                          }
                        }().ignore();
                      },
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    final msg = e.toString().replaceFirst('Exception: ', '');
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  } finally {
                    if (isLockAcquired && !isPrinted) {
                      () async {
                        try {
                          await lockApi.release(noMixer);
                        } catch (_) {
                          await queue.enqueue(
                            feature: 'mixer',
                            noLabel: noMixer,
                            needsReleaseLock: true,
                          );
                        }
                      }().ignore();
                    }
                  }
                }),
              ),
              divider,
              LabelPopoverMenuTile(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Print QC',
                enabled: true,
                onTap: () => _runAndClose(() async {
                  final rootCtx = Navigator.of(
                    context,
                    rootNavigator: true,
                  ).context;

                  // Sengaja tanpa lock + tanpa markAsPrinted: yang menambah
                  // HasBeenPrinted hanya cetak LABEL. Print QC hanya
                  // mengambil ulang angka QC — pola sama dengan broker/washing.
                  final noMixer = widget.header.noMixer;
                  try {
                    await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
                      context: rootCtx,
                      pdfUrl: Uri.parse(ApiConstants.mixerQcPdf(noMixer)),
                      title: '$noMixer - QC',
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    final msg = e.toString().replaceFirst('Exception: ', '');
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(msg)));
                  }
                }),
              ),
              divider,
              LabelPopoverMenuTile(
                icon: Icons.delete_outline,
                label: 'Delete',
                enabled: canDelete,
                tooltipWhenDisabled: 'Tidak punya izin hapus',
                iconColor: const Color(0xFFC9372C),
                textStyle: const TextStyle(
                  color: Color(0xFFC9372C),
                  fontWeight: FontWeight.w600,
                ),
                onTap: () => _runAndClose(widget.onDelete),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQCDataCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFDCDFE4)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quality Control',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF44546F),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildQcDataItem('Moist 1', widget.header.moisture),
              const SizedBox(width: 8),
              _buildQcDataItem('Moist 2', widget.header.moisture2),
              const SizedBox(width: 8),
              _buildQcDataItem('Moist 3', widget.header.moisture3),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildQcDataItem('Max Melt', widget.header.maxMeltTemp),
              const SizedBox(width: 8),
              _buildQcDataItem('Min Melt', widget.header.minMeltTemp),
              const SizedBox(width: 8),
              _buildQcDataItem('MFI', widget.header.mfi),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualNoteItem(String? note) {
    final displayValue = (note ?? '').trim().isEmpty ? '-' : note!.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEBECF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Visual Note',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B778C),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            displayValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172B4D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQcDataItem(String label, double? value) {
    final displayValue = value != null ? value.toStringAsFixed(2) : '-';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFEBECF0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B778C),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              displayValue,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF172B4D),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
