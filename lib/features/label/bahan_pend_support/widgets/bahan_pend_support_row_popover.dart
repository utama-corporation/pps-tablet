// lib/features/label/bahan_pend_support/widgets/bahan_pend_support_row_popover.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/label_popover_widgets.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/network/label_print_lock_api.dart';
import '../../../../core/services/label_print_sync_queue.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../core/utils/pdf_print_service.dart';
import '../../../../core/view_model/label_print_lock_socket_manager.dart';
import '../../../../core/view_model/permission_view_model.dart';
import '../model/bahan_pend_support_header_model.dart';
import '../repository/bahan_pend_support_repository.dart';

/// Menu aksi baris Label Bahan Pendukung.
///
/// Backend tidak punya endpoint create untuk BP., jadi tidak ada aksi Edit —
/// hanya Print dan Delete.
class BahanPendukungRowPopover extends StatefulWidget {
  final BahanPendukungHeader header;
  final VoidCallback onClose;
  final VoidCallback onDelete;
  final VoidCallback onAuditHistory;

  const BahanPendukungRowPopover({
    super.key,
    required this.header,
    required this.onClose,
    required this.onDelete,
    required this.onAuditHistory,
  });

  @override
  State<BahanPendukungRowPopover> createState() =>
      _BahanPendukungRowPopoverState();
}

class _BahanPendukungRowPopoverState extends State<BahanPendukungRowPopover> {
  static const _copyFeedbackDuration = Duration(milliseconds: 1200);
  bool _copied = false;
  Timer? _copiedResetTimer;

  void _runAndClose(VoidCallback action) {
    widget.onClose();
    action();
  }

  Future<void> _copyOnly() async {
    await Clipboard.setData(
      ClipboardData(text: widget.header.noBahanPendukung),
    );
    if (!mounted) return;

    _copiedResetTimer?.cancel();
    setState(() => _copied = true);
    _copiedResetTimer = Timer(_copyFeedbackDuration, () {
      if (mounted) setState(() => _copied = false);
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
    const atlasBorder = Color(0xFFDCDFE4);
    const atlasText = Color(0xFF172B4D);
    const atlasSubtleText = Color(0xFF44546F);

    final divider = const Divider(
      height: 0,
      thickness: 0.8,
      color: atlasBorder,
    );

    final perm = context.watch<PermissionViewModel>();
    final canDelete = perm.can('label_bahanpendukung:delete');

    final namaMaterial = (widget.header.namaCabinetMaterial ?? '').trim();
    final qty = widget.header.qty;
    final subtitle = [
      if (namaMaterial.isNotEmpty) namaMaterial,
      if (qty != null) 'Qty: ${formatPcsQty(qty)}',
    ].join(' • ');

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      child: Material(
        color: Colors.white,
        elevation: 10,
        shadowColor: const Color(0xFF091E42).withValues(alpha: 0.18),
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
                        color: atlasBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: atlasBlue.withValues(alpha: 0.24),
                        ),
                      ),
                      child: const Icon(
                        Icons.science_outlined,
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
                            widget.header.noBahanPendukung,
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
                            subtitle.isEmpty
                                ? 'Bahan Pendukung'
                                : subtitle,
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
              divider,
              /*LabelPopoverMenuTile(
                icon: Icons.history_rounded,
                label: 'History',
                enabled: true,
                onTap: () => _runAndClose(widget.onAuditHistory),
              ),
              divider,*/
              LabelPopoverMenuTile(
                icon: Icons.print_outlined,
                label: 'Print',
                enabled: true,
                onTap: () => _runAndClose(() async {
                  final rootCtx = Navigator.of(
                    context,
                    rootNavigator: true,
                  ).context;

                  final noLabel = widget.header.noBahanPendukung;
                  final lockApi = LabelPrintLockApi();
                  final repo = BahanPendukungRepository();
                  final lockVm = context.read<LabelPrintLockSocketManager>();
                  final queue = context.read<LabelPrintSyncQueue>();
                  var isLockAcquired = false;
                  var isPrinted = false;

                  try {
                    await lockApi.acquire(noLabel);
                    isLockAcquired = true;

                    await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
                      context: rootCtx,
                      pdfUrl: Uri.parse(
                        ApiConstants.bahanPendukungLabelPdf(noLabel),
                      ),
                      title: noLabel,
                      onPrinted: () {
                        isPrinted = true;
                        () async {
                          var needsIncrement = false;
                          var needsRelease = false;

                          try {
                            final count = await repo.markAsPrinted(noLabel);
                            if (count != null) {
                              lockVm.setPrintCount(noLabel, count);
                            }
                          } catch (_) {
                            needsIncrement = true;
                          }

                          try {
                            await lockApi.release(noLabel);
                          } catch (_) {
                            needsRelease = true;
                          }

                          if (needsIncrement || needsRelease) {
                            await queue.enqueue(
                              feature: 'bahan_pendukung',
                              noLabel: noLabel,
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
                          await lockApi.release(noLabel);
                        } catch (_) {
                          await queue.enqueue(
                            feature: 'bahan_pendukung',
                            noLabel: noLabel,
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
}