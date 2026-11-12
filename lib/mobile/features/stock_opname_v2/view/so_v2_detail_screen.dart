import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../constants/kategori_constants.dart';
import '../model/so_v2_failed_scan.dart';
import '../model/so_v2_models.dart';
import '../view_model/so_v2_detail_view_model.dart';
import '../view_model/so_v2_failed_scan_view_model.dart';
import 'so_v2_category_style.dart';
import 'so_v2_failed_scan_sheet.dart';
import 'so_v2_scan_screen.dart';

class SoV2DetailScreen extends StatefulWidget {
  const SoV2DetailScreen({super.key, required this.myLokasi});

  final SoV2MyLokasi myLokasi;

  @override
  State<SoV2DetailScreen> createState() => _SoV2DetailScreenState();
}

class _SoV2DetailScreenState extends State<SoV2DetailScreen> {
  late final SoV2DetailViewModel _viewModel;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _labelScrollController = ScrollController();
  Timer? _searchDebounce;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _viewModel = SoV2DetailViewModel(
      stockOpnameNo: widget.myLokasi.stockOpnameNo,
      categoryCode: widget.myLokasi.categoryCode,
      location: widget.myLokasi.location,
    )..init();
    _labelScrollController.addListener(_onLabelScroll);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _labelScrollController
      ..removeListener(_onLabelScroll)
      ..dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _onLabelScroll() {
    if (!_labelScrollController.hasClients ||
        !_viewModel.canLoadMore ||
        _viewModel.isLoadingLabels ||
        _viewModel.isLoadingMore) {
      return;
    }

    final position = _labelScrollController.position;
    _loadMoreIfNeeded(position.extentAfter);
  }

  void _loadMoreIfNeeded(double extentAfter) {
    if (!_viewModel.canLoadMore ||
        _viewModel.isLoadingLabels ||
        _viewModel.isLoadingMore) {
      return;
    }

    const loadMoreThreshold = 300.0;
    if (extentAfter <= loadMoreThreshold) {
      _viewModel.loadLabels(reset: false);
    }
  }

  bool _onLabelScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      _loadMoreIfNeeded(notification.metrics.extentAfter);
    }
    return false;
  }

  void _handleBack(SoV2DetailViewModel viewModel) {
    if (_isSearching) {
      _closeSearch(viewModel);
      return;
    }
    Navigator.of(context).pop();
  }

  void _openSearch() {
    setState(() => _isSearching = true);
  }

  void _closeSearch(SoV2DetailViewModel viewModel) {
    setState(() => _isSearching = false);
    _searchDebounce?.cancel();
    _searchController.clear();
    viewModel.setSearch('');
  }

  Future<void> _openScanner(SoV2DetailViewModel viewModel) async {
    final location = viewModel.location;
    final pendingLabels = viewModel.groups
        .expand((group) => group.labels)
        .toList();

    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SoV2ScanScreen(
          stockOpnameNo: widget.myLokasi.stockOpnameNo,
          blok: location.blok,
          locationId: location.locationId,
          pendingLabels: pendingLabels,
        ),
      ),
    );
    await viewModel.loadLabels(reset: true);
  }

  Future<void> _openFailedScans() async {
    // Jangan pakai context.read<SoV2DetailViewModel>() di sini: view model itu
    // dibuat lokal lalu dibungkus ChangeNotifierProvider.value di dalam build(),
    // jadi context milik State berada DI ATAS provider tersebut dan lookup akan
    // melempar ProviderNotFoundException. widget.myLokasi.location adalah
    // instance yang sama dengan viewModel.location.
    final location = widget.myLokasi.location;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SoV2FailedScanSheet(
        stockOpnameNo: widget.myLokasi.stockOpnameNo,
        blok: location.blok,
        locationId: location.locationId,
      ),
    );
  }

  /// Penanda daftar gagal. Kalau ada isinya, ditampilkan sebagai pil
  /// berwarna yang mencolok — badge kecil di AppBar mudah terlewat saat
  /// operator sedang fokus ke area scan.
  Widget _buildFailedButton(int total, int retryable) {
    if (total == 0) {
      return IconButton(
        onPressed: _openFailedScans,
        tooltip: 'Daftar gagal',
        icon: const Icon(Icons.error_outline, color: Colors.white),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _openFailedScans,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  '$total gagal',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (retryable > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '· $retryable retry',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onSearchChanged(String value, SoV2DetailViewModel viewModel) {
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => viewModel.setSearch(value),
    );
  }

  Future<void> _refreshCurrentStep(SoV2DetailViewModel viewModel) {
    return viewModel.loadLabels(reset: true);
  }

  String _appBarTitle(SoV2DetailViewModel viewModel) {
    final categoryName = KategoriConstants.getLabel(
      widget.myLokasi.categoryCode,
    );
    final location = widget.myLokasi.location;
    final locationText = location.isUnknown
        ? 'Lokasi Tidak Diketahui'
        : '${location.blok}${location.locationId}';
    return '$categoryName ($locationText)';
  }

  Widget _buildHeader(BuildContext context, SoV2DetailViewModel viewModel) {
    final failedStore = context.watch<SoV2FailedScanViewModel>();
    final location = viewModel.location;
    final failedEntries = failedStore.entriesFor(
      stockOpnameNo: viewModel.stockOpnameNo,
      blok: location.blok,
      locationId: location.locationId,
    );
    final failedRetryable = failedEntries
        .where((SoV2FailedScan entry) => entry.isRetryable)
        .length;

    final progress = viewModel.totalRecords == 0
        ? 0.0
        : (viewModel.totalScanned / viewModel.totalRecords).clamp(0.0, 1.0);
    final complete = viewModel.isComplete;

    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.of(context).padding.top + 10,
        16,
        18,
      ),
      decoration: const BoxDecoration(
        color: soV2ThemeBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _handleBack(viewModel),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: _isSearching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white),
                        cursorColor: Colors.white,
                        decoration: const InputDecoration(
                          hintText: 'Cari nomor label...',
                          hintStyle: TextStyle(color: Colors.white70),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) =>
                            _onSearchChanged(value, viewModel),
                      )
                    : Text(
                        _appBarTitle(viewModel),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
              ),
              _buildFailedButton(failedEntries.length, failedRetryable),
              IconButton(
                onPressed: _isSearching
                    ? () => _closeSearch(viewModel)
                    : _openSearch,
                icon: Icon(
                  _isSearching ? Icons.close : Icons.search,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (!_isSearching) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${viewModel.totalScanned}/${viewModel.totalRecords} label discan',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  Icon(
                    viewModel.unit == 'pcs'
                        ? Icons.numbers
                        : Icons.scale_outlined,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${soV2FormatQuantity(viewModel.totalQuantity)} ${viewModel.unit}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    complete ? 'Selesai' : '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SoV2DetailViewModel>(
        builder: (context, viewModel, _) {
          return PopScope(
            canPop: !_isSearching,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _handleBack(viewModel);
            },
            child: Scaffold(
              backgroundColor: const Color(0xFFF5F7FA),
              body: Column(
                children: [
                  _buildHeader(context, viewModel),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _refreshCurrentStep(viewModel),
                      child: _buildLabelStep(viewModel),
                    ),
                  ),
                ],
              ),
              floatingActionButton: !viewModel.isComplete
                  ? FloatingActionButton(
                      backgroundColor: soV2ThemeBlue,
                      foregroundColor: Colors.white,
                      onPressed: () => _openScanner(viewModel),
                      child: const Icon(Icons.qr_code_scanner),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabelStep(SoV2DetailViewModel viewModel) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onLabelScrollNotification,
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
          else if (viewModel.groups.isEmpty)
            const _InlineEmpty(message: 'Belum ada label pada lokasi ini.')
          else ...[
            for (final group in viewModel.groups)
              _LabelGroupCard(group: group, unit: viewModel.unit),
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

class _LabelGroupCard extends StatelessWidget {
  const _LabelGroupCard({required this.group, required this.unit});

  final SoV2LabelGroup group;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final complete =
        group.labelCount > 0 && group.scannedCount >= group.labelCount;
    final accentColor = complete ? soV2CompleteGreen : soV2ThemeBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: soV2ThemeBlue.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          childrenPadding: EdgeInsets.zero,
          iconColor: accentColor,
          collapsedIconColor: Colors.grey.shade500,
          title: Text(
            group.typeName.isEmpty ? 'Jenis tidak diketahui' : group.typeName,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1F2937),
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                Text(
                  '${group.scannedCount}/${group.labelCount} label',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '· ${soV2FormatQuantity(group.totalQuantity)} $unit',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          children: [
            Container(height: 1, color: Colors.grey.shade100),
            for (final label in group.labels)
              _LabelRow(label: label, unit: unit),
          ],
        ),
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label, required this.unit});

  final SoV2LabelRow label;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final quantity = label.quantityDisplay(unit);
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade100)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      child: Row(
        children: [
          Icon(
            label.isScanned
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked,
            size: 18,
            color: label.isScanned
                ? Colors.green.shade600
                : Colors.grey.shade400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label.primaryValue,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
                color: label.isScanned
                    ? const Color(0xFF1F2937)
                    : Colors.grey.shade600,
              ),
            ),
          ),
          if (quantity != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: label.isScanned
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                quantity,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: label.isScanned
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
