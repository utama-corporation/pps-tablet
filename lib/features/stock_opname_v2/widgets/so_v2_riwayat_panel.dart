// lib/features/stock_opname_v2/widgets/so_v2_riwayat_panel.dart
//
// Isi panel "Riwayat Stock Opname" — daftar SELURUH sesi stock opname
// dengan paging server-side. Dipakai di dalam `ProductionOverlayDrawer`
// sehingga panel ini meng-overlay grid kategori, bukan menyingkarkan grid —
// grid utama tetap live dan full width saat panel dibuka.
import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../features/production/shared/widgets/production_filter_chip.dart';
import '../model/so_v2_kategori.dart';
import '../model/so_v2_riwayat_sesi.dart';
import '../view_model/so_v2_riwayat_view_model.dart';
import 'so_v2_status_badge.dart';

const _kPanelSurface = Color(0xFFF8F9FB);
const _kPanelBorder = Color(0xFFECEEF1);
const _kPanelInk = Color(0xFF1A1D23);
const _kPanelMuted = Color(0xFF767E8C);
const _kPanelAccent = Color(0xFF1E6FD9);

/// Panel riwayat yang bisa dibuka/tutup dari tepi kanan layar kategori.
/// Header berisi tombol tutup + pencarian + filter status; badan berisi
/// daftar kartu sesi dengan paging server-side (`PagedListView`) sehingga
/// halaman berikutnya otomatis diambil saat liste nearing akhir.
///
/// [isOpen] dipakai agar isi panel (dan `PagedListView`-nya) baru dibuat
/// saat drawer benar-benar dibuka — selama itu paging tidak pernah
/// meminta halaman 1.
class SoV2RiwayatPanel extends StatefulWidget {
  final SoV2RiwayatViewModel vm;
  final bool isOpen;
  final VoidCallback onClose;
  final ValueChanged<SoV2RiwayatSesi> onOpenSesi;

  const SoV2RiwayatPanel({
    super.key,
    required this.vm,
    required this.isOpen,
    required this.onClose,
    required this.onOpenSesi,
  });

  @override
  State<SoV2RiwayatPanel> createState() => _SoV2RiwayatPanelState();
}

class _SoV2RiwayatPanelState extends State<SoV2RiwayatPanel> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        _buildFilters(),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kPanelBorder)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
        child: Row(
          children: [
            Tooltip(
              message: 'Sembunyikan Riwayat',
              waitDuration: const Duration(milliseconds: 400),
              child: IconButton(
                onPressed: widget.onClose,
                icon: const Icon(
                  Icons.keyboard_double_arrow_right_rounded,
                  size: 16,
                ),
                color: const Color(0xFF9CA3AF),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.history_rounded, size: 16, color: _kPanelAccent),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Riwayat Stock Opname',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kPanelInk,
                ),
              ),
            ),
            Tooltip(
              message: 'Muat ulang',
              waitDuration: const Duration(milliseconds: 400),
              child: IconButton(
                onPressed: widget.vm.refresh,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                color: const Color(0xFF9CA3AF),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    final vm = widget.vm;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 8),
          TextField(
            controller: _searchCtl,
            onChanged: vm.setSearchDebounced,
            onSubmitted: vm.setSearchDebounced,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFFAFBFC),
              hintText: 'Cari no. SO / kategori...',
              hintStyle: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFFA5ADBA),
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 16,
                color: Color(0xFF9CA3AF),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 30,
                minHeight: 30,
              ),
              suffixIcon: _searchCtl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 15),
                      color: const Color(0xFF9CA3AF),
                      onPressed: () {
                        _searchCtl.clear();
                        vm.setSearchDebounced('');
                        setState(() {});
                      },
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: _kPanelAccent, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 22,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ProductionFilterChip(
                  label: 'Semua',
                  selected: vm.statusFilter == null,
                  onTap: () => vm.setStatusFilter(null),
                ),
                for (final status in SoV2Status.values) ...[
                  const SizedBox(width: 6),
                  ProductionFilterChip(
                    label: status.label,
                    selected: vm.statusFilter == status,
                    onTap: () => vm.setStatusFilter(status),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ColoredBox(
      color: _kPanelSurface,
      child: PagingListener<int, SoV2RiwayatSesi>(
        controller: widget.vm.pagingController,
        builder: (context, state, fetchNextPage) {
          // PENTING: pemicu fetch di v5 ada di `PagedListView`
          // (_PagedLayoutBuilderState), BUKAN di `PagingListener` yang cuma
          // `ValueListenableBuilder`. Kalau daftar dibuat manual dengan
          // `ListView.builder`, `fetchNextPage()` tidak pernah terpanggil dan
          // panel mentok di spinner halaman pertama.
          final loaded = state.items?.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (loaded != null) _buildCounter(loaded),
              Expanded(
                child: RefreshIndicator(
                  // PagingController.refresh() sinkron (void), dibungkus agar
                  // RefreshIndicator menutup setelah state berikutnya render.
                  onRefresh: () async => widget.vm.refresh(),
                  child: PagedListView<int, SoV2RiwayatSesi>(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
                    builderDelegate:
                        PagedChildBuilderDelegate<SoV2RiwayatSesi>(
                          itemBuilder: (context, sesi, _) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _RiwayatSesiCard(
                              sesi: sesi,
                              onTap: () => widget.onOpenSesi(sesi),
                            ),
                          ),
                          firstPageProgressIndicatorBuilder: (_) =>
                              const _StatusBlock(
                                child: CircularProgressIndicator(),
                              ),
                          firstPageErrorIndicatorBuilder: (_) => _StatusBlock(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${state.error}',
                                  textAlign: TextAlign.center,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: _kPanelMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                TextButton.icon(
                                  onPressed: fetchNextPage,
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 15,
                                  ),
                                  label: const Text(
                                    'Coba lagi',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          newPageErrorIndicatorBuilder: (_) => _StatusBlock(
                            child: TextButton.icon(
                              onPressed: fetchNextPage,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                size: 15,
                              ),
                              label: const Text(
                                'Gagal memuat, coba lagi',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ),
                          newPageProgressIndicatorBuilder: (_) =>
                              const _StatusBlock(
                                child: SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                          noItemsFoundIndicatorBuilder: (_) =>
                              const _StatusBlock(
                                child: Text(
                                  'Belum ada riwayat stock opname',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: _kPanelMuted,
                                  ),
                                ),
                              ),
                          noMoreItemsIndicatorBuilder: (_) => _StatusBlock(
                            child: Text(
                              widget.vm.totalRecords > 0
                                  ? 'Semua ${widget.vm.totalRecords} sesi sudah ditampilkan'
                                  : 'Riwayat sudah ditampilkan semua',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _kPanelMuted,
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// "Menampilkan X dari Y sesi" — X = baris yang sudah termuat, Y = total
  /// dari meta paging server.
  Widget _buildCounter(int loaded) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 12),
      child: Text(
        'Menampilkan $loaded dari ${widget.vm.totalRecords} sesi',
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: _kPanelMuted,
        ),
      ),
    );
  }
}

/// Pembungkus untuk semua indikator status milik `PagedChildBuilderDelegate`
/// (loading / error / kosong / habis) supaya punya tinggi & lebar yang rapi di
/// tengah area daftar.
class _StatusBlock extends StatelessWidget {
  final Widget child;

  const _StatusBlock({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 14),
      child: Center(child: child),
    );
  }
}

/// Satu kartu sesi riwayat — nama kategori, nomor SO, status, rentang
/// tanggal, dan progress scan saat sesi itu dijalankan.
class _RiwayatSesiCard extends StatelessWidget {
  final SoV2RiwayatSesi sesi;
  final VoidCallback onTap;

  const _RiwayatSesiCard({required this.sesi, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final percent = (sesi.progress * 100).round();
    final color = sesi.status.color;
    final mulai = sesi.startDate == null
        ? '-'
        : formatDateToShortId(sesi.startDate!);
    final selesai = sesi.completedAt == null
        ? '-'
        : formatDateToShortId(sesi.completedAt!);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _kPanelBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sesi.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _kPanelInk,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SoV2StatusBadge(status: sesi.status),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                sesi.stockOpnameNo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: _kPanelMuted),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 11,
                    color: _kPanelMuted,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      '$mulai → $selesai',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: _kPanelMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${sesi.scannedCount}/${sesi.labelCount} label',
                    style: const TextStyle(fontSize: 10.5, color: _kPanelMuted),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: sesi.progress.clamp(0, 1),
                  minHeight: 4,
                  backgroundColor: const Color(0xFFF1F2F4),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
