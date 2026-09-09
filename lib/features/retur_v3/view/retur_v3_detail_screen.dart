import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/scan_label_dialog.dart';
import '../../../common/widgets/success_status_dialog.dart'
    show StatusAction, SuccessStatusDialog;
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
import '../../label/reject/repository/reject_repository.dart';
import '../model/retur_v3_item.dart';
import '../model/retur_v3_output.dart';
import '../model/retur_v3_turnover.dart';
import '../repository/retur_v3_repository.dart';
import '../view_model/retur_v3_detail_view_model.dart';
import '../widgets/retur_v3_reject_generate_dialog.dart';

const _kPrimary = Color(0xFF1E6FD9);
const _kSurface = Color(0xFFF3F5F8);
const _kBorder = Color(0xFFE2E6EA);
const _kSuccess = Color(0xFF0A7349);
const _kMuted = Color(0xFF6B7280);
const _kText = Color(0xFF1A1D23);

const _kKategoriReject = 'reject';

// ── Print-flow helpers (mirrors lib/features/retur_v2/view/retur_v2_detail_screen.dart) ──

String _featureOf(ReturV3Output o) {
  switch (o.kodeKategori) {
    case ReturV3Kategori.furnitureWip:
      return 'furniture_wip';
    case _kKategoriReject:
      return 'reject';
    default:
      return 'packing';
  }
}

String _pdfUrlOf(ReturV3Output o) {
  switch (o.kodeKategori) {
    case ReturV3Kategori.furnitureWip:
      return ApiConstants.furnitureWipLabelPdf(o.labelCode);
    case _kKategoriReject:
      return ApiConstants.rejectLabelPdf(o.labelCode);
    default:
      return ApiConstants.packingLabelPdf(o.labelCode);
  }
}

Future<int?> _markAsPrinted(ReturV3Output o) {
  switch (o.kodeKategori) {
    case ReturV3Kategori.furnitureWip:
      return FurnitureWipRepository().markAsPrinted(o.labelCode);
    case _kKategoriReject:
      return RejectRepository(api: ApiClient()).markAsPrinted(o.labelCode);
    default:
      return PackingRepository(api: ApiClient()).markAsPrinted(o.labelCode);
  }
}

/// Detail 1 nomor Retur v3 — tampilan berubah menurut `statusRetur`:
/// PENDING (tampilan item + keputusan), DIGANTI (generate label lalu scan
/// turnover), TIDAK_DIGANTI (generate label). Permission dipisah per role:
/// - `retur:decide` — Sales, HANYA untuk tombol DIGANTI/TIDAK_DIGANTI. Sales
///   tidak pernah memicu generate label sama sekali, bahkan tidak sebagai
///   efek samping dari aksi decide — dua action ini sengaja dipisah total.
/// - `retur:create`/`retur:update`/`retur:delete` — Admin (buat data retur,
///   edit header, scan turnover, flag kirim, DAN generate label).
///
/// Generate label adalah tombol manual eksplisit ("Generate Label" per
/// item di `_TidakDigantiSection`) yang cuma tampil/aktif untuk pemegang
/// `retur:update` — user lain (mis. Sales) cuma melihat status "Menunggu",
/// tidak ada aksi otomatis apapun yang terpicu di sesi mereka.
class ReturV3DetailScreen extends StatefulWidget {
  final String noRetur;

  /// Saat true, layar ini ditampilkan inline di panel kanan layout
  /// master-detail (lihat `retur_v3_list_screen.dart`) — bukan sebagai
  /// halaman yang di-push lewat Navigator — sehingga tidak boleh memutasi
  /// breadcrumb `AppShell` (daftar master di kiri tetap terlihat, tidak ada
  /// "perpindahan halaman" yang perlu direfleksikan di breadcrumb).
  final bool embedded;

  /// Dipanggil setelah aksi yang mengubah data yang juga tampil di badge
  /// kartu daftar master (keputusan diganti/tidak-diganti, flag kirim) —
  /// supaya panel kiri (`ReturV3ListScreen`) bisa refresh badge-nya tanpa
  /// user harus reload manual, karena detail & list di sini pakai view
  /// model terpisah (lihat layout master-detail di `retur_v3_list_screen`).
  final VoidCallback? onHeaderChanged;

  const ReturV3DetailScreen({
    super.key,
    required this.noRetur,
    this.embedded = false,
    this.onHeaderChanged,
  });

  @override
  State<ReturV3DetailScreen> createState() => _ReturV3DetailScreenState();
}

class _ReturV3DetailScreenState extends State<ReturV3DetailScreen> {
  late final ReturV3DetailViewModel _vm;
  List<BreadcrumbSegment> _prevBreadcrumb = [];

  @override
  void initState() {
    super.initState();
    _vm = ReturV3DetailViewModel(
      noRetur: widget.noRetur,
      repository: ReturV3Repository(),
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
          BreadcrumbSegment(widget.noRetur),
        ];
      });
    }
  }

  @override
  void dispose() {
    if (!widget.embedded) {
      final prev = _prevBreadcrumb;
      final noRetur = widget.noRetur;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final current = AppShell.breadcrumb.value;
        if (current.isNotEmpty && current.last.label == noRetur) {
          AppShell.breadcrumb.value = prev;
        }
      });
    }
    _vm.dispose();
    super.dispose();
  }

  // ── Print flow ─────────────────────────────────────────────────────

  void _openPrintDialog() {
    if (_vm.outputs.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (_) =>
          _PrintPickerDialog(items: _vm.outputs, onPrint: _printEntries),
    );
  }

  Future<void> _printEntries(List<ReturV3Output> entries) async {
    if (entries.isEmpty) return;
    final lockApi = LabelPrintLockApi();
    final lockVm = context.read<LabelPrintLockSocketManager>();
    final queue = context.read<LabelPrintSyncQueue>();
    final rootCtx = Navigator.of(context, rootNavigator: true).context;

    final acquiredCodes = <String>{};
    for (final entry in entries) {
      if (!mounted) break;
      try {
        await lockApi.acquire(entry.labelCode);
        acquiredCodes.add(entry.labelCode);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal lock ${entry.labelCode}: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }

    final printedCodes = <String>{};
    // Ditunggu (bukan .ignore()) sebelum refreshOutputs() di bawah — kalau
    // fire-and-forget, refreshOutputs() bisa balapan lebih dulu dan narik
    // data lama dari server (HasBeenPrinted/printCount belum ke-update),
    // makanya section 2 (Item yang Dipickup) kelihatan masih terkunci sampai
    // layar di-refresh manual.
    final pendingMarks = <Future<void>>[];
    final callbacks = entries.map((entry) {
      return () {
            printedCodes.add(entry.labelCode);
            final markFuture = () async {
              var needsIncrement = false;
              var needsRelease = false;
              try {
                final count = await _markAsPrinted(entry);
                if (count != null) lockVm.setPrintCount(entry.labelCode, count);
              } catch (_) {
                needsIncrement = true;
              }
              try {
                await lockApi.release(entry.labelCode);
              } catch (_) {
                needsRelease = true;
              }
              if (needsIncrement || needsRelease) {
                await queue.enqueue(
                  feature: _featureOf(entry),
                  noLabel: entry.labelCode,
                  needsIncrement: needsIncrement,
                  needsReleaseLock: needsRelease,
                );
              }
            }();
            pendingMarks.add(markFuture);
          }
          as VoidCallback;
    }).toList();

    try {
      await PdfPrintService(defaultSystem: 'pps').previewMultipleFromUrls(
        context: rootCtx,
        pdfUrls: entries.map((e) => Uri.parse(_pdfUrlOf(e))).toList(),
        title: 'Cetak ${entries.length} Label',
        onPrintedCallbacks: callbacks,
      );
    } finally {
      for (final entry in entries) {
        if (acquiredCodes.contains(entry.labelCode) &&
            !printedCodes.contains(entry.labelCode)) {
          () async {
            try {
              await lockApi.release(entry.labelCode);
            } catch (_) {
              await queue.enqueue(
                feature: _featureOf(entry),
                noLabel: entry.labelCode,
                needsReleaseLock: true,
              );
            }
          }().ignore();
        }
      }
      // Setiap future di pendingMarks sudah punya try/catch sendiri (jatuh
      // ke sync queue kalau gagal), jadi Future.wait ini tidak akan
      // melempar — aman ditunggu sebelum refresh.
      await Future.wait(pendingMarks);
      if (mounted) _vm.refreshOutputs();
    }
  }

  Future<void> _decide(String decision) async {
    final label = decision == 'DIGANTI' ? 'DIGANTI' : 'TIDAK DIGANTI';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi Keputusan'),
        content: Text(
          'Tetapkan keputusan retur ini sebagai "$label"? Keputusan ini tidak bisa diubah kembali ke Pending.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: _kPrimary),
            child: const Text('Ya, Tetapkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _vm.decide(decision);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_vm.decisionError ?? 'Gagal menetapkan keputusan'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Generate label sengaja BUKAN bagian dari aksi decide — retur:decide
    // (Sales) cuma untuk menentukan keputusan. Generate label adalah aksi
    // terpisah, tombolnya sendiri, khusus retur:update (Admin) — lihat
    // _generateLabel(), dipanggil dari tombol "Generate Label" per item.
    widget.onHeaderChanged?.call();
  }

  // ── Generate label (aksi manual terpisah, khusus Admin/retur:update) ──

  Future<void> _generateLabel(ReturV3Item item) async {
    double? berat;
    int? idReject;
    if (item.isReject) {
      final result = await showDialog<ReturV3RejectGenerateResult>(
        context: context,
        builder: (_) => ReturV3RejectGenerateDialog(
          namaJenis: item.namaJenis ?? '-',
          pcs: item.pcs,
        ),
      );
      if (result == null) return;
      berat = result.berat;
      idReject = result.idReject;
    }
    final ok = await _vm.generateLabelForItem(
      item.idItem,
      berat: berat,
      idReject: idReject,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_vm.generateError ?? 'Gagal generate label'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Scan (DIGANTI) ───────────────────────────────────────────────────

  /// Satu dialog scan untuk semua item pada retur ini — backend yang
  /// otomatis mendeteksi target mana yang cocok berdasarkan kategori+jenis
  /// label yang discan (lihat `ReturV3DetailViewModel.attemptScan`).
  void _openScanDialogAuto() {
    showDialog<void>(
      context: context,
      builder: (_) => ScanLabelDialog(
        headerSubtitle: 'Scan label untuk memenuhi turnover',
        manualHint: 'Scan atau ketik kode label',
        onLookup: _handleScan,
      ),
    );
  }

  /// Percobaan scan pertama; kalau backend merekomendasikan partial (pcs
  /// label melebihi sisa target), tanya user dulu lewat dialog konfirmasi
  /// bersarang di atas `ScanLabelDialog` sebelum benar-benar memecah
  /// labelnya. Kontrak `onLookup`: null = sukses (dialog auto tutup),
  /// String = pesan error ditampilkan inline. Sejajar
  /// `PenjualanDetailScreen._handleScan`.
  Future<String?> _handleScan(String code) async {
    final result = await _vm.attemptScan(code);
    if (result.success) return null;

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
        return 'Scan dibatalkan — pcs label melebihi sisa target';
      }
      final partialResult = await _vm.confirmPartialScan(code);
      if (!partialResult.success) return partialResult.error;

      if (mounted && partialResult.kodeKategori != null) {
        await _offerPrintParentLabel(code, partialResult.kodeKategori!);
      }
      return null;
    }
    return result.error;
  }

  /// Partial berhasil dibuat — tawarkan cetak ulang label ASAL (parent),
  /// bukan kode partial internal (BC./BL.): pcs pada label fisiknya sekarang
  /// berkurang, jadi kalau tidak dicetak ulang, label yang beredar masih
  /// menunjukkan angka lama. Sejajar `PenjualanDetailScreen._offerPrintParentLabel`.
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
            'retur ini. Pcs pada label fisiknya sekarang berkurang, jadi '
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

  /// Cetak ulang label asal (furniturewip/barangjadi) — pola sama dengan
  /// `_printEntries`: acquire print-lock → preview+print PDF → markAsPrinted
  /// & release lock (fallback ke `LabelPrintSyncQueue`). Pakai endpoint &
  /// repository label yang SUDAH ADA untuk label induk.
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

  Future<void> _undoScan(int idTurnover) async {
    final ok = await _vm.undoScan(idTurnover);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_vm.decisionError ?? 'Gagal membatalkan scan'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Target pengganti (DIGANTI) dibuat OTOMATIS oleh backend saat keputusan
  // "DIGANTI" disimpan — like-for-like: kategori/jenis/pcs mengikuti item
  // retur asalnya. Tidak ada input target manual di layar ini.

  Future<void> _complete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WarningStatusDialog(
        title: 'Kirim Retur Ini?',
        message:
            'Aksi ini akan otomatis men-generate data surat jalan ke ERP '
            'Ascend. Aksi ini tidak dapat dibatalkan.',
        actions: [
          StatusAction(
            label: 'Batal',
            isPrimary: false,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          StatusAction(
            label: 'Ya, Kirim',
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await _vm.markComplete();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_vm.completeError ?? 'Gagal mengirim retur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    widget.onHeaderChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ReturV3DetailViewModel>.value(
      value: _vm,
      child: Consumer<ReturV3DetailViewModel>(
        builder: (context, vm, _) {
          final canFlag = context.watch<PermissionViewModel>().can(
            'retur:update',
          );
          final showPrintFab =
              vm.header?.isTidakDiganti == true && vm.outputs.isNotEmpty;
          final isDiganti = vm.header?.isDiganti == true;
          final alreadyComplete = vm.header?.isComplete == true;
          // Langkah 1 (generate label + label-nya sudah dicetak minimal 1x,
          // lihat ReturV3DetailViewModel.step1Complete) harus selesai dulu
          // sebelum langkah 2 (scan turnover) bisa diakses — sinkron dengan
          // section-nya yang sekarang beneran dikunci
          // (_LockedStepPlaceholder), bukan cuma FAB-nya saja yang tampil
          // duluan padahal section-nya masih locked.
          // Selama status DIGANTI: FAB scan tampil sampai semua item
          // terpenuhi, lalu otomatis berganti jadi FAB "Kirim" (kalau
          // retur sudah ditandai complete, tidak ada FAB lagi — sudah
          // selesai).
          final showCompleteFab =
              isDiganti &&
              vm.step1Complete &&
              !alreadyComplete &&
              vm.canComplete &&
              canFlag;
          // Scan turnover juga wewenang Admin (retur:update) — digate di UI
          // supaya konsisten dengan FAB Kirim. Muncul begitu langkah 1
          // (generate + cetak label) selesai; turnover dicocokkan langsung
          // ke item retur, tidak ada langkah "tentukan target" lagi.
          final showScanFab =
              isDiganti &&
              vm.step1Complete &&
              !alreadyComplete &&
              !vm.canComplete &&
              canFlag;
          return Scaffold(
            backgroundColor: _kSurface,
            floatingActionButton: showPrintFab
                ? FloatingActionButton(
                    onPressed: _openPrintDialog,
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.print_rounded),
                  )
                : showCompleteFab
                ? FloatingActionButton.extended(
                    onPressed: vm.isCompleting ? null : _complete,
                    backgroundColor: _kSuccess,
                    foregroundColor: Colors.white,
                    icon: vm.isCompleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.local_shipping_rounded),
                    label: const Text('Kirim'),
                  )
                : showScanFab
                ? FloatingActionButton.extended(
                    onPressed: _openScanDialogAuto,
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

  Widget _buildBody(ReturV3DetailViewModel vm) {
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

    // Header info (no.retur/tanggal/pembeli/status) tidak diulang di sini —
    // sudah jelas dari kartu yang dipilih di panel kiri. Detail langsung
    // mulai dari section langkahnya (samakan dengan detail Goods Transfer).
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (header.isPending) _PendingSection(vm: vm, screen: this),
        // TIDAK_DIGANTI: cuma 1 langkah (generate label), tidak perlu badge
        // nomor. DIGANTI: 2 langkah berurutan — generate label per item
        // dulu (barang yang kembali tetap harus diklasifikasi jadi stok
        // nyata), baru turnover (scan pengganti) — makanya reuse section
        // yang sama dengan TIDAK_DIGANTI, diberi label "Langkah 1".
        if (header.isTidakDiganti) _TidakDigantiSection(vm: vm, screen: this),
        if (header.isDiganti) ...[
          _TidakDigantiSection(vm: vm, screen: this, stepNumber: 1),
          const SizedBox(height: 16),
          // Step-by-step: langkah 2 & 3 dikunci (tampil placeholder abu-abu,
          // bukan isinya) sampai langkah sebelumnya benar-benar selesai —
          // bukan cuma nomor urut kosmetik, tapi alur yang beneran gated.
          // Langkah 1 baru dianggap selesai kalau semua label sudah
          // digenerate DAN sudah dicetak minimal 1x (vm.step1Complete),
          // bukan cuma digenerate saja.
          if (vm.step1Complete) ...[
            _DigantiSection(vm: vm, screen: this, stepNumber: 2),
            const SizedBox(height: 16),
            if (vm.allItemsFulfilled)
              _KirimSection(vm: vm, stepNumber: 3)
            else
              const _LockedStepPlaceholder(
                stepNumber: 3,
                title: 'Pengiriman',
                message:
                    'Selesaikan penggantian item di langkah 2 dulu untuk lanjut ke langkah ini.',
              ),
          ] else ...[
            const _LockedStepPlaceholder(
              stepNumber: 2,
              title: 'Item yang Dipickup',
              message:
                  'Selesaikan generate & cetak label di langkah 1 dulu untuk lanjut ke langkah ini.',
            ),
            const SizedBox(height: 16),
            const _LockedStepPlaceholder(
              stepNumber: 3,
              title: 'Pengiriman',
              message:
                  'Selesaikan generate & cetak label di langkah 1, lalu penggantian item di langkah 2.',
            ),
          ],
        ],
      ],
    );
  }
}

// ── PENDING section ───────────────────────────────────────────────────

class _PendingSection extends StatelessWidget {
  final ReturV3DetailViewModel vm;
  final _ReturV3DetailScreenState screen;

  const _PendingSection({required this.vm, required this.screen});

  @override
  Widget build(BuildContext context) {
    // Keputusan diganti/tidak-diganti adalah wewenang Sales (retur:decide),
    // terpisah dari retur:update yang dipegang Admin (create/edit/scan/kirim).
    final canDecide = context.watch<PermissionViewModel>().can('retur:decide');

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
              'Item Retur',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _kText,
              ),
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          if (vm.items.isEmpty)
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
              itemCount: vm.items.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: _kBorder),
              itemBuilder: (context, i) =>
                  _PendingItemRow(number: i + 1, item: vm.items[i]),
            ),
          if (vm.items.isNotEmpty) ...[
            const Divider(height: 1, color: _kBorder),
            if (canDecide)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: vm.isDeciding
                            ? null
                            : () => screen._decide('TIDAK_DIGANTI'),
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Tidak Diganti'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.orange.shade800,
                          side: BorderSide(color: Colors.orange.shade300),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: vm.isDeciding
                            ? null
                            : () => screen._decide('DIGANTI'),
                        icon: const Icon(Icons.autorenew, size: 16),
                        label: const Text('Diganti'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              // Tidak punya retur:decide (bukan Sales) — jangan tampil
              // kosong begitu saja, tunjukkan bahwa ini memang sedang
              // menunggu keputusan pihak lain, bukan macet/error.
              const Padding(
                padding: EdgeInsets.all(14),
                child: _AwaitingApprovalBanner(),
              ),
          ],
        ],
      ),
    );
  }
}

/// Banner "menunggu persetujuan" — tampil di section PENDING untuk user
/// yang tidak punya `retur:decide` (mis. Admin), supaya jelas kalau retur
/// ini memang sedang menunggu keputusan Sales, bukan layar yang macet.
class _AwaitingApprovalBanner extends StatelessWidget {
  const _AwaitingApprovalBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Menunggu persetujuan — keputusan Diganti / Tidak Diganti.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.orange.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris item retur di section PENDING — satu baris saja, tampilan murni
/// (nama jenis, pcs, kondisi bagus/reject). Tanpa badge kategori BJ/FWIP
/// (beda dengan `_ItemTile` yang dipakai di section TIDAK_DIGANTI). Item
/// hanya bisa diisi lewat form pembuatan retur — section ini read-only,
/// tidak ada tombol tambah/hapus.
class _PendingItemRow extends StatelessWidget {
  final int number;
  final ReturV3Item item;

  const _PendingItemRow({required this.number, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$number.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.namaJenis ?? 'Jenis #${item.idJenis}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${item.pcs} pcs',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: item.isReject
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ReturV3KategoriInput.displayLabel(item.kategoriInput),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: item.isReject
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Baris item retur di section TIDAK_DIGANTI — format sama seperti
/// `_PendingItemRow` (satu baris: nama jenis, pcs, kondisi bagus/reject,
/// tanpa badge kategori BJ/FWIP), ditambah slot `trailing` untuk tombol
/// generate label / chip kode label yang sudah dibuat.
class _ItemTile extends StatelessWidget {
  final int number;
  final ReturV3Item item;
  final Widget? trailing;

  const _ItemTile({required this.number, required this.item, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$number.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _kMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              item.namaJenis ?? 'Jenis #${item.idJenis}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _kText,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${item.pcs} pcs',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kText,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: item.isReject
                  ? Colors.red.withValues(alpha: 0.1)
                  : Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ReturV3KategoriInput.displayLabel(item.kategoriInput),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: item.isReject
                    ? Colors.red.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

// ── TIDAK_DIGANTI section ───────────────────────────────────────────────

class _TidakDigantiSection extends StatefulWidget {
  final ReturV3DetailViewModel vm;
  final _ReturV3DetailScreenState screen;
  final int? stepNumber;

  const _TidakDigantiSection({
    required this.vm,
    required this.screen,
    this.stepNumber,
  });

  @override
  State<_TidakDigantiSection> createState() => _TidakDigantiSectionState();
}

class _TidakDigantiSectionState extends State<_TidakDigantiSection> {
  // null = ikut vm.step1Complete otomatis (collapse begitu semua item
  // selesai digenerate+dicetak); begitu user tap header sekali, pilihan
  // manual mereka menang sampai layar ini dibuang (ganti retur lain).
  bool? _expandedOverride;

  bool get _expanded => _expandedOverride ?? !widget.vm.step1Complete;

  void _toggle() => setState(() => _expandedOverride = !_expanded);

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final screen = widget.screen;
    final complete = vm.step1Complete;
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
          InkWell(
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  if (widget.stepNumber != null) ...[
                    _StepBadge(number: widget.stepNumber!, complete: complete),
                    const SizedBox(width: 8),
                  ],
                  const Expanded(
                    child: Text(
                      'Generate Label',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _kText,
                      ),
                    ),
                  ),
                  if (vm.outputs.isNotEmpty)
                    IconButton(
                      onPressed: screen._openPrintDialog,
                      tooltip: 'Cetak label',
                      icon: const Icon(
                        Icons.print_rounded,
                        size: 19,
                        color: _kPrimary,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 20,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, color: _kBorder),
            Builder(
              builder: (context) {
                // Generate label khusus Admin (retur:update) — user lain
                // (mis. Sales yang baru saja decide) cuma lihat status
                // "Menunggu", tidak ada tombol yang bisa mereka pencet.
                final canGenerate = context.watch<PermissionViewModel>().can(
                  'retur:update',
                );
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: vm.items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (context, i) {
                    final item = vm.items[i];
                    final generating = vm.generatingItemIds.contains(
                      item.idItem,
                    );
                    final output = item.hasGeneratedLabel
                        ? vm.outputs.cast<ReturV3Output?>().firstWhere(
                            (o) => o?.labelCode == item.generatedLabelCode,
                            orElse: () => null,
                          )
                        : null;
                    return _ItemTile(
                      number: i + 1,
                      item: item,
                      trailing: item.hasGeneratedLabel
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  margin: const EdgeInsets.only(left: 8),
                                  decoration: BoxDecoration(
                                    color: _kSuccess.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.generatedLabelCode!,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: _kSuccess,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _PrintCountBadge(
                                  count: output?.printCount ?? 0,
                                ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: !canGenerate
                                  ? Text(
                                      'Menunggu',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                        color: Colors.grey.shade400,
                                      ),
                                    )
                                  : SizedBox(
                                      height: 32,
                                      child: FilledButton(
                                        onPressed: generating
                                            ? null
                                            : () => screen._generateLabel(item),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _kPrimary,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 11.5,
                                          ),
                                        ),
                                        child: generating
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Text('Generate Label'),
                                      ),
                                    ),
                            ),
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Badge kecil ikon printer + berapa kali label item ini sudah dicetak —
/// dulunya cuma total ringkasan di bawah section, sekarang per-item.
class _PrintCountBadge extends StatelessWidget {
  final int count;

  const _PrintCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final printed = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: printed
            ? _kPrimary.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.print_rounded,
            size: 12,
            color: printed ? _kPrimary : Colors.grey.shade400,
          ),
          const SizedBox(width: 3),
          Text(
            '${count}x',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: printed ? _kPrimary : Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card placeholder untuk langkah DIGANTI yang belum bisa diakses karena
/// langkah sebelumnya belum selesai — badge nomornya abu-abu (bukan biru
/// seperti langkah aktif) + ikon gembok, supaya jelas ini bukan section
/// kosong biasa tapi memang "terkunci" sampai gilirannya.
class _LockedStepPlaceholder extends StatelessWidget {
  final int stepNumber;
  final String title;
  final String message;

  const _LockedStepPlaceholder({
    required this.stepNumber,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$stepNumber',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: Colors.grey.shade400,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge bulat kecil bernomor — dipakai untuk menandai urutan langkah pada
/// alur DIGANTI (1 = generate label, 2 = penggantian item, 3 = pengiriman).
/// Tidak dipakai sama sekali pada TIDAK_DIGANTI karena cuma ada 1 langkah
/// di sana. Warnanya berubah jadi hijau begitu langkah itu selesai — bukan
/// ikon centang terpisah, angkanya sendiri yang jadi penanda status.
class _StepBadge extends StatelessWidget {
  final int number;
  final bool complete;

  const _StepBadge({required this.number, this.complete = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: complete ? _kSuccess : _kPrimary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── DIGANTI section ─────────────────────────────────────────────────────

class _DigantiSection extends StatelessWidget {
  final ReturV3DetailViewModel vm;
  final _ReturV3DetailScreenState screen;
  final int? stepNumber;

  const _DigantiSection({
    required this.vm,
    required this.screen,
    this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = vm.header?.isComplete == true;
    // Turnover dicocokkan langsung ke item retur (like-for-like): satu baris
    // progress per item, target pcs = pcs item retur itu sendiri.

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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                if (stepNumber != null) ...[
                  _StepBadge(
                    number: stepNumber!,
                    complete: vm.allItemsFulfilled,
                  ),
                  const SizedBox(width: 8),
                ],
                const Text(
                  'Item yang Dipickup',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: vm.items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: _kBorder),
            itemBuilder: (context, i) {
              final item = vm.items[i];
              return _TurnoverItemBlock(
                number: i + 1,
                item: item,
                turnover: vm.turnoverFor(item.idItem),
                isComplete: isComplete,
                onUndoScan: screen._undoScan,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Langkah 3 alur DIGANTI — status/indikator flag kirim, terpisah dari
/// card progress turnover supaya alurnya kelihatan jelas 3 langkah
/// berurutan: generate label → progress turnover → dikirim.
class _KirimSection extends StatelessWidget {
  final ReturV3DetailViewModel vm;
  final int stepNumber;

  const _KirimSection({required this.vm, required this.stepNumber});

  @override
  Widget build(BuildContext context) {
    final isComplete = vm.header?.isComplete == true;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                _StepBadge(number: stepNumber, complete: isComplete),
                const SizedBox(width: 8),
                const Text(
                  'Pengiriman',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  isComplete
                      ? Icons.local_shipping_rounded
                      : vm.canComplete
                      ? Icons.check_circle_rounded
                      : Icons.qr_code_scanner_rounded,
                  size: 16,
                  color: isComplete || vm.canComplete ? _kSuccess : _kMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isComplete
                        ? 'Sudah dikirim.'
                        : vm.canComplete
                        ? 'Semua item terpenuhi — tekan tombol Kirim di kanan bawah.'
                        : 'Scan label lewat tombol Scan di kanan bawah sampai semua item terpenuhi.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isComplete || vm.canComplete ? _kSuccess : _kMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu tile progress per item retur yang dipickup (like-for-like): target
/// pcs = pcs item retur, dipenuhi lewat scan label existing dengan
/// kategori/jenis yang sama.
class _TurnoverItemBlock extends StatelessWidget {
  final int number;
  final ReturV3Item item;
  final ReturV3Turnover? turnover;
  final bool isComplete;
  final ValueChanged<int> onUndoScan;

  const _TurnoverItemBlock({
    required this.number,
    required this.item,
    required this.turnover,
    required this.isComplete,
    required this.onUndoScan,
  });

  @override
  Widget build(BuildContext context) {
    final scanned = turnover?.scannedPcs ?? 0;
    final targetPcs = turnover?.pcsAsal ?? item.pcs;
    final fulfilled = scanned >= targetPcs && targetPcs > 0;
    final namaJenis =
        turnover?.namaJenisAsal ??
        item.namaJenis ??
        'Jenis #${turnover?.idJenisAsal ?? item.idJenis}';
    final scans = turnover?.scans ?? const [];

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
                  '$scanned/$targetPcs pcs',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: fulfilled ? _kSuccess : _kMuted,
                  ),
                ),
              ],
            ),
            if (scans.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: scans
                    .map(
                      (s) => Chip(
                        label: Text(
                          '${s.labelCode} (${s.pcs})',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                        onDeleted: isComplete
                            ? null
                            : () => onUndoScan(s.idTurnover),
                        deleteIconColor: Colors.red.shade400,
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

// ── Print picker dialog (single group, mirrors retur_v2's) ──────────────

class _PrintPickerDialog extends StatefulWidget {
  final List<ReturV3Output> items;
  final void Function(List<ReturV3Output> selected) onPrint;

  const _PrintPickerDialog({required this.items, required this.onPrint});

  @override
  State<_PrintPickerDialog> createState() => _PrintPickerDialogState();
}

class _PrintPickerDialogState extends State<_PrintPickerDialog> {
  late final Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.items.map((e) => e.labelCode).toSet();
  }

  bool get _allSelected => _selected.length == widget.items.length;

  void _toggleAll() => setState(() {
    if (_allSelected) {
      _selected.clear();
    } else {
      _selected.addAll(widget.items.map((e) => e.labelCode));
    }
  });

  @override
  Widget build(BuildContext context) {
    final selectedItems = widget.items
        .where((e) => _selected.contains(e.labelCode))
        .toList();

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pilih Label untuk Dicetak',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _toggleAll,
                    child: Text(
                      _allSelected ? 'Batalkan Semua' : 'Pilih Semua',
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                shrinkWrap: true,
                itemCount: widget.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final item = widget.items[i];
                  final selected = _selected.contains(item.labelCode);
                  return InkWell(
                    onTap: () => setState(() {
                      if (selected) {
                        _selected.remove(item.labelCode);
                      } else {
                        _selected.add(item.labelCode);
                      }
                    }),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? _kPrimary.withValues(alpha: 0.06)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? _kPrimary.withValues(alpha: 0.35)
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_box
                                : Icons.check_box_outline_blank,
                            size: 18,
                            color: selected ? _kPrimary : Colors.grey.shade400,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.namaJenis?.isNotEmpty == true
                                      ? item.namaJenis!
                                      : item.labelCode,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  item.labelCode,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${item.qty} ${item.uom}'.trim(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _kPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: _kBorder),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: FilledButton.icon(
                onPressed: selectedItems.isEmpty
                    ? null
                    : () {
                        Navigator.of(context).pop();
                        widget.onPrint(selectedItems);
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: _kPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.print, size: 16),
                label: Text('Cetak ${selectedItems.length} Label'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
