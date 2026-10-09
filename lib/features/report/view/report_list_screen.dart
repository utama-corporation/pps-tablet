// lib/features/report/view/report_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/loading_dialog.dart';
import '../../../core/network/api_client.dart';
import '../model/report_item.dart';
import '../service/report_pdf_service.dart';
import '../view_model/report_list_view_model.dart';
import '../widgets/report_param_dialog.dart';
import 'report_pdf_viewer_screen.dart';

class ReportListScreen extends StatelessWidget {
  const ReportListScreen({super.key});

  static const List<ReportItem> reports = [
    ReportItem(
      title: 'Mutasi Washing',
      subtitle: '', // tidak dipakai di UI
      reportName: 'MutasiWashing',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Mutasi Broker',
      subtitle: '', // tidak dipakai di UI
      reportName: 'MutasiBroker',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Mutasi Bonggolan',
      subtitle: '', // tidak dipakai di UI
      reportName: 'MutasiBonggolan',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Mutasi Crusher',
      subtitle: '',
      reportName: 'MutasiCrusher',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Mutasi Gilingan',
      subtitle: '',
      reportName: 'MutasiGilingan',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Mutasi Mixer',
      subtitle: '',
      reportName: 'MutasiMixer',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Mutasi Furniture WIP',
      subtitle: '',
      reportName: 'MutasiFurnitureWIP',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Mutasi Barang Jadi',
      subtitle: '',
      reportName: 'MutasiBarangJadi',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Mutasi Reject',
      subtitle: '',
      reportName: 'MutasiReject',
      icon: Icons.picture_as_pdf_outlined,
    ),
    ReportItem(
      title: 'Rekap Produksi',
      subtitle: '',
      reportName: 'RekapProduksi',
      icon: Icons.summarize_outlined,
      isSingleDate: true,
      source: ReportSource.ppsApi,
      ppsApiPath: '/api/reports/pps/rekap-produksi/inject/pdf',
    ),
    ReportItem(
      title: 'Rekap Produksi BJ',
      subtitle: '',
      reportName: 'RekapProduksiBJ',
      icon: Icons.summarize_outlined,
      isSingleDate: true,
      source: ReportSource.ppsApi,
      ppsApiPath: '/api/reports/pps/rekap-produksi/inject-bj/pdf',
    ),
    ReportItem(
      title: 'Packing BJ',
      subtitle: '',
      reportName: 'PackingBJ',
      icon: Icons.inventory_2_outlined,
      isSingleDate: true,
      source: ReportSource.ppsApi,
      ppsApiPath: '/api/reports/pps/rekap-produksi/packing-bj/pdf',
    ),
    ReportItem(
      title: 'Hot Stamping FWIP',
      subtitle: '',
      reportName: 'HotStampingFWIP',
      icon: Icons.local_fire_department_outlined,
      isSingleDate: true,
      source: ReportSource.ppsApi,
      ppsApiPath: '/api/reports/pps/rekap-produksi/hot-stamping-fwip/pdf',
    ),
    ReportItem(
      title: 'Spanner FWIP',
      subtitle: '',
      reportName: 'SpannerFWIP',
      icon: Icons.build_outlined,
      isSingleDate: true,
      source: ReportSource.ppsApi,
      ppsApiPath: '/api/reports/pps/rekap-produksi/spanner-fwip/pdf',
    ),
    ReportItem(
      title: 'Pasang Kunci FWIP',
      subtitle: '',
      reportName: 'PasangKunciFWIP',
      icon: Icons.key_outlined,
      isSingleDate: true,
      source: ReportSource.ppsApi,
      ppsApiPath: '/api/reports/pps/rekap-produksi/pasang-kunci-fwip/pdf',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // TODO: ambil username dari session/login
    const username = 'ADMIN';

    return ChangeNotifierProvider(
      create: (_) => ReportListViewModel(
        initialReports: reports,
        pdfService: ReportPdfService(),
        apiClient: ApiClient(),
        username: username,
      ),
      child: const _ReportListView(),
    );
  }
}

class _ReportListView extends StatefulWidget {
  const _ReportListView();

  @override
  State<_ReportListView> createState() => _ReportListViewState();
}

class _ReportListViewState extends State<_ReportListView> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportListViewModel>();
    final items = vm.filteredReports;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0xFF0D47A1), Colors.grey[100]!],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => vm.search = v,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Cari laporan...',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.grey[600],
                    size: 22,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          onPressed: () {
                            _searchCtrl.clear();
                            vm.search = '';
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),

          // Badge jumlah laporan (optional, boleh hapus kalau mau super minimal)
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length} Laporan',
                      style: const TextStyle(
                        color: Color(0xFF0D47A1),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 72,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada laporan',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: items.length,
                    itemBuilder: (_, i) {
                      final item = items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ReportCard(
                          title: item.title,
                          icon: item.icon,
                          onTap: () => _openParamDialog(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _openParamDialog(ReportItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReportParamDialog(
        title: item.title,
        icon: item.icon,
        singleDate: item.isSingleDate,
        onGenerate: (startDate, endDate) =>
            _handleGenerateReport(item, startDate, endDate),
      ),
    );
  }

  Future<void> _handleGenerateReport(
    ReportItem item,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final vm = context.read<ReportListViewModel>();

    // showDialog() default-nya useRootNavigator: true, jadi LoadingDialog
    // di-push ke ROOT navigator. ReportPdfViewerScreen.push juga memakai
    // rootNavigator: true.
    //
    // Navigator.of(context) tanpa rootNavigator memakai navigator TERDEKAT,
    // yaitu shell navigator milik AppShell - dan shell navigator itu selalu
    // hanya punya SATU route (home_sidebar memakai pushNamedAndRemoveUntil
    // dengan (r) => false), sehingga pop() di sana tidak pernah mengubah
    // apa pun. Akibatnya LoadingDialog tidak pernah tertutup: ia hanya
    // tersembunyi di belakang PDF viewer, lalu muncul lagi begitu viewer
    // ditutup.
    //
    // Karena itu popup DAN penutupannya harus memakai root navigator yang
    // sama. Ditangkap di sini (sebelum await) supaya tetap aman kalau
    // widget-nya ke-unmount saat download berjalan.
    final rootNavigator = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const LoadingDialog(message: 'Mengunduh laporan...'),
    );

    var loaderClosed = false;
    void closeLoader() {
      if (loaderClosed) return;
      loaderClosed = true;
      if (rootNavigator.mounted && rootNavigator.canPop()) {
        rootNavigator.pop();
      }
    }

    try {
      final bytes = await vm.generateReport(
        item: item,
        startDate: startDate,
        endDate: endDate,
      );

      if (!mounted) return;

      closeLoader();

      await ReportPdfViewerScreen.push(
        context: context,
        title: item.title,
        pdfBytes: bytes,
        isSingleDate: item.isSingleDate,
        startDate: startDate,
        endDate: endDate,
        onRegenerate: (s, e) =>
            vm.generateReport(item: item, startDate: s, endDate: e),
      );
    } catch (e) {
      closeLoader();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Gagal membuka PDF: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      closeLoader();
    }
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ReportCard({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D47A1).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF212121),
                    ),
                  ),
                ),

                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF0D47A1),
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
