import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/confirm_dialog.dart';
import '../../../common/widgets/loading_dialog.dart';
import '../../../core/utils/date_formatter.dart';
import '../model/so_v2_kategori.dart';
import '../view_model/so_v2_kategori_list_view_model.dart';
import '../view_model/so_v2_socket_manager.dart';
import '../widgets/so_v2_generate_preview_dialog.dart';
import '../widgets/so_v2_period_picker_dialog.dart';
import 'so_v2_detail_screen.dart';

const _kSurface = Color(0xFFF8F9FB);
const _kBorder = Color(0xFFECEEF1);
const _kInk = Color(0xFF1A1D23);
const _kMuted = Color(0xFF767E8C);

class SoV2KategoriListScreen extends StatefulWidget {
  const SoV2KategoriListScreen({super.key});

  @override
  State<SoV2KategoriListScreen> createState() => _SoV2KategoriListScreenState();
}

class _SoV2KategoriListScreenState extends State<SoV2KategoriListScreen> {
  late final SoV2KategoriListViewModel _vm;
  final Set<String> _joinedRooms = {};
  VoidCallback? _unsubscribeHasilInserted;
  VoidCallback? _unsubscribeHasilDeleted;

  @override
  void initState() {
    super.initState();
    _vm = SoV2KategoriListViewModel();
    _vm.addListener(_syncSocketRooms);
    _vm.load();

    final socketVm = context.read<SoV2SocketManager>();
    _unsubscribeHasilInserted = socketVm.addHasilInsertedListener(
      _onHasilInserted,
    );
    _unsubscribeHasilDeleted = socketVm.addHasilDeletedListener(
      _onHasilDeleted,
    );
  }

  @override
  void dispose() {
    _unsubscribeHasilInserted?.call();
    _unsubscribeHasilDeleted?.call();
    final socketVm = context.read<SoV2SocketManager>();
    for (final room in _joinedRooms) {
      socketVm.leaveStockOpname(room);
    }
    _vm.removeListener(_syncSocketRooms);
    _vm.dispose();
    super.dispose();
  }

  /// Kartu di grid ini menampilkan progress scan dari banyak SO sekaligus
  /// (satu per kategori), jadi — beda dari [SoV2DetailScreen] yang cuma
  /// join 1 room — di sini kita join room utk SEMUA SO yang sedang punya
  /// nomor (notStarted belum punya stockOpnameNo, jadi otomatis dilewati).
  /// Dipanggil ulang tiap [_vm] berubah (reload/riwayat) supaya room selalu
  /// sinkron dengan SO yang lagi ditampilkan.
  void _syncSocketRooms() {
    final socketVm = context.read<SoV2SocketManager>();
    final current = _vm.items
        .map((k) => k.stockOpnameNo)
        .whereType<String>()
        .toSet();

    for (final room in current.difference(_joinedRooms)) {
      socketVm.joinStockOpname(room);
    }
    for (final room in _joinedRooms.difference(current)) {
      socketVm.leaveStockOpname(room);
    }
    _joinedRooms
      ..clear()
      ..addAll(current);
  }

  void _onHasilInserted(SoV2HasilInsertedEvent event) {
    if (!mounted) return;
    _vm.applyScan(event.stockOpnameNo);
  }

  void _onHasilDeleted(SoV2HasilDeletedEvent event) {
    if (!mounted) return;
    _vm.applyUnscan(event.stockOpnameNo);
  }

  Future<void> _openRiwayat() async {
    final now = DateTime.now();
    final period = await showDialog<({int year, int month})>(
      context: context,
      builder: (_) => SoV2PeriodPickerDialog(
        initialYear: _vm.riwayatPeriod?.year ?? now.year,
        initialMonth: _vm.riwayatPeriod?.month ?? now.month,
      ),
    );
    if (period == null) return;
    _vm.loadRiwayat(year: period.year, month: period.month);
  }

  Future<void> _onTapKategori(SoV2Kategori kategori) async {
    if (kategori.status == SoV2Status.notStarted) {
      if (_vm.isRiwayatMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data stock opname pada periode ini'),
          ),
        );
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LoadingDialog(message: 'Memuat preview...'),
      );
      final preview = await _vm.previewGenerate(
        categoryId: kategori.categoryId,
      );
      if (!mounted) return;
      // showDialog default-nya push ke root Navigator (useRootNavigator:
      // true), sementara layar ini sendiri hidup di nested shell Navigator
      // milik AppShell — Navigator.pop(context) polos bakal salah sasaran
      // (nge-pop shell Navigator, bukan dialog loading-nya).
      Navigator.of(context, rootNavigator: true).pop(); // close loading
      if (preview.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(preview.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      final confirmed = await showSoV2GeneratePreviewDialog(
        context,
        preview: preview.preview!,
      );
      if (confirmed != true) return;

      final res = await _vm.generate(categoryId: kategori.categoryId);
      if (!mounted) return;
      if (res.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
      final result = res.result!;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SoV2DetailScreen(
            stockOpnameNo: result['stockOpnameNo'].toString(),
            categoryCode:
                result['categoryCode']?.toString() ?? kategori.categoryCode,
            categoryName: kategori.categoryName,
          ),
        ),
      );
      if (mounted) _vm.load();
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SoV2DetailScreen(
            stockOpnameNo: kategori.stockOpnameNo!,
            categoryCode: kategori.categoryCode,
            categoryName: kategori.categoryName,
          ),
        ),
      );
      if (mounted) _vm.load();
    }
  }


  Future <void> _onDoubleTapKategori(SoV2Kategori kategori) async{
    if (kategori.status != SoV2Status.completed){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stock opname belum selesai!')
        )
      );

      return;
    }

    //if (kategori.status == SoV2Status.notStarted) {
      if (_vm.isRiwayatMode) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ada data stock opname pada periode ini'),
          ),
        );
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const LoadingDialog(message: 'Memuat preview...'),
      );
      final preview = await _vm.previewGenerate(
        categoryId: kategori.categoryId,
      );
      if (!mounted) return;
      // showDialog default-nya push ke root Navigator (useRootNavigator:
      // true), sementara layar ini sendiri hidup di nested shell Navigator
      // milik AppShell — Navigator.pop(context) polos bakal salah sasaran
      // (nge-pop shell Navigator, bukan dialog loading-nya).
      Navigator.of(context, rootNavigator: true).pop(); // close loading
      if (preview.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(preview.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      final confirmed = await showSoV2GeneratePreviewDialog(
        context,
        preview: preview.preview!,
      );
      if (confirmed != true) return;

      final res = await _vm.generate(categoryId: kategori.categoryId);
      if (!mounted) return;
      if (res.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.errorMessage!),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }
      final result = res.result!;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SoV2DetailScreen(
            stockOpnameNo: result['stockOpnameNo'].toString(),
            categoryCode:
                result['categoryCode']?.toString() ?? kategori.categoryCode,
            categoryName: kategori.categoryName,
          ),
        ),
      );
      if (mounted) _vm.load();
//     } else {
//       await Navigator.of(context).push(
//         MaterialPageRoute(
//           builder: (_) => SoV2DetailScreen(
//             stockOpnameNo: kategori.stockOpnameNo!,
//             categoryCode: kategori.categoryCode,
//             categoryName: kategori.categoryName,
//           ),
//         ),
//       );
//       if (mounted) _vm.load();
//     }
  }

  Future<void> _onDeleteKategori(SoV2Kategori kategori) async {
    final stockOpnameNo = kategori.stockOpnameNo;
    if (stockOpnameNo == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Stock Opname',
        message:
            'Yakin ingin menghapus stock opname $stockOpnameNo '
            '("${kategori.categoryName}")? Semua data hasil scan yang '
            'sudah tercatat akan ikut terhapus dan tidak dapat dikembalikan.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true) return;

    final errorMessage = await _vm.deleteStockOpname(stockOpnameNo);
    if (!mounted) return;
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$stockOpnameNo berhasil dihapus'),
        backgroundColor: Colors.green.shade700,
      ),
    );
    _vm.load();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SoV2KategoriListViewModel>.value(
      value: _vm,
      child: Consumer<SoV2KategoriListViewModel>(
        builder: (context, vm, _) {
          return Scaffold(
            backgroundColor: _kSurface,
            body: Stack(
              children: [
                Positioned.fill(
                  child: RefreshIndicator(
                    onRefresh: () => vm.isRiwayatMode
                        ? vm.loadRiwayat(
                            year: vm.riwayatPeriod!.year,
                            month: vm.riwayatPeriod!.month,
                          )
                        : vm.load(),
                    child: _buildBody(vm),
                  ),
                ),
                const Positioned(top: 16, left: 16, child: _StatusLegend()),
                Positioned(
                  top: 12,
                  right: 16,
                  child: _RiwayatFilterChip(
                    period: vm.riwayatPeriod,
                    onTap: _openRiwayat,
                    onClear: vm.load,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(SoV2KategoriListViewModel vm) {
    if (vm.isLoading && vm.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null && vm.items.isEmpty) {
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
    if (vm.items.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Belum ada kategori')),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 176).floor().clamp(
          1,
          12,
        );
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
          itemCount: vm.items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.15,
          ),
          itemBuilder: (context, index) {
            final kategori = vm.items[index];
            return _KategoriTile(
              kategori: kategori,
              onTap: () => _onTapKategori(kategori),
              onDoubleTap: () => _onDoubleTapKategori(kategori),
              //onDoubleTap: () =>  _onDoubleTapKategori(kategori),
              dimmed: vm.isRiwayatMode && kategori.stockOpnameNo == null,
              onDelete: (vm.isRiwayatMode || kategori.stockOpnameNo == null)
                  ? null
                  : () => _onDeleteKategori(kategori),
            );
          },
        );
      },
    );
  }
}

class _KategoriTile extends StatelessWidget {
  final SoV2Kategori kategori;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback? onDelete;
  final bool dimmed;

  const _KategoriTile({
    required this.kategori,
    required this.onTap,
    required this.onDoubleTap,
    this.onDelete,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (kategori.progress * 100).round();
    final complete =
        kategori.labelCount > 0 && kategori.scannedCount >= kategori.labelCount;
    final progressColor = complete
        ? const Color(0xFF0A7349)
        : const Color(0xFF1E6FD9);
    final startLabel = kategori.startDate == null
        ? null
        : formatDateToShortId(kategori.startDate);
    final completedLabel = kategori.completedAt == null
        ? null
        : formatDateToShortId(kategori.completedAt);

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onLongPress: onDelete,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        kategori.categoryName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                          height: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _StatusDot(color: kategori.status.color),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  kategori.stockOpnameNo ?? 'Belum ada nomor SO',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: _kMuted),
                ),
                if (startLabel != null) ...[
                  const SizedBox(height: 4),
                  _DateInfo(label: 'Mulai', value: startLabel, color: _kMuted),
                  const SizedBox(height: 2),
                  _DateInfo(
                    label: 'Selesai',
                    value: completedLabel ?? '-',
                    color: completedLabel != null
                        ? const Color(0xFF0A7349)
                        : _kMuted,
                  ),
                ],
                if (kategori.status == SoV2Status.inProgress &&
                    kategori.workingLocations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _WorkingLocationsRow(locations: kategori.workingLocations),
                ],
                const Spacer(),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${kategori.scannedCount}/${kategori.labelCount} label',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: _kMuted,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: kategori.progress.clamp(0, 1),
                    minHeight: 5,
                    backgroundColor: const Color(0xFFF1F2F4),
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Baris ringkas lokasi yang sedang aktif dikerjakan pada kategori yang
/// berjalan — detail lokasi & user ditampilkan lewat tooltip karena kartu
/// grid ruangnya sempit.
class _WorkingLocationsRow extends StatelessWidget {
  final List<SoV2KategoriWorkingLocation> locations;

  const _WorkingLocationsRow({required this.locations});

  @override
  Widget build(BuildContext context) {
    final codes = locations.map((l) => l.lokasi).join(', ');
    final tooltip = locations
        .map((l) {
          final users = l.users.map((u) => u.displayName).join(', ');
          return users.isEmpty ? l.lokasi : '${l.lokasi} · $users';
        })
        .join('\n');

    return Tooltip(
      message: tooltip,
      child: Row(
        children: [
          const Icon(Icons.bolt_rounded, size: 11, color: Color(0xFF0A7349)),
          const SizedBox(width: 3),
          Expanded(
            child: Text(
              codes,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0A7349),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DateInfo({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.75),
            ),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Titik status dengan lingkaran halo lembut di sekelilingnya.
class _StatusDot extends StatelessWidget {
  final Color color;

  const _StatusDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      margin: const EdgeInsets.only(top: 1),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Legenda arti warna titik status pada tiap kartu kategori.
class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in SoV2Status.values) ...[
              if (status != SoV2Status.values.first) const SizedBox(width: 14),
              _LegendDot(status: status),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final SoV2Status status;

  const _LegendDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusDot(color: status.color),
        const SizedBox(width: 5),
        Text(
          status.label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _kMuted,
          ),
        ),
      ],
    );
  }
}

/// Filter mengambang di pojok kanan-atas konten (bukan bar penuh) supaya
/// tidak menumpuk dengan compact app bar global milik AppShell.
class _RiwayatFilterChip extends StatelessWidget {
  final ({int year, int month})? period;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _RiwayatFilterChip({
    required this.period,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final active = period != null;
    final color = active ? const Color(0xFFB45309) : const Color(0xFF1E6FD9);
    final bgColor = active ? const Color(0xFFFFF7ED) : Colors.white;
    final borderColor = active ? const Color(0xFFFCD9A8) : _kBorder;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: EdgeInsets.fromLTRB(12, 8, active ? 6 : 12, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      active
                          ? Icons.history_rounded
                          : Icons.calendar_month_rounded,
                      size: 15,
                      color: color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      active
                          ? '${soV2MonthName(period!.month)} ${period!.year}'
                          : 'Riwayat',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (active)
              InkWell(
                onTap: onClear,
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 10, 8),
                  child: Icon(Icons.close_rounded, size: 15, color: color),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
