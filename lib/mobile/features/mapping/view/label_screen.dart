// lib/features/label/view/label_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/lokasi/lokasi_repository.dart';
import '../../../shared/lokasi/lokasi_view_model.dart';
import '../repository/label_repository.dart';
import '../view_model/label_view_model.dart';
import '../widgets/label_filter_bar.dart';
import '../widgets/label_list_view.dart';
import '../widgets/summary_card.dart';
import 'barcode_qr_scan_mapping_screen.dart';
import '../../../widgets/error_status_dialog.dart';


class LabelScreen extends StatelessWidget {
  const LabelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LokasiViewModel(repository: LokasiRepository())..fetchLokasiList(),
        ),
        ChangeNotifierProvider(
          create: (_) => LabelViewModel(repository: LabelRepository())..fetchFirstPage(),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mapping', style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF0D47A1),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const _Body(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Builder(
          builder: (fabCtx) => FloatingActionButton(
            backgroundColor: const Color(0xFF0D47A1), // biru gelap
            elevation: 4,
            tooltip: 'Scan QR Label',
            child: const Icon(
              Icons.qr_code_scanner,
              color: Colors.white, // ikon putih
              size: 28,
            ),
            onPressed: () {
              final vm = fabCtx.read<LabelViewModel>();
              final idLokasi = vm.selectedIdLokasi;
              final blok = vm.selectedBlok;
              final selectedFilter = vm.selectedKategori ?? 'semua';

              if (idLokasi == null || idLokasi.isEmpty || idLokasi.toLowerCase() == 'semua') {
                showDialog(
                  context: fabCtx,
                  builder: (_) => const ErrorStatusDialog(
                    title: 'Lokasi Belum Dipilih',
                    message: 'Silakan pilih lokasi terlebih dahulu sebelum melakukan scan!',
                  ),
                );
                return;
              }

              Navigator.push(
                fabCtx,
                MaterialPageRoute(
                  builder: (_) => BarcodeQrScanMappingScreen(
                    selectedFilter: selectedFilter,
                    idLokasi: idLokasi,
                    blok: blok,
                  ),
                ),
              ).then((_) {
                fabCtx.read<LabelViewModel>().refresh();
              });
            },
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<LabelViewModel>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, // biar full width
            children: [
              const LabelFilterBar(),
              const SizedBox(height: 8),
              SummaryCard( // ⬅️ pakai widget terpisah
                total: vm.totalData,
                kategori: vm.selectedKategori ?? 'semua',
                lokasi: vm.selectedIdLokasi ?? 'semua',
                totalQty: vm.totalQty,
                totalBerat: vm.totalBerat,
              ),
            ],
          ),
        ),
        const Expanded(child: LabelListView()),
      ],
    );
  }
}
