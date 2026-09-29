import 'package:flutter/material.dart';

import '../stock_proses_key.dart';
import '../stock_totals.dart';
import '../widgets/stock_proses_card.dart';
import 'stock_detail_screen.dart';

class _StockProsesDef {
  const _StockProsesDef({
    required this.key,
    required this.title,
    required this.icon,
  });

  final StockProsesKey key;
  final String title;
  final IconData icon;
}

class _StockProsesTitle{
  final String title;
  final String subtitle;

  const _StockProsesTitle({
    required this.title,
    required this.subtitle,
  });
}


final Map<_StockProsesTitle, List<_StockProsesDef>> _dashboardInventoryData = {
  const _StockProsesTitle(title: '1. Bahan Baku', subtitle: 'Kategori Stock Bahan Baku & Pendukung') : [
    const _StockProsesDef(key: StockProsesKey.bahanBakuProses, title: 'Bahan Baku Proses', icon: Icons.view_in_ar),
    const _StockProsesDef(key: StockProsesKey.bahanBakuPakai, title: 'Bahan Baku Pakai', icon: Icons.inventory_2_outlined),
    const _StockProsesDef(key: StockProsesKey.bahanPendukung, title: 'Bahan Pendukung', icon: Icons.science_outlined),
  ],
  const _StockProsesTitle(title: '2. Proses Produksi', subtitle: 'Inventory Fase Pengolahan & Daur Ulang') : [
    const _StockProsesDef(key: StockProsesKey.washing, title: 'Washing', icon: Icons.local_laundry_service_outlined),
    const _StockProsesDef(key: StockProsesKey.broker, title: 'Broker', icon: Icons.recycling_outlined),
    const _StockProsesDef(key: StockProsesKey.crusher, title: 'Crusher', icon: Icons.grain_outlined),
    const _StockProsesDef(key: StockProsesKey.gilingan, title: 'Gilingan', icon: Icons.settings_outlined),
    const _StockProsesDef(key: StockProsesKey.mixer, title: 'Mixer', icon: Icons.blender_outlined),
    const _StockProsesDef(key: StockProsesKey.wipInject, title: 'Inject', icon: Icons.format_paint_outlined),
    const _StockProsesDef(key: StockProsesKey.wipStamping, title: 'Stamping', icon: Icons.layers_outlined),
    const _StockProsesDef(key: StockProsesKey.wipSpanner, title: 'Packing Spanner', icon: Icons.extension_outlined),
  ],
  //const _StockProsesTitle(title: '3. WIP (Work In Progress)', subtitle: 'Barang Setengah Jadi / Semi-Finished') : [

  //],
  const _StockProsesTitle(title: '3. Waste', subtitle: 'Sisa Hasil Produksi & Barang Reject') : [
    const _StockProsesDef(key: StockProsesKey.bonggolan, title: 'Bonggolan', icon: Icons.scatter_plot_outlined),
    const _StockProsesDef(key: StockProsesKey.reject, title: 'Reject', icon: Icons.report_gmailerrorred_outlined),
  ],
  const _StockProsesTitle(title: '4. Barang Jadi', subtitle: 'Produk Jadi Siap Kirim / Finish Goods') : [
    const _StockProsesDef(key: StockProsesKey.barangJadiGrande, title: 'Grande', icon: Icons.star_border_outlined),
    const _StockProsesDef(key: StockProsesKey.barangJadiHana, title: 'Hana', icon: Icons.view_in_ar),
    const _StockProsesDef(key: StockProsesKey.barangJadiModelux, title: 'Modelux', icon: Icons.weekend_outlined),
    const _StockProsesDef(key: StockProsesKey.barangJadiMerona, title: 'Merona', icon: Icons.chair_alt_outlined),
    const _StockProsesDef(key: StockProsesKey.barangJadiMoore, title: 'Moore', icon: Icons.inventory_rounded),
    const _StockProsesDef(key: StockProsesKey.barangJadiSekar, title: 'Sekar', icon: Icons.dining),
    //const _StockProsesDef(key: StockProsesKey.barangJadiKursi, title: 'Kursi', icon: Icons.chair),
    //const _StockProsesDef(key: StockProsesKey.barangJadiEnamel, title: 'Enamel', icon: Icons.fact_check_outlined),
  ]
};

/// Grid pilihan proses untuk menu Stock — layout meniru grid mesin pada
/// layar produksi (`WashingProductionMesinScreen` dkk), tapi kartunya
/// merepresentasikan proses (Washing/Broker/dst), bukan mesin. Tiap kartu
/// juga menampilkan ringkasan jumlah label & total berat/pcs proses
/// tersebut. Tap sebuah kartu membuka [StockDetailScreen] yang menampilkan
/// data stok item untuk proses tersebut.
class StockSelectionScreen extends StatefulWidget {
  const StockSelectionScreen({super.key});

  @override
  State<StockSelectionScreen> createState() => _StockSelectionScreenState();
}

class _StockSelectionScreenState extends State<StockSelectionScreen> {
  final Map<StockProsesKey, StockProsesTotals> _totals = {};
  final Set<StockProsesKey> _failed = {};

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  void _loadTotals() {
    final keys = _dashboardInventoryData.values
        .expand((defs) => defs.map((d) => d.key))
        .toSet();

    for (final key in keys) {
      fetchStockProsesTotals(key)
          .then((totals) {
            if (!mounted) return;
            setState(() => _totals[key] = totals);
          })
          .catchError((_) {
            if (!mounted) return;
            setState(() => _failed.add(key));
          });
    }
  }

  Widget _stockProsesTitleWidget({required String title, required String subtitle, required String count}){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87
              )
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(count,
                style: const TextStyle(
                  color: Color(0xFF0D47A1),
                  fontSize: 9,
                  fontWeight: FontWeight.bold
                )
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          )
        ),
        const SizedBox(height: 5),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async{
          _totals.clear();
          _loadTotals();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: _dashboardInventoryData.entries.map((entry){
              final _StockProsesTitle _stockProsesTitle = entry.key;
              final List<_StockProsesDef> _lstProsesDef = entry.value;


              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stockProsesTitleWidget(title: _stockProsesTitle.title , subtitle: _stockProsesTitle.subtitle, count: '${_lstProsesDef.length} Kategori'),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _lstProsesDef
                        .map((def) => StockProsesCard(
                      title: def.title,
                      icon: def.icon,
                      totals: _totals[def.key],
                      isLoading:
                      !_totals.containsKey(def.key) && !_failed.contains(def.key),
                      hasError: _failed.contains(def.key),
                      onTap: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            StockDetailScreen(prosesKey: def.key, title: def.title),
                      ),
                    )).toList(),
                  ),
                  SizedBox(height: 12.0),

                ],
              );

            }).toList(),
          ),
        ),
      )
      /*body: LayoutBuilder(
        builder: (context, constraints) {
          final cols = (constraints.maxWidth / 160).floor().clamp(2, 6);
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisExtent: 140,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: _kStockProsesList.length,
            itemBuilder: (context, index) {
              final def = _kStockProsesList[index];
              return StockProsesCard(
                title: def.title,
                icon: def.icon,
                totals: _totals[def.key],
                isLoading:
                    !_totals.containsKey(def.key) && !_failed.contains(def.key),
                hasError: _failed.contains(def.key),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      StockDetailScreen(prosesKey: def.key, title: def.title),
                ),
              );
            },
          );
        },
      ),*/
    );
  }
}
