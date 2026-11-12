import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/atlas_data_table.dart';
import '../../../common/widgets/confirm_dialog.dart';
import '../../../common/widgets/interactive_popover.dart';
import '../../../common/widgets/row_action_popover.dart';
import '../../../common/widgets/search_dropdown_field.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_error.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/master_blok_lokasi_models.dart';
import '../repository/master_blok_lokasi_repository.dart';
import '../view_model/master_blok_lokasi_view_model.dart';
import 'blok_form_dialog.dart';
import 'lokasi_form_dialog.dart';

class MasterBlokLokasiScreen extends StatefulWidget {
  const MasterBlokLokasiScreen({super.key, this.repository});

  final MasterBlokLokasiRepository? repository;

  @override
  State<MasterBlokLokasiScreen> createState() =>
      _MasterBlokLokasiScreenState();
}

class _MasterBlokLokasiScreenState extends State<MasterBlokLokasiScreen> {
  late final MasterBlokLokasiViewModel vm;
  final TextEditingController _blokSearch = TextEditingController();
  final TextEditingController _lokasiSearch = TextEditingController();
  final FocusNode _blokFocus = FocusNode();
  final FocusNode _lokasiFocus = FocusNode();
  final InteractivePopover _popover = InteractivePopover();

  KategoriKonfig? _jenisKategori;
  JenisOption? _jenisItem;

  @override
  void initState() {
    super.initState();
    vm = MasterBlokLokasiViewModel(
      widget.repository ??
          MasterBlokLokasiRepository(api: context.read<ApiClient>()),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!context.read<PermissionViewModel>().can(
        'datamasterbloklokasi:read',
      )) {
        return;
      }
      unawaited(vm.loadMaster());
      unawaited(vm.loadBloks());
    });
  }

  @override
  void dispose() {
    _popover.dispose();
    _blokFocus.dispose();
    _lokasiFocus.dispose();
    _blokSearch.dispose();
    _lokasiSearch.dispose();
    vm.dispose();
    super.dispose();
  }

  bool _can(String action) =>
      context.read<PermissionViewModel>().can('datamasterbloklokasi:$action');

  // ── Blok ───────────────────────────────────────────────────────────────────

  Future<void> _openBlokForm({BlokRow? edit}) async {
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: BlokFormDialog(viewModel: vm, edit: edit),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? 'Blok berhasil disimpan: $saved'
              : 'Blok berhasil diubah: $saved',
        ),
      ),
    );
  }

  void _onBlokLongPress(BlokRow blok, Offset position) {
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(220.0, 560.0).toDouble();
    _popover.show(
      context: context,
      globalPosition: position,
      child: RowActionPopover(
        title: 'Blok ${blok.blok}',
        subtitle: blok.namaWarehouse,
        icon: Icons.location_on_outlined,
        accent: const Color(0xFF0E7490),
        canUpdate: _can('update'),
        canDelete: _can('delete'),
        onEdit: () => _openBlokForm(edit: blok),
        onDelete: () => _confirmDeleteBlok(blok),
        onClose: _popover.hide,
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

  Future<void> _confirmDeleteBlok(BlokRow blok) async {
    if (!_can('delete')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Blok',
        message:
            'Hapus blok ${blok.blok}? Seluruh lokasi dan relasi jenis di dalamnya ikut terhapus.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await vm.deleteBlok(blok.blok);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Blok ${blok.blok} berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  // ── Lokasi ─────────────────────────────────────────────────────────────────

  Future<void> _openLokasiForm({LokasiRow? edit}) async {
    if (vm.selectedBlok == null) return;
    if (edit == null && !_can('create')) return;
    if (edit != null && !_can('update')) return;
    final saved = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChangeNotifierProvider.value(
        value: vm,
        child: LokasiFormDialog(viewModel: vm, edit: edit),
      ),
    );
    if (saved == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          edit == null
              ? 'Lokasi berhasil disimpan'
              : 'Lokasi berhasil diubah',
        ),
      ),
    );
  }

  void _onLokasiLongPress(LokasiRow row, Offset position) {
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveMaxHeight =
        (screenHeight - 32).clamp(220.0, 560.0).toDouble();
    _popover.show(
      context: context,
      globalPosition: position,
      child: RowActionPopover(
        title: 'Lokasi #${row.idLokasi} · ${row.blok}',
        subtitle: row.description,
        icon: Icons.where_to_vote_outlined,
        accent: const Color(0xFF0E7490),
        canUpdate: _can('update'),
        canDelete: _can('delete'),
        onEdit: () => _openLokasiForm(edit: row),
        onDelete: () => _confirmDeleteLokasi(row),
        onClose: _popover.hide,
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

  Future<void> _confirmDeleteLokasi(LokasiRow row) async {
    if (!_can('delete')) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: 'Hapus Lokasi',
        message:
            'Hapus lokasi #${row.idLokasi} (${row.description})? Relasi jenis di lokasi ini ikut terhapus.',
        confirmLabel: 'Hapus',
        confirmIcon: Icons.delete_outline_rounded,
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await vm.deleteLokasi(row);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lokasi #${row.idLokasi} berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  // ── Jenis ──────────────────────────────────────────────────────────────────

  Future<void> _addJenis() async {
    final kategori = _jenisKategori;
    final jenis = _jenisItem;
    if (kategori == null || jenis == null || !_can('create')) return;
    try {
      await vm.addLokasiJenis(idKategori: kategori.id, idJenis: jenis.id);
      if (!mounted) return;
      setState(() => _jenisItem = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jenis berhasil ditambahkan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  Future<void> _removeJenis(LokasiJenisRow row) async {
    if (!_can('delete')) return;
    try {
      await vm.removeLokasiJenis(row);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${row.namaJenis} berhasil dihapus dari lokasi')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<PermissionViewModel>().can('datamasterbloklokasi:read')) {
      return const Scaffold(
        body: Center(
          child: Text('Anda tidak memiliki akses ke Blok & Lokasi.'),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: ChangeNotifierProvider.value(
        value: vm,
        child: Consumer<MasterBlokLokasiViewModel>(
          builder: (context, vm, _) => Row(
            children: [
              SizedBox(width: 330, child: _buildBlokPanel(vm)),
              const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE5E7EB)),
              Expanded(child: _buildLokasiPanel(vm)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Panel kiri: blok ───────────────────────────────────────────────────────

  Widget _buildBlokPanel(MasterBlokLokasiViewModel vm) {
    final bloks = vm.bloks;
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text(
                  'BLOK',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B778C),
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                if (_can('create'))
                  IconButton.filledTonal(
                    key: const ValueKey('blok-add'),
                    tooltip: 'Tambah blok',
                    onPressed: () => _openBlokForm(),
                    icon: const Icon(Icons.add),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              key: const ValueKey('blok-search'),
              focusNode: _blokFocus,
              controller: _blokSearch,
              onChanged: (v) => vm.setBlokQuery(v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari blok…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isCollapsed: true,
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
          ),
          Expanded(
            child: bloks.isEmpty && !vm.blokLoading && vm.blokError.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 44,
                            color: Color(0xFFC1C7D0),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Belum ada blok',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF44546F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : vm.blokError.isNotEmpty && bloks.isEmpty
                ? _panelError(message: vm.blokError, onRetry: vm.loadBloks)
                : RefreshIndicator(
                    onRefresh: vm.loadBloks,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: bloks.length,
                      itemBuilder: (_, i) => _blokTile(vm, bloks[i]),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Text(
              '${bloks.length} dari ${vm.blokTotal} blok',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B778C)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blokTile(MasterBlokLokasiViewModel vm, BlokRow blok) {
    final selected = vm.selectedBlok == blok.blok;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => _onBlokLongPress(
        blok,
        details.globalPosition,
      ),
      child: InkWell(
        key: ValueKey('blok-tile-${blok.blok}'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => vm.selectBlok(
          vm.selectedBlok == blok.blok ? null : blok.blok,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE3F2FD) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF1565C0) : Colors.transparent,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1565C0)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  blok.blok,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: selected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      blok.namaWarehouse.isEmpty
                          ? 'Warehouse #${blok.idWarehouse}'
                          : blok.namaWarehouse,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF172B4D),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${vm.selectedBlok == blok.blok ? 'Terpilih' : 'Tap untuk isi lokasi'} · ketuk lama = opsi',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF1565C0),
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Panel kanan: lokasi + jenis ────────────────────────────────────────────

  Widget _buildLokasiPanel(MasterBlokLokasiViewModel vm) {
    final blok = vm.selectedBlok;
    if (blok == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_outlined,
              size: 44,
              color: Color(0xFFC1C7D0),
            ),
            SizedBox(height: 12),
            Text(
              'Pilih blok di kiri untuk melihat lokasinya',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF44546F),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final lokasis = vm.lokasis;
    final selectedLokasi = vm.selectedLokasi;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOKASI — BLOK $blok',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B778C),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text(
                      'Ketuk baris lokasi untuk mengatur jenis',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_can('create'))
                FilledButton.icon(
                  key: const ValueKey('lokasi-add'),
                  onPressed: () => _openLokasiForm(),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Tambah Lokasi'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            key: const ValueKey('lokasi-search'),
            focusNode: _lokasiFocus,
            controller: _lokasiSearch,
            onChanged: (v) => vm.setLokasiQuery(v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari deskripsi lokasi…',
              prefixIcon: const Icon(Icons.search, size: 20),
              isCollapsed: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: lokasis.isEmpty && !vm.lokasiLoading && vm.lokasiError.isEmpty
                ? RefreshIndicator(
                    onRefresh: vm.loadLokasi,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.where_to_vote_outlined,
                              size: 44,
                              color: Color(0xFFC1C7D0),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Belum ada lokasi di blok ini',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF44546F),
                              ),
                            ),
                            if (_can('create')) ...[
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: () => _openLokasiForm(),
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Lokasi Pertama'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  )
                : vm.lokasiError.isNotEmpty && lokasis.isEmpty
                ? _panelError(
                    message: vm.lokasiError,
                    onRetry: vm.loadLokasi,
                  )
                : RefreshIndicator(
                    onRefresh: vm.loadLokasi,
                    child: AtlasDataTable<LokasiRow>(
                      columns: _lokasiColumns,
                      items: lokasis,
                      isLoading: vm.lokasiLoading,
                      errorMessage: lokasis.isEmpty ? vm.lokasiError : '',
                      onRowTap: (row) => vm.selectLokasi(row),
                      onRowLongPress: _onLokasiLongPress,
                      selectedPredicate: (row) =>
                          vm.selectedLokasi?.idLokasi == row.idLokasi &&
                          vm.selectedLokasi?.blok == row.blok,
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 16, 0),
          child: Text(
            '${lokasis.length} dari ${vm.lokasiTotal} lokasi · ketuk baris untuk mengatur jenis',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B778C)),
          ),
        ),
        Container(
          constraints: const BoxConstraints(maxHeight: 190),
          margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: _buildJenisPanel(vm, selectedLokasi),
        ),
      ],
    );
  }

  Widget _buildJenisPanel(
    MasterBlokLokasiViewModel vm,
    LokasiRow? selectedLokasi,
  ) {
    final master = vm.master;
    final jenisKategoris = master?.jenisKategoris ?? const <KategoriKonfig>[];
    if (selectedLokasi == null) {
      return const Center(
        child: Text(
          'Pilih lokasi di atas untuk mengatur jenis',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF94A3B8),
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final jenisList = vm.lokasiJenis;
    final items = vm.jenisFor(_jenisKategori?.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'JENIS — LOKASI #${selectedLokasi.idLokasi}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B778C),
                letterSpacing: 1.1,
              ),
            ),
            const Spacer(),
            if (vm.jenisLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (vm.jenisError.isNotEmpty)
          Text(
            vm.jenisError,
            style: TextStyle(fontSize: 11, color: Colors.red.shade700),
          ),
        if (vm.jenisError.isEmpty && jenisList.isEmpty && !vm.jenisLoading)
          const Text(
            'Belum ada jenis. Tambah lewat dropdown di bawah.',
            style: TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Color(0xFF94A3B8),
            ),
          ),
        if (jenisList.isNotEmpty)
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final row in jenisList)
                    InputChip(
                      label: Text('${row.namaKategori} · ${row.namaJenis}'),
                      onDeleted: _can('delete')
                          ? () => _removeJenis(row)
                          : null,
                      deleteIcon: const Icon(Icons.close, size: 14),
                    ),
                ],
              ),
            ),
          ),
        if (_can('create')) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 170,
                child: SearchDropdownField<KategoriKonfig>(
                  items: jenisKategoris,
                  value: _jenisKategori,
                  onChanged: (v) {
                    setState(() {
                      _jenisKategori = v;
                      _jenisItem = null;
                    });
                    if (v != null) unawaited(vm.loadJenis(v.id));
                  },
                  itemAsString: (k) => k.nama,
                  compareFn: (a, b) => a.id == b.id,
                  label: '',
                  hint: 'Kategori…',
                  prefixIcon: Icons.category_outlined,
                  isLoading: vm.masterLoading && master == null,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 200,
                child: SearchDropdownField<JenisOption>(
                  items: items ?? const [],
                  value: _jenisItem,
                  onChanged: (v) => setState(() => _jenisItem = v),
                  itemAsString: (o) => o.nama,
                  compareFn: (a, b) => a.id == b.id,
                  label: '',
                  hint: _jenisKategori == null ? 'Pilih kategori…' : 'Jenis…',
                  prefixIcon: Icons.label_outline,
                  enabled: _jenisKategori != null,
                  isLoading: vm.isJenisLoading(_jenisKategori?.id),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const ValueKey('jenis-add'),
                onPressed: (_jenisKategori != null && _jenisItem != null)
                    ? _addJenis
                    : null,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _panelError({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 32),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }

  List<AtlasTableColumn<LokasiRow>> get _lokasiColumns => [
    AtlasTableColumn(
      title: 'ID',
      width: 70,
      headerAlign: TextAlign.center,
      cellAlignment: Alignment.center,
      cellBuilder: (_, row, r) => Text(
        '#${row.idLokasi}',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: r.textColor,
        ),
      ),
    ),
    AtlasTableColumn(
      title: 'DESKRIPSI',
      flex: 3,
      cellBuilder: (_, row, r) => Text(
        row.description.isEmpty ? '—' : row.description,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF172B4D),
        ),
        softWrap: true,
      ),
    ),
    AtlasTableColumn(
      title: 'STATUS',
      width: 120,
      showDivider: false,
      cellBuilder: (_, row, r) => Align(
        alignment: Alignment.centerLeft,
        child: _SmallPill(
          label: row.enable ? 'Aktif' : 'Nonaktif',
          fg: row.enable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
          bg: row.enable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
        ),
      ),
    ),
  ];
}

class _SmallPill extends StatelessWidget {
  const _SmallPill({required this.label, required this.fg, required this.bg});

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
