import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/label_popover_widgets.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/label_print_lock_api.dart';
import '../../../../core/view_model/label_print_lock_socket_manager.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/services/dialog_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../model/washing_header_model.dart';
import '../repository/washing_repository.dart';

class WashingRowPopover extends StatefulWidget {
  final WashingHeader header;
  final VoidCallback onClose;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPrint;
  final VoidCallback onAuditHistory;
  final VoidCallback onQc;

  const WashingRowPopover({
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
  State<WashingRowPopover> createState() => _WashingRowPopoverState();
}

class _WashingRowPopoverState extends State<WashingRowPopover> {
  static const _copyFeedbackDuration = Duration(milliseconds: 1200);
  bool _copied = false;
  Timer? _copiedResetTimer;

  void _runAndClose(VoidCallback action) {
    widget.onClose();
    action();
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

  Future<void> _copyOnly() async {
    await Clipboard.setData(ClipboardData(text: widget.header.noWashing));
    if (!mounted) return;

    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(_copyFeedbackDuration, () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
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
    final canEdit = perm.can('label_washing:update');
    final canDelete = perm.can('label_washing:delete');
    final canQC = perm.can('qc_label:update');

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
                        Icons.local_laundry_service_outlined,
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
                            widget.header.noWashing,
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
                            widget.header.namaJenisPlastik,
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
              Container(
                width: double.infinity,
                color: atlasSurface,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [_buildQcDataCard()],
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

                  final noWashing = widget.header.noWashing;
                  final lockApi = LabelPrintLockApi();
                  final repo = WashingRepository();
                  final lockVm = context.read<LabelPrintLockSocketManager>();
                  final queue = context.read<LabelPrintSyncQueue>();
                  var isLockAcquired = false;
                  var isPrinted = false;
                  try {
                    await lockApi.acquire(noWashing);
                    isLockAcquired = true;

                    await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
                      context: rootCtx,
                      pdfUrl: Uri.parse(
                        ApiConstants.washingLabelPdf(noWashing),
                      ),
                      title: 'Label $noWashing',
                      onPrinted: () {
                        isPrinted = true;
                        () async {
                          var needsIncrement = false;
                          var needsRelease = false;

                          try {
                            final count = await repo.markAsPrinted(noWashing);
                            if (count != null) {
                              lockVm.setPrintCount(noWashing, count);
                            }
                          } catch (_) {
                            needsIncrement = true;
                          }

                          try {
                            await lockApi.release(noWashing);
                          } catch (_) {
                            needsRelease = true;
                          }

                          if (needsIncrement || needsRelease) {
                            await queue.enqueue(
                              feature: 'washing',
                              noLabel: noWashing,
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
                          await lockApi.release(noWashing);
                        } catch (_) {
                          await queue.enqueue(
                            feature: 'washing',
                            noLabel: noWashing,
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

  Widget _buildQcDataCard() {
    final qcDate = formatDateToShortId(widget.header.dateQc);
    final qcBy = (widget.header.qcBy ?? '').trim();
    final hasQcDate = qcDate.isNotEmpty && qcDate != widget.header.dateQc;

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quality Control',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF44546F),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              if (hasQcDate)
                Text(
                  qcBy.isEmpty ? qcDate : '$qcDate • $qcBy',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B778C),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildQcDataItem('Density 1', widget.header.density),
              const SizedBox(width: 8),
              _buildQcDataItem('Density 2', widget.header.density2),
              const SizedBox(width: 8),
              _buildQcDataItem('Density 3', widget.header.density3),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildQcDataItem('Moist 1', widget.header.moisture),
              const SizedBox(width: 8),
              _buildQcDataItem('Moist 2', widget.header.moisture2),
              const SizedBox(width: 8),
              _buildQcDataItem('Moist 3', widget.header.moisture3),
            ],
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
