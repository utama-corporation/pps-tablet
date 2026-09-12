import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/scan_label_dialog.dart';
import '../../../common/widgets/success_status_dialog.dart';
import '../../../common/widgets/warning_status_dialog.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/network/label_print_lock_api.dart';
import '../../../core/services/label_print_sync_queue.dart';
import '../../../core/utils/pdf_print_service.dart';
import '../../../core/view/app_shell.dart';
import '../../../core/view_model/label_print_lock_socket_manager.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../../label/furniture_wip/repository/furniture_wip_repository.dart';
import '../../label/packing/repository/packing_repository.dart';
import '../model/penjualan_line_model.dart';
import '../repository/penjualan_repository.dart';
import '../view_model/penjualan_detail_view_model.dart';

const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF3F5F8);
const _kBorder = Color(0xFFE2E6EA);
const _kSuccess = Color(0xFF0A7349);
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1D23);

/// Detail 1 nomor Penjualan (BJJual) — daftar item turnover dengan progress
/// pcs, dipenuhi lewat scan label (kategori furniturewip/barangjadi saja).
/// Meniru struktur section-card `retur_v3_detail_screen.dart`.
class PenjualanDetailScreen extends StatefulWidget {
  final String noBJJual;

  /// Saat true, layar ini ditampilkan inline di panel kanan layout
  /// master-detail (lihat `penjualan_list_screen.dart`) — bukan sebagai
  /// halaman yang di-push lewat Navigator — sehingga tidak boleh memutasi
  /// breadcrumb `AppShell`.
  final bool embedded;

  /// Dipanggil begitu header ini terdeteksi complete setelah scan berhasil
  /// (semua baris turnover terpenuhi) — dipakai panel list untuk refresh
  /// & melepas seleksi karena header complete otomatis hilang dari daftar
  /// "belum complete".
  final VoidCallback? onCompleted;

  const PenjualanDetailScreen({
    super.key,
    required this.noBJJual,
    this.embedded = false,
    this.onCompleted,
  });

  @override
  State<PenjualanDetailScreen> createState() => _PenjualanDetailScreenState();
}

class _PenjualanDetailScreenState extends State<PenjualanDetailScreen> {
  late final PenjualanDetailViewModel _vm;
  List<BreadcrumbSegment> _prevBreadcrumb = [];

  @override
  void initState() {
    super.initState();
    _vm = PenjualanDetailViewModel(
      noBJJual: widget.noBJJual,
      repository: PenjualanRepository(),
    );
    _vm.load();
    if (!widget.embedded) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _prevBreadcrumb = List<BreadcrumbSegment>.from(
          AppShell.breadcrumb.value,
        );
        AppShell.breadcrumb.value = [
          ..._prevBreadcrumb.map(
            (s) => BreadcrumbSegment(
              s.label,
              onTap: () {
                AppShell.breadcrumb.value = _prevBreadcrumb;
                AppShell.shellNavigatorKey.currentState?.pop();
              },
            ),
          ),
          BreadcrumbSegment(widget.noBJJual),
        ];
      });
    }
  }

  @override
  void dispose() {
    if (!widget.embedded) {
      final prev = _prevBreadcrumb;
      final noBJJual = widget.noBJJual;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = AppShell.breadcrumb.value;
        if (current.isNotEmpty && current.last.label == noBJJual) {
          AppShell.breadcrumb.value = prev;
        }
      });
    }
    _vm.dispose();
    super.dispose();
  }

  /// Percobaan scan pertama; kalau backend merekomendasikan partial
  /// (pcs label melebihi sisa kebutuhan), tanya user dulu lewat dialog
  /// konfirmasi bersarang di atas `ScanLabelDialog` sebelum benar-benar
  /// memecah labelnya. Kontrak `onLookup`: null = sukses (dialog auto
  /// tutup), String = pesan error ditampilkan inline (dialog tetap buka).
  Future<String?> _handleScan(String code) async {
    final result = await _vm.attemptScan(code);
    if (result.success) {
      if (_vm.allLinesFulfilled) widget.onCompleted?.call();
      return null;
    }
    if (result.needsConfirmation) {
      if (!mounted) return null;
      final suggestion = result.suggestion!;
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => WarningStatusDialog(
          title: 'Pcs Label Melebihi Kebutuhan',
          message: suggestion.message,
          actions: [
            StatusAction(
              label: 'Batal',
              isPrimary: false,
              onPressed: () => Navigator.pop(dialogContext, false),
            ),
            StatusAction(
              label: 'Ya, Pecah ${suggestion.pcsNeeded} pcs',
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return 'Scan dibatalkan — pcs label melebihi sisa kebutuhan';
      }
      final partialResult = await _vm.confirmPartialScan(code);
      if (!partialResult.success) return partialResult.error;

      if (mounted && partialResult.kodeKategori != null) {
        // Cetak ulang label ASAL (parent) yang barusan discan — bukan kode
        // partial internal (BC./BL.) — lewat endpoint PDF label yang sudah
        // ada di modul furniture-wip/packing. Endpoint itu menghitung Pcs
        // dinamis dari Pcs - SUM(partial), jadi begitu partial baru saja
        // dibuat, PDF label induk otomatis menampilkan sisa pcs yang benar.
        await _offerPrintParentLabel(code, partialResult.kodeKategori!);
      }

      if (_vm.allLinesFulfilled) widget.onCompleted?.call();
      return null;
    }
    return result.error;
  }

  /// Partial berhasil dibuat — pakai dialog SUCCESS (bukan warning, karena
  /// operasinya sudah berhasil), tapi tetap tawarkan cetak ulang label asal
  /// sebagai aksi lanjutan: pcs pada label fisiknya sekarang berkurang, jadi
  /// kalau tidak dicetak ulang, label yang beredar masih menunjukkan angka
  /// lama. "Nanti" cuma menunda — bisa dicetak manual belakangan lewat menu
  /// label Furniture WIP / Barang Jadi yang sudah ada.
  Future<void> _offerPrintParentLabel(
    String noLabel,
    String kodeKategori,
  ) async {
    if (!mounted) return;
    final shouldPrint = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => SuccessStatusDialog(
        title: 'Partial Berhasil Dibuat',
        message:
            'Label $noLabel berhasil dipecah (partial) untuk memenuhi turnover '
            'Penjualan ini. Pcs pada label fisiknya sekarang berkurang, jadi '
            'label perlu dicetak ulang supaya pcs yang tertera sesuai. '
            'Cetak sekarang?',
        actions: [
          StatusAction(
            label: 'Nanti',
            isPrimary: false,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          StatusAction(
            label: 'Cetak Sekarang',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (shouldPrint != true || !mounted) return;
    await _printParentLabel(noLabel, kodeKategori);
  }

  /// Cetak ulang label asal (furniturewip/barangjadi) — pola persis sama
  /// dengan tombol Print di `furniture_wip_row_popover.dart` /
  /// `packing_row_popover.dart`: acquire print-lock → preview+print PDF →
  /// tandai HasBeenPrinted & release lock (fallback ke `LabelPrintSyncQueue`
  /// kalau gagal). Pakai endpoint & repository label yang SUDAH ADA untuk
  /// label induk — bukan endpoint khusus partial.
  Future<void> _printParentLabel(String noLabel, String kodeKategori) async {
    final rootCtx = Navigator.of(context, rootNavigator: true).context;
    final lockApi = LabelPrintLockApi();
    final lockVm = context.read<LabelPrintLockSocketManager>();
    final queue = context.read<LabelPrintSyncQueue>();
    final isFurnitureWip = kodeKategori == 'furniturewip';
    final feature = isFurnitureWip ? 'furniture_wip' : 'packing';
    final pdfUrl = isFurnitureWip
        ? ApiConstants.furnitureWipLabelPdf(noLabel)
        : ApiConstants.packingLabelPdf(noLabel);
    final furnitureWipRepo = FurnitureWipRepository();
    final packingRepo = PackingRepository(api: ApiClient());

    var isLockAcquired = false;
    var isPrinted = false;

    try {
      await lockApi.acquire(noLabel);
      isLockAcquired = true;

      await PdfPrintService(defaultSystem: 'pps').previewFromUrl(
        context: rootCtx,
        pdfUrl: Uri.parse(pdfUrl),
        title: noLabel,
        onPrinted: () {
          isPrinted = true;
          () async {
            var needsIncrement = false;
            var needsRelease = false;

            try {
              final count = isFurnitureWip
                  ? await furnitureWipRepo.markAsPrinted(noLabel)
                  : await packingRepo.markAsPrinted(noLabel);
              if (count != null) lockVm.setPrintCount(noLabel, count);
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
                feature: feature,
                noLabel: noLabel,
                needsIncrement: needsIncrement,
                needsReleaseLock: needsRelease,
              );
            }
          }().ignore();
        },
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (isLockAcquired && !isPrinted) {
        () async {
          try {
            await lockApi.release(noLabel);
          } catch (_) {
            await queue.enqueue(
              feature: feature,
              noLabel: noLabel,
              needsReleaseLock: true,
            );
          }
        }().ignore();
      }
    }
  }

  void _openScanDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => ScanLabelDialog(
        headerSubtitle: 'Scan label untuk memenuhi turnover',
        manualHint: 'BA.0000000001 / BB.0000000001',
        acceptedLabels: const [
          (prefix: 'BA.', label: 'Barang Jadi'),
          (prefix: 'BB.', label: 'Furniture WIP'),
        ],
        onLookup: _handleScan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PenjualanDetailViewModel>.value(
      value: _vm,
      child: Consumer<PenjualanDetailViewModel>(
        builder: (context, vm, _) {
          final canScan = context.watch<PermissionViewModel>().can(
            'penjualan:create',
          );
          final showScanFab = !vm.allLinesFulfilled && canScan;

          return Scaffold(
            backgroundColor: _kSurface,
            floatingActionButton: showScanFab
                ? FloatingActionButton.extended(
                    onPressed: _openScanDialog,
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan'),
                  )
                : null,
            body: RefreshIndicator(onRefresh: vm.load, child: _buildBody(vm)),
          );
        },
      ),
    );
  }

  Widget _buildBody(PenjualanDetailViewModel vm) {
    if (vm.isLoading && vm.header == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null && vm.header == null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              vm.error!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
      );
    }

    final header = vm.header;
    if (header == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Cukup judul simpel penanda "ini section detail" — info lengkap
        // (no.BJJual/tanggal/pembeli) sudah jelas dari kartu yang dipilih
        // di panel kiri, tidak perlu diulang jadi card besar lagi.
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Detail Penjualan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _kText,
            ),
          ),
        ),
        _TurnoverSection(vm: vm),
        const SizedBox(height: 16),
        _StatusBanner(vm: vm),
      ],
    );
  }
}

// ── Section: daftar item turnover + progress ────────────────────────────

class _TurnoverSection extends StatelessWidget {
  final PenjualanDetailViewModel vm;
  const _TurnoverSection({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Text(
              'Item yang Dipickup',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          if (vm.lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Belum ada item',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: vm.lines.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _kBorder),
              itemBuilder: (context, i) =>
                  _TurnoverTile(number: i + 1, line: vm.lines[i]),
            ),
        ],
      ),
    );
  }
}

/// Satu tile progress per item — meniru `_TurnoverItemBlock` di
/// `retur_v3_detail_screen.dart` (badge nomor jadi centang hijau saat
/// terpenuhi, dibungkus card abu-abu, chip per label yang sudah discan).
class _TurnoverTile extends StatelessWidget {
  final int number;
  final PenjualanLine line;
  const _TurnoverTile({required this.number, required this.line});

  @override
  Widget build(BuildContext context) {
    final scanned = line.pcsScanned;
    final target = line.pcsRequired;
    final fulfilled = line.isComplete;
    final namaJenis = (line.namaJenis ?? '').isNotEmpty
        ? line.namaJenis!
        : '${line.kategoriLabel} #${line.idJenis}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Badge nomor urut — jadi centang hijau saat item terpenuhi.
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: fulfilled
                        ? _kSuccess
                        : _kPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: fulfilled
                      ? const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        )
                      : Text(
                          '$number',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _kPrimary,
                          ),
                        ),
                ),
                Expanded(
                  child: Text(
                    namaJenis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _kText,
                    ),
                  ),
                ),
                Text(
                  '$scanned/$target pcs',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fulfilled ? _kSuccess : _kMuted,
                  ),
                ),
              ],
            ),
            if (line.scans.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: line.scans
                    .map(
                      (s) => Chip(
                        label: Text(
                          '${s.noLabel} (${s.pcs})',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Banner status di bawah section ───────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final PenjualanDetailViewModel vm;
  const _StatusBanner({required this.vm});

  @override
  Widget build(BuildContext context) {
    final complete = vm.allLinesFulfilled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: complete
            ? _kSuccess.withValues(alpha: 0.08)
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: complete
              ? _kSuccess.withValues(alpha: 0.3)
              : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            complete
                ? Icons.check_circle_rounded
                : Icons.qr_code_scanner_rounded,
            size: 18,
            color: complete ? _kSuccess : Colors.orange.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              complete
                  ? 'Semua item turnover sudah terpenuhi — Penjualan ini complete.'
                  : 'Scan label lewat tombol Scan di kanan bawah sampai semua item terpenuhi.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: complete ? _kSuccess : Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
