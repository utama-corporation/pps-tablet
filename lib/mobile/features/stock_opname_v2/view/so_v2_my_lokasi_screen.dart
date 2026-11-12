import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../model/so_v2_models.dart';
import '../view_model/so_v2_my_lokasi_view_model.dart';
import 'so_v2_category_style.dart';
import 'so_v2_detail_screen.dart';

class SoV2MyLokasiScreen extends StatefulWidget {
  const SoV2MyLokasiScreen({super.key});

  @override
  State<SoV2MyLokasiScreen> createState() => _SoV2MyLokasiScreenState();
}

class _SoV2MyLokasiScreenState extends State<SoV2MyLokasiScreen> {
  late final SoV2MyLokasiViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = SoV2MyLokasiViewModel()..load();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        8,
        MediaQuery.of(context).padding.top + 6,
        20,
        20,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STOCK OPNAME',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Lokasi Anda',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 17,
                  color: Colors.white,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pilih salah satu lokasi di bawah untuk mulai scan label.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
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

  Future<void> _openDetail(SoV2MyLokasi myLokasi) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SoV2DetailScreen(myLokasi: myLokasi)),
    );
    if (mounted) {
      await _viewModel.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SoV2MyLokasiViewModel>(
        builder: (context, viewModel, _) => Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: viewModel.load,
                  child: _buildBody(viewModel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(SoV2MyLokasiViewModel viewModel) {
    if (viewModel.isLoading && viewModel.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.error != null && viewModel.items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const Icon(Icons.error_outline, size: 56, color: Colors.red),
          const SizedBox(height: 16),
          Text(viewModel.error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: viewModel.load,
            child: const Text('Coba Lagi'),
          ),
        ],
      );
    }
    if (viewModel.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.inventory_2_outlined, size: 56, color: Colors.grey),
          SizedBox(height: 12),
          Text('Belum ada lokasi stock opname.', textAlign: TextAlign.center),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        for (final myLokasi in viewModel.items) ...[
          _MyLokasiCard(myLokasi: myLokasi, onTap: () => _openDetail(myLokasi)),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}

class _MyLokasiCard extends StatelessWidget {
  const _MyLokasiCard({required this.myLokasi, required this.onTap});

  final SoV2MyLokasi myLokasi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = myLokasi.location;
    final progress = location.progress.clamp(0.0, 1.0);
    final complete =
        location.labelCount > 0 && location.scannedCount >= location.labelCount;
    final locationName = location.isUnknown
        ? 'Lokasi Tidak Diketahui'
        : '${location.blok}${location.locationId}';
    final unit = myLokasi.categoryCode.toLowerCase() == 'furniturewip'
        ? 'pcs'
        : 'kg';

    final progressColor = complete ? soV2CompleteGreen : soV2ThemeBlue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7EAF0)),
        boxShadow: [
          BoxShadow(
            color: soV2ThemeBlue.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kuadran atas: lokasi (kiri) & persentase discan (kanan).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        locationName,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: progressColor,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          complete ? 'Selesai' : 'Terscan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: complete
                                ? soV2CompleteGreen
                                : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Divider(height: 1, color: Color(0xFFE7EAF0)),
                const SizedBox(height: 20),
                // Kuadran bawah: berat/pcs hasil scan (kiri) & jumlah label discan (kanan).
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.scale_outlined,
                            size: 19,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '${soV2FormatQuantity(location.totalQuantity)} $unit',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF1F2937),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.qr_code_scanner_rounded,
                          size: 19,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          '${location.scannedCount}/${location.labelCount} label',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1F2937),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        myLokasi.stockOpnameNo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
