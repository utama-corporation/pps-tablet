import 'package:flutter/material.dart';

import '../../production/shared/models/bahan_baku_proses_label.dart';
import '../../production/shared/models/barang_jadi_stok_item.dart';
import '../../production/shared/models/barang_jadi_stok_label.dart';
import '../../production/shared/models/bonggolan_stok_item.dart';
import '../../production/shared/models/bonggolan_stok_label.dart';
import '../../production/shared/models/broker_stok_item.dart';
import '../../production/shared/models/broker_stok_label.dart';
import '../../production/shared/models/crusher_stok_item.dart';
import '../../production/shared/models/crusher_stok_label.dart';
import '../../production/shared/models/furniture_wip_stok_item.dart';
import '../../production/shared/models/furniture_wip_stok_label.dart';
import '../../production/shared/models/gilingan_stok_item.dart';
import '../../production/shared/models/gilingan_stok_label.dart';
import '../../production/shared/models/mixer_stok_item.dart';
import '../../production/shared/models/mixer_stok_label.dart';
import '../../production/shared/models/bahan_pendukung_stok_item.dart';
import '../../production/shared/models/bahan_pendukung_stok_label.dart';
import '../../production/shared/models/packing_stok_item.dart';
import '../../production/shared/models/packing_stok_label.dart';
import '../../production/shared/models/reject_stok_item.dart';
import '../../production/shared/models/reject_stok_label.dart';
import '../../production/shared/models/stok_bahan_baku_item.dart';
import '../../production/shared/models/stok_item_data.dart';
import '../../production/shared/models/washing_stok_item.dart';
import '../../production/shared/models/washing_stok_label.dart';
import '../../production/shared/models/inject_stok_item.dart';
import '../../production/shared/models/inject_stok_label.dart';
import '../../production/shared/repository/barang_jadi_stok_repository.dart';
import '../../production/shared/repository/bonggolan_stok_repository.dart';
import '../../production/shared/repository/broker_stok_repository.dart';
import '../../production/shared/repository/crusher_stok_repository.dart';
import '../../production/shared/repository/furniture_wip_stok_repository.dart';
import '../../production/shared/repository/gilingan_stok_repository.dart';
import '../../production/shared/repository/mixer_stok_repository.dart';
import '../../production/shared/repository/bahan_pendukung_stok_repository.dart';
import '../../production/shared/repository/packing_produksi_repository.dart';
import '../../production/shared/repository/reject_stok_repository.dart';
import '../../production/shared/repository/stok_bahan_baku_pakai_repository.dart';
import '../../production/shared/repository/stok_bahan_baku_repository.dart';
import '../../production/shared/repository/washing_stok_repository.dart';
import '../../production/shared/repository/inject_stok_repository.dart';
import '../../production/shared/repository/stamping_stock_repository.dart';
import '../../production/shared/repository/spanner_stock_repository.dart';

import '../../production/shared/widgets/production_filter_chip.dart';
import '../../production/shared/widgets/stok_item_label_dialog.dart';
import '../../production/shared/widgets/stok_item_panel.dart';

import '../stock_proses_key.dart';

/// Satu sumber data stok (endpoint stok + endpoint label) untuk
/// [StockDetailScreen] — analog dengan `TypedStokItemSource` di
/// `stok_item_section.dart`, tapi tiap pane juga menghitung & menampilkan
/// total keseluruhan (jumlah label + total berat) di atas daftar per-jenis.
abstract class _StockSource {
  const _StockSource({required this.label});
  final String label;
  Widget buildPane(_StockRefreshController controller);
}

class _TypedStockSource<T extends StokItemData, L extends StokLabelData>
    extends _StockSource {
  const _TypedStockSource({
    required super.label,
    required this.fetchStok,
    required this.fetchLabel,
    required this.labelSisaOf,
    this.showSakColumn = true,
    this.sakColumnLabel = 'SAK',
    this.showBeratColumn = true,
    this.oldestDateOf,
  });

  final Future<List<T>> Function() fetchStok;
  final Future<List<L>> Function(T item) fetchLabel;
  final int Function(T item) labelSisaOf;
  final bool showSakColumn;
  final String sakColumnLabel;
  final bool showBeratColumn;
  final DateTime? Function(T item)? oldestDateOf;

  @override
  Widget buildPane(_StockRefreshController controller) =>
      _StockSourcePane<T, L>(source: this, controller: controller);
}

/// Mirip `StokItemSectionController` di `stok_item_section.dart`, dibuat
/// tersendiri karena metode register/unregister aslinya bersifat privat
/// (per-file) sehingga tak bisa dipakai lintas file.
class _StockRefreshController {
  final List<Future<void> Function()> _refreshers = [];

  void _register(Future<void> Function() refresh) => _refreshers.add(refresh);

  void _unregister(Future<void> Function() refresh) =>
      _refreshers.remove(refresh);

  Future<void> refreshAll() async {
    await Future.wait(_refreshers.map((r) => r()));
  }
}

class _StockSourcePane<T extends StokItemData, L extends StokLabelData>
    extends StatefulWidget {
  const _StockSourcePane({required this.source, required this.controller});

  final _TypedStockSource<T, L> source;
  final _StockRefreshController controller;

  @override
  State<_StockSourcePane<T, L>> createState() =>
      _StockSourcePaneState<T, L>();
}

class _StockSourcePaneState<T extends StokItemData, L extends StokLabelData>
    extends State<_StockSourcePane<T, L>>
    with AutomaticKeepAliveClientMixin {
  List<T> _items = [];
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.controller._register(_load);
    _load();
  }

  @override
  void dispose() {
    widget.controller._unregister(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.source.fetchStok();
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final totalLabel = _items.fold<int>(
      0,
      (sum, item) => sum + widget.source.labelSisaOf(item),
    );
    final totalBerat = _items.fold<double>(
      0,
      (sum, item) => sum + item.beratSisa,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: Column(
        children: [
          _StockTotalSummary(
            isLoading: _loading,
            totalLabel: totalLabel,
            totalBerat: totalBerat,
          ),
          Expanded(
            child: StokItemList<T>(
              items: _items,
              isLoading: _loading,
              errorMessage: _error,
              oldestDateOf: widget.source.oldestDateOf,
              showSakColumn: widget.source.showSakColumn,
              sakColumnLabel: widget.source.sakColumnLabel,
              showBeratColumn: widget.source.showBeratColumn,
              onTap: (item) => showDialog<void>(
                context: context,
                builder: (_) => StokItemLabelDialog<T, L>(
                  item: item,
                  showSakColumn: widget.source.showSakColumn,
                  sakColumnLabel: widget.source.sakColumnLabel,
                  showBeratColumn: widget.source.showBeratColumn,
                  fetchLabels: widget.source.fetchLabel,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kartu ringkasan total keseluruhan (jumlah label + total berat) untuk
/// proses yang sedang dilihat, dijumlah dari seluruh jenis pada proses ini.
class _StockTotalSummary extends StatelessWidget {
  const _StockTotalSummary({
    required this.isLoading,
    required this.totalLabel,
    required this.totalBerat,
  });

  final bool isLoading;
  final int totalLabel;
  final double totalBerat;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: isLoading
          ? const SizedBox(
              height: 40,
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: _StockTotalTile(
                    label: 'Jumlah Label',
                    value: '$totalLabel',
                    icon: Icons.label_outline_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  color: const Color(0xFFE5E7EB),
                ),
                Expanded(
                  child: _StockTotalTile(
                    label: 'Total Berat',
                    value: '${totalBerat.toStringAsFixed(2)} kg',
                    icon: Icons.scale_outlined,
                  ),
                ),
              ],
            ),
    );
  }
}

class _StockTotalTile extends StatelessWidget {
  const _StockTotalTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dialog detail Stock — menampilkan total keseluruhan (jumlah label +
/// berat) beserta rincian per-jenis untuk satu proses, memakai
/// repository/model yang sama dengan tab "Stok Item" pada tiap layar
/// mesin produksi. Dibuka lewat `showDialog` dari [StockSelectionScreen]
/// (bukan halaman penuh) supaya tidak menduplikasi breadcrumb yang sudah
/// disediakan `AppShell`.
class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({
    super.key,
    required this.prosesKey,
    required this.title,
  });

  final StockProsesKey prosesKey;
  final String title;

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final _controller = _StockRefreshController();
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final sources = _sourcesFor(widget.prosesKey);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),
            if (sources.length > 1)
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                    children: [
                      for (var i = 0; i < sources.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ProductionFilterChip(
                            label: sources[i].label,
                            selected: _selected == i,
                            onTap: () => setState(() => _selected = i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: IndexedStack(
                index: _selected,
                children: [
                  for (final source in sources) source.buildPane(_controller),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              size: 19,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () => _controller.refreshAll(),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: const Color(0xFF9CA3AF),
            hoverColor: const Color(0xFFF3F4F6),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            tooltip: 'Muat ulang',
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: const Color(0xFF9CA3AF),
            hoverColor: const Color(0xFFF3F4F6),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  List<_StockSource> _sourcesFor(StockProsesKey key) {
    switch (key) {
      case StockProsesKey.washing:
        final repo = WashingStokRepository();
        return [
          _TypedStockSource<WashingStokItem, WashingStokLabel>(
            label: 'Washing',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idWashing),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.broker:
        final repo = BrokerStokRepository();
        return [
          _TypedStockSource<BrokerStokItem, BrokerStokLabel>(
            label: 'Broker',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idBroker),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.crusher:
        final repo = CrusherStokRepository();
        return [
          _TypedStockSource<CrusherStokItem, CrusherStokLabel>(
            label: 'Crusher',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idCrusher),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.bonggolan:
        final repo = BonggolanStokRepository();
        return [
          _TypedStockSource<BonggolanStokItem, BonggolanStokLabel>(
            label: 'Bonggolan',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idBonggolan),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.gilingan:
        final repo = GilinganStokRepository();
        return [
          _TypedStockSource<GilinganStokItem, GilinganStokLabel>(
            label: 'Gilingan',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idGilingan),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.mixer:
        final repo = MixerStokRepository();
        return [
          _TypedStockSource<MixerStokItem, MixerStokLabel>(
            label: 'Mixer',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idMixer),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.furnitureWip:
        final repo = FurnitureWipStokRepository();
        return [
          _TypedStockSource<FurnitureWipStokItem, FurnitureWipStokLabel>(
            label: 'Furniture WIP',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idCabinetWip),
            labelSisaOf: (item) => item.labelSisa,
            sakColumnLabel: 'PCS',
            showBeratColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.barangJadi:
        final repo = BarangJadiStokRepository();
        return [
          _TypedStockSource<BarangJadiStokItem, BarangJadiStokLabel>(
            label: 'Barang Jadi',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idBJ),
            labelSisaOf: (item) => item.labelSisa,
            sakColumnLabel: 'PCS',
            showBeratColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.reject:
        final repo = RejectStokRepository();
        return [
          _TypedStockSource<RejectStokItem, RejectStokLabel>(
            label: 'Reject',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idReject),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];
      case StockProsesKey.bahanBaku:
        final prosesRepo = StokBahanBakuRepository();
        final pakaiRepo = StokBahanBakuPakaiRepository();
        return [
          _TypedStockSource<StokBahanBakuItem, BahanBakuProsesLabel>(
            label: 'Bahan Baku Proses',
            fetchStok: prosesRepo.fetchStok,
            fetchLabel: (item) => prosesRepo.fetchLabel(item.idBB),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
          _TypedStockSource<StokBahanBakuItem, BahanBakuProsesLabel>(
            label: 'Bahan Baku Pakai',
            fetchStok: pakaiRepo.fetchStok,
            fetchLabel: (item) => pakaiRepo.fetchLabel(item.idBB),
            labelSisaOf: (item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          ),
        ];


      case StockProsesKey.bahanBakuProses:
        final repo = StokBahanBakuRepository();
        return [
          _TypedStockSource<StokBahanBakuItem, BahanBakuProsesLabel>(
            label: 'Bahan Baku Proses',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idBB) ,
            labelSisaOf: (StokBahanBakuItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
      case StockProsesKey.bahanBakuPakai:
        final repo = StokBahanBakuPakaiRepository();
        return [
          _TypedStockSource<StokBahanBakuItem, BahanBakuProsesLabel>(
            label: 'Bahan Baku Pakai',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idBB) ,
            labelSisaOf: (StokBahanBakuItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
      case StockProsesKey.wipInject:
        final repo = InjectStokRepository();
        return [
          _TypedStockSource<InjectStokItem, InjectStokLabel>(
            label: 'Inject',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idCabinetWIP),
            labelSisaOf: (InjectStokItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
      case StockProsesKey.wipStamping:
        final repo = StampingStokRepository();
        return [
          _TypedStockSource<InjectStokItem, InjectStokLabel>(
            label: 'Stamping',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idCabinetWIP),
            labelSisaOf: (InjectStokItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
      case StockProsesKey.wipSpanner:
        final repo = SpannerStokRepository();
        return [
          _TypedStockSource<InjectStokItem, InjectStokLabel>(
            label: 'Packing Spanner',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idCabinetWIP),
            labelSisaOf: (InjectStokItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
      case StockProsesKey.bahanPendukung:
        final repo = BahanPendukungStokRepository();
        return [
          _TypedStockSource<BahanPendukungStokItem, BahanPendukungStokLabel>(
            label: 'Bahan Pendukung',
            fetchStok: repo.fetchStok,
            fetchLabel: (item) => repo.fetchLabel(item.idCabinetMaterial),
            labelSisaOf: (BahanPendukungStokItem item) => item.labelSisa,
            sakColumnLabel: 'PCS',
            showBeratColumn: false,
          )
        ];
      case StockProsesKey.barangJadiGrande:
        final repo = PackingProduksiRepository();
        return [
          _TypedStockSource<PackingStokItem, PackingStokLabel>(
            label: 'Packing Produksi Grande',
            fetchStok: () => repo.fetchStok(type: 'GRANDE'),
            fetchLabel: (item) => repo.fetchLabel(item.idBJ, type: 'GRANDE'),
            labelSisaOf: (PackingStokItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
      case StockProsesKey.barangJadiHana:
        final repo = PackingProduksiRepository();
        return [
          _TypedStockSource<PackingStokItem, PackingStokLabel>(
            label: 'Packing Produksi Hana',
            fetchStok: () => repo.fetchStok(type: 'HANA'),
            fetchLabel: (item) => repo.fetchLabel(item.idBJ, type: 'HANA'),
            labelSisaOf: (PackingStokItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
      case StockProsesKey.barangJadiKursi:
        final repo = PackingProduksiRepository();
        return [
          _TypedStockSource<PackingStokItem, PackingStokLabel>(
            label: 'Packing Produksi Kursi',
            fetchStok: () => repo.fetchStok(type: 'PART KURSI'),
            fetchLabel: (item) => repo.fetchLabel(item.idBJ, type: 'PART KURSI'),
            labelSisaOf: (PackingStokItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
      case StockProsesKey.barangJadiEnamel:
        final repo = PackingProduksiRepository();
        return [
          _TypedStockSource<PackingStokItem, PackingStokLabel>(
            label: 'Packing Produksi Enamel',
            fetchStok: () => repo.fetchStok(type: 'ENAMEL'),
            fetchLabel: (item) => repo.fetchLabel(item.idBJ, type: 'ENAMEL'),
            labelSisaOf: (PackingStokItem item) => item.labelSisa,
            showSakColumn: false,
            oldestDateOf: (item) => item.dateCreateTertua,
          )
        ];
    }
  }
}
