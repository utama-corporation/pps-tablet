import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../model/mapping_v2_models.dart';
import '../view_model/mapping_v2_view_model.dart';
import 'mapping_v2_scan_screen.dart';

class MappingV2Screen extends StatefulWidget {
  const MappingV2Screen({super.key});

  @override
  State<MappingV2Screen> createState() => _MappingV2ScreenState();
}

class _MappingV2ScreenState extends State<MappingV2Screen> {
  late final MappingV2ViewModel _viewModel;
  final ScrollController _labelScrollController = ScrollController();
  final TextEditingController _locationSearchController =
      TextEditingController();
  String _locationSearchQuery = '';
  bool _isLocationSearchActive = false;

  final TextEditingController _labelSearchController = TextEditingController();
  String _labelSearchQuery = '';
  bool _isLabelSearchActive = false;
  bool _isOpeningScanner = false;

  @override
  void initState() {
    super.initState();
    _viewModel = MappingV2ViewModel()..loadBloks();
    _labelScrollController.addListener(_onLabelScroll);
  }

  @override
  void dispose() {
    _labelScrollController
      ..removeListener(_onLabelScroll)
      ..dispose();
    _locationSearchController.dispose();
    _labelSearchController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _clearLocationSearch() {
    _locationSearchController.clear();
    if (_locationSearchQuery.isNotEmpty || _isLocationSearchActive) {
      setState(() {
        _locationSearchQuery = '';
        _isLocationSearchActive = false;
      });
    }
  }

  void _toggleLocationSearch() {
    if (_isLocationSearchActive) {
      _clearLocationSearch();
    } else {
      setState(() => _isLocationSearchActive = true);
    }
  }

  List<MappingV2Lokasi> _filterLocations(
    MappingV2Blok blok,
    List<MappingV2Lokasi> locations,
  ) {
    final query = _locationSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return locations;
    return locations.where((location) {
      final locationName = '${blok.blok}${location.idLokasi}'.toLowerCase();
      final matchesName = locationName.contains(query);
      final matchesJenis = location.jenisList.any(
        (jenis) => jenis.namaJenis.toLowerCase().contains(query),
      );
      return matchesName || matchesJenis;
    }).toList();
  }

  void _clearLabelSearch() {
    _labelSearchController.clear();
    if (_labelSearchQuery.isNotEmpty || _isLabelSearchActive) {
      setState(() {
        _labelSearchQuery = '';
        _isLabelSearchActive = false;
      });
    }
  }

  void _toggleLabelSearch() {
    if (_isLabelSearchActive) {
      _clearLabelSearch();
    } else {
      setState(() => _isLabelSearchActive = true);
    }
  }

  List<MappingV2Label> _filterLabels(List<MappingV2Label> labels) {
    final query = _labelSearchQuery.trim().toLowerCase();
    if (query.isEmpty) return labels;
    return labels.where((label) {
      return label.labelCode.toLowerCase().contains(query) ||
          label.namaJenis.toLowerCase().contains(query) ||
          label.kategori.toLowerCase().contains(query);
    }).toList();
  }

  void _onLabelScroll() {
    if (!_labelScrollController.hasClients ||
        _viewModel.selectedLocation == null ||
        !_viewModel.canLoadMore ||
        _viewModel.isLoadingLabels ||
        _viewModel.isLoadingMore) {
      return;
    }
    final position = _labelScrollController.position;
    if (position.extentAfter <= 300) {
      _viewModel.loadLabels(reset: false);
    }
  }

  void _handleBack(MappingV2ViewModel viewModel) {
    if (viewModel.selectedLocation != null) {
      _clearLabelSearch();
      viewModel.backToLocations();
      return;
    }
    if (viewModel.selectedBlok != null) {
      _clearLocationSearch();
      viewModel.backToBloks();
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _openScanner(MappingV2ViewModel viewModel) async {
    final blok = viewModel.selectedBlok;
    final location = viewModel.selectedLocation;
    if (blok == null || location == null) return;

    // /api/label/update-lokasi mewajibkan labelCode + idLokasi + blok dari lokasi
    // yang sedang discan. Lokasi tanpa nomor (IdLokasi 0) tidak punya tujuan
    // yang valid, jadi ditolak di client daripada mengirim idLokasi 0.
    if (location.idLokasi == 0) {
      _showSnackBar(
        'Lokasi ${location.blok.isEmpty ? '' : location.blok} tidak punya nomor lokasi, tidak bisa discan.',
        isError: true,
      );
      return;
    }

    // FAB bisa ditekan dua kali cepat; tanpa guard ini dua route scanner
    // ter-push dan _releaseCode/scanner callback saling tumpang tindih.
    if (_isOpeningScanner) return;
    setState(() => _isOpeningScanner = true);

    final locationBlok = location.blok.trim();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => MappingV2ScanScreen(
          // Blok milik lokasi itu sendiri yang dikirim, bukan blok induk yang
          // sedang dibuka; fallback hanya kalau lokasi tidak membawa blok.
          blok: locationBlok.isEmpty ? blok.blok : locationBlok,
          idLokasi: location.idLokasi,
          initialLabelCount: location.totalLabel,
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _isOpeningScanner = false);
    await viewModel.loadLabels(reset: true);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refreshCurrentStep(MappingV2ViewModel viewModel) {
    if (viewModel.selectedLocation != null) {
      return viewModel.loadLabels(reset: true);
    }
    if (viewModel.selectedBlok != null) {
      return viewModel.selectBlok(viewModel.selectedBlok!);
    }
    return viewModel.loadBloks();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<MappingV2ViewModel>(
        builder: (context, viewModel, _) {
          final atRoot =
              viewModel.selectedBlok == null &&
              viewModel.selectedLocation == null;
          final isSearching = _isLocationSearchActive || _isLabelSearchActive;
          return PopScope(
            canPop: atRoot && !isSearching,
            onPopInvokedWithResult: (didPop, _) {
              if (didPop) return;
              if (_isLocationSearchActive) {
                _clearLocationSearch();
              } else if (_isLabelSearchActive) {
                _clearLabelSearch();
              } else {
                _handleBack(viewModel);
              }
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              appBar: _isLocationSearchActive
                  ? _buildSearchAppBar(
                      controller: _locationSearchController,
                      query: _locationSearchQuery,
                      hintText: 'Cari lokasi atau jenis...',
                      onClose: _clearLocationSearch,
                      onChanged: (value) =>
                          setState(() => _locationSearchQuery = value),
                      onClear: () => setState(() {
                        _locationSearchController.clear();
                        _locationSearchQuery = '';
                      }),
                    )
                  : _isLabelSearchActive
                  ? _buildSearchAppBar(
                      controller: _labelSearchController,
                      query: _labelSearchQuery,
                      hintText: 'Cari kode label, jenis, atau kategori...',
                      onClose: _clearLabelSearch,
                      onChanged: (value) =>
                          setState(() => _labelSearchQuery = value),
                      onClear: () => setState(() {
                        _labelSearchController.clear();
                        _labelSearchQuery = '';
                      }),
                    )
                  : AppBar(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      leading: IconButton(
                        onPressed: () => _handleBack(viewModel),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pageTitle(viewModel),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_pageSubtitle(viewModel).isNotEmpty)
                            Text(
                              _pageSubtitle(viewModel),
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                      actions: [
                        if (viewModel.selectedBlok != null &&
                            viewModel.selectedLocation == null)
                          IconButton(
                            onPressed: _toggleLocationSearch,
                            icon: const Icon(Icons.search),
                          ),
                        if (viewModel.selectedLocation != null)
                          IconButton(
                            onPressed: _toggleLabelSearch,
                            icon: const Icon(Icons.search),
                          ),
                      ],
                    ),
              body: RefreshIndicator(
                onRefresh: () => _refreshCurrentStep(viewModel),
                child: _buildCurrentStep(viewModel),
              ),
              floatingActionButton: viewModel.selectedLocation != null
                  ? FloatingActionButton(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      onPressed: _isOpeningScanner ? null : () => _openScanner(viewModel),
                      tooltip: 'Scan Label',
                      child: const Icon(Icons.qr_code_scanner),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  String _pageTitle(MappingV2ViewModel viewModel) {
    final blok = viewModel.selectedBlok;
    final location = viewModel.selectedLocation;
    if (location != null && blok != null) {
      return '${blok.blok}${location.idLokasi} (${viewModel.totalData})';
    }
    if (blok != null) return '${blok.blok} (${viewModel.locations.length})';
    return 'Mapping V2';
  }

  String _pageSubtitle(MappingV2ViewModel viewModel) {
    final blok = viewModel.selectedBlok;
    final location = viewModel.selectedLocation;
    if (location != null && blok != null) {
      return '';
    }
    if (blok != null) {
      return '';
    }
    return 'Pilih blok untuk melihat lokasi dan label';
  }

  AppBar _buildSearchAppBar({
    required TextEditingController controller,
    required String query,
    required String hintText,
    required VoidCallback onClose,
    required ValueChanged<String> onChanged,
    required VoidCallback onClear,
  }) {
    return AppBar(
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      leading: IconButton(
        onPressed: onClose,
        icon: const Icon(Icons.arrow_back),
      ),
      title: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        onChanged: onChanged,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      ),
      actions: [
        if (query.isNotEmpty)
          IconButton(onPressed: onClear, icon: const Icon(Icons.close)),
      ],
    );
  }

  Widget _buildCurrentStep(MappingV2ViewModel viewModel) {
    if (viewModel.selectedLocation != null) {
      return _buildLabelStep(viewModel);
    }
    if (viewModel.selectedBlok != null) {
      return _buildLocationStep(viewModel);
    }
    return _buildBlokStep(viewModel);
  }

  Widget _buildBlokStep(MappingV2ViewModel viewModel) {
    if (viewModel.isLoadingBloks && viewModel.bloks.isEmpty) {
      return const _LoadingList(message: 'Memuat daftar blok...');
    }
    if (viewModel.error != null && viewModel.bloks.isEmpty) {
      return _ErrorList(
        message: viewModel.error!,
        onRetry: viewModel.loadBloks,
      );
    }
    if (viewModel.bloks.isEmpty) {
      return const _EmptyList(
        icon: Icons.grid_view_outlined,
        message: 'Belum ada blok tersedia.',
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final blok = viewModel.bloks[index];
              return _BlokMenuCard(
                blok: blok,
                onTap: () {
                  _clearLocationSearch();
                  viewModel.selectBlok(blok);
                },
              );
            }, childCount: viewModel.bloks.length),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationStep(MappingV2ViewModel viewModel) {
    if (viewModel.isLoadingLocations && viewModel.locations.isEmpty) {
      return const _LoadingList(message: 'Memuat daftar lokasi...');
    }
    if (viewModel.error != null && viewModel.locations.isEmpty) {
      return _ErrorList(
        message: viewModel.error!,
        onRetry: () => viewModel.selectBlok(viewModel.selectedBlok!),
      );
    }
    if (viewModel.locations.isEmpty) {
      return const _EmptyList(
        icon: Icons.location_off_outlined,
        message: 'Belum ada lokasi pada blok ini.',
      );
    }

    final blok = viewModel.selectedBlok!;
    final filteredLocations = _filterLocations(blok, viewModel.locations);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (filteredLocations.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverToBoxAdapter(
              child: _InlineEmpty(
                message: 'Lokasi "$_locationSearchQuery" tidak ditemukan.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final location = filteredLocations[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _LocationMenuCard(
                    blok: blok,
                    location: location,
                    onTap: () {
                      _clearLocationSearch();
                      _clearLabelSearch();
                      viewModel.selectLocation(location);
                    },
                  ),
                );
              }, childCount: filteredLocations.length),
            ),
          ),
      ],
    );
  }

  Widget _buildLabelStep(MappingV2ViewModel viewModel) {
    final filteredLabels = _filterLabels(viewModel.labels);
    final isFiltering = _labelSearchQuery.trim().isNotEmpty;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.axis == Axis.vertical &&
            notification.metrics.extentAfter <= 300) {
          if (viewModel.canLoadMore &&
              !viewModel.isLoadingLabels &&
              !viewModel.isLoadingMore) {
            viewModel.loadLabels(reset: false);
          }
        }
        return false;
      },
      child: ListView(
        controller: _labelScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (viewModel.isLoadingLabels)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (viewModel.labels.isEmpty)
            const _InlineEmpty(message: 'Belum ada label pada lokasi ini.')
          else if (filteredLabels.isEmpty)
            _InlineEmpty(
              message: 'Label "${_labelSearchQuery.trim()}" tidak ditemukan.',
            )
          else ...[
            for (final label in filteredLabels) _LabelCard(label: label),
            if (isFiltering && viewModel.canLoadMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Sebagian label mungkin belum dimuat. Scroll ke bawah untuk memuat lebih banyak dan mencari lebih lengkap.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
              ),
            if (viewModel.isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ),
          ],
          if (viewModel.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                viewModel.error!,
                style: TextStyle(color: Colors.red.shade700),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _BlokMenuCard extends StatelessWidget {
  const _BlokMenuCard({required this.blok, required this.onTap});

  final MappingV2Blok blok;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                blok.blok,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${blok.totalLokasi} lokasi',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationMenuCard extends StatelessWidget {
  const _LocationMenuCard({
    required this.blok,
    required this.location,
    required this.onTap,
  });

  final MappingV2Blok blok;
  final MappingV2Lokasi location;
  final VoidCallback onTap;

  bool get _isPcsUom {
    if (location.jenisList.isEmpty) return false;
    return location.jenisList.every(
      (jenis) => jenis.namaUOM.trim().toLowerCase() == 'pcs',
    );
  }

  String get _quantityText {
    if (_isPcsUom) {
      final uom = location.jenisList.first.namaUOM;
      return '${mappingV2FormatQuantity(location.totalQty)} $uom';
    }
    return '${mappingV2FormatQuantity(location.totalBerat)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final locationName = '${blok.blok}${location.idLokasi}';
    final hasData = location.totalLabel > 0;

    final accentColor = !location.enable
        ? Colors.grey.shade400
        : hasData
        ? const Color(0xFF1E3A8A)
        : Colors.grey.shade300;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: location.enable
                                  ? const Color(0xFF1E3A8A)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                locationName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        location.jenisList.isEmpty
                            ? Text(
                                '-',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              )
                            : _JenisChipList(jenisList: location.jenisList),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sell_outlined,
                                  size: 13,
                                  color: hasData
                                      ? const Color(0xFF1E3A8A)
                                      : Colors.grey.shade500,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  hasData
                                      ? '${location.totalLabel} label'
                                      : 'Kosong',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.5,
                                    color: hasData
                                        ? const Color(0xFF1E3A8A)
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                            if (hasData)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _isPcsUom
                                        ? Icons.inventory_2_outlined
                                        : Icons.scale_outlined,
                                    size: 13,
                                    color: const Color(0xFF1E3A8A),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _quantityText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11.5,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
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

class _JenisChipList extends StatelessWidget {
  const _JenisChipList({required this.jenisList});

  final List<MappingV2Jenis> jenisList;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final jenis in jenisList)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              jenis.namaJenis,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
      ],
    );
  }
}

class _LabelCard extends StatelessWidget {
  const _LabelCard({required this.label});

  final MappingV2Label label;

  @override
  Widget build(BuildContext context) {
    final date = label.dateCreate;
    final dateText = date == null
        ? '-'
        : DateFormat('dd MMM yyyy').format(date);

    final quantityText = label.isPcsOnly
        ? '${mappingV2FormatQuantity(label.qty)} ${label.namaUOM}'
        : '${mappingV2FormatQuantity(label.berat)} kg';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.namaJenis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label.labelCode,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quantityText,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                dateText,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF1E3A8A)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            message,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ErrorList extends StatelessWidget {
  const _ErrorList({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 90),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 30,
              color: Colors.red.shade600,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: onRetry,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Coba Lagi'),
        ),
      ],
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 130),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: const Color(0xFF1E3A8A)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.inbox_outlined,
              size: 26,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
