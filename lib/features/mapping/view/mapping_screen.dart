import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/core/network/api_client.dart';
import 'package:pps_tablet/core/view/app_shell.dart';
import 'package:pps_tablet/features/mapping/repository/mapping_repository.dart';
import 'package:pps_tablet/features/mapping/view/mapping_lokasi_screen.dart';
import 'package:pps_tablet/features/mapping/view_model/mapping_view_model.dart';

const Color _primary = Color(0xFF0D47A1);

class MappingScreen extends StatelessWidget {
  const MappingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          MappingViewModel(repository: MappingRepository(api: ApiClient()))
            ..loadBlok(),
      child: const _MappingView(),
    );
  }
}

class _MappingView extends StatelessWidget {
  const _MappingView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MappingViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: _buildContent(context, vm),
    );
  }

  Widget _buildContent(BuildContext context, MappingViewModel vm) {
    if (vm.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (vm.error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text(vm.error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.read<MappingViewModel>().loadBlok(),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (vm.blokList.isEmpty) {
      return const Center(child: Text('Tidak ada data blok'));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 16,
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pilih Blok Warehouse',
                style: TextStyle(
                  color: _primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${vm.blokList.length} blok',
                style: TextStyle(color: Colors.grey[400], fontSize: 11),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _groupByWarehouse(vm.blokList).entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: entry.value
                            .map((blok) => _buildBlokCard(context, blok))
                            .toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, List<dynamic>> _groupByWarehouse(List<dynamic> blokList) {
    final map = <String, List<dynamic>>{};
    for (final blok in blokList) {
      map.putIfAbsent(blok.namaWarehouse, () => []).add(blok);

      //print(map);
    }
    return map;
  }

  Widget _buildBlokCard(BuildContext context, blok) {
    return GestureDetector(
      onTap: () {
        AppShell.breadcrumb.value = [
          BreadcrumbSegment(
            'Mapping',
            onTap: () => Navigator.of(context).maybePop(),
          ),
          BreadcrumbSegment("Layout ${blok.blok}"),
        ];
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (_) => MappingLokasiScreen(
                  blok: blok.blok,
                  namaWarehouse: blok.namaWarehouse,
                ),
              ),
            )
            .then((_) {
              AppShell.breadcrumb.value = [const BreadcrumbSegment('Mapping')];
            });
      },
      child: Container(
        width: 80,
        height: 88,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              blok.blok,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _primary,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: blok.totalLokasi > 0
                    ? _primary.withValues(alpha: 0.10)
                    : Colors.grey.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${blok.totalLokasi} lokasi',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: blok.totalLokasi > 0 ? _primary : Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: blok.totalJenis > 0
                    ? const Color(0xFF2E7D32).withValues(alpha: 0.10)
                    : Colors.grey.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${blok.totalJenis} jenis',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: blok.totalJenis > 0
                      ? const Color(0xFF2E7D32)
                      : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
