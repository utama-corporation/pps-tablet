import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/features/stock_opname_v2/model/so_v2_kategori.dart';
import 'package:pps_tablet/features/stock_opname_v2/model/so_v2_riwayat_sesi.dart';
import 'package:pps_tablet/features/stock_opname_v2/repository/so_v2_repository.dart';
import 'package:pps_tablet/features/stock_opname_v2/view_model/so_v2_riwayat_view_model.dart';
import 'package:pps_tablet/features/stock_opname_v2/widgets/so_v2_riwayat_panel.dart';

class FakeSoV2Repository extends SoV2Repository {
  FakeSoV2Repository();

  final List<int> requestedPages = [];

  @override
  Future<SoV2RiwayatPage> fetchRiwayat({
    required int page,
    int pageSize = 20,
    String? search,
    SoV2Status? status,
  }) async {
    requestedPages.add(page);
    // Halaman 1 berisi 2 sesi, halaman berikutnya kosong supaya rantai
    // paging berhenti (getNextPageKey mengembalikan null).
    if (page > 1) {
      return const SoV2RiwayatPage(
        data: [],
        currentPage: 2,
        pageSize: 20,
        totalRecords: 2,
        totalPages: 1,
      );
    }
    return SoV2RiwayatPage(
      data: const [
        SoV2RiwayatSesi(
          stockOpnameNo: 'SO.0000000018',
          categoryId: 9,
          categoryCode: 'barangjadi',
          categoryName: 'Barang Jadi',
          status: SoV2Status.inProgress,
          labelCount: 100,
          scannedCount: 25,
        ),
        SoV2RiwayatSesi(
          stockOpnameNo: 'SO.0000000016',
          categoryId: 4,
          categoryCode: 'crusher',
          categoryName: 'Crusher',
          status: SoV2Status.completed,
          labelCount: 50,
          scannedCount: 50,
        ),
      ],
      currentPage: 1,
      pageSize: 20,
      totalRecords: 2,
      totalPages: 1,
    );
  }
}

Widget _wrap(SoV2RiwayatViewModel vm) {
  return MaterialApp(
    home: Scaffold(
      body: SoV2RiwayatPanel(
        vm: vm,
        isOpen: true,
        onClose: () {},
        onOpenSesi: (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('panel otomatis fetch halaman 1 dan menampilkan sesi', (
    tester,
  ) async {
    final repo = FakeSoV2Repository();
    final vm = SoV2RiwayatViewModel(repository: repo);

    await tester.pumpWidget(_wrap(vm));
    await tester.pumpAndSettle();

    expect(repo.requestedPages, contains(1));
    expect(find.text('SO.0000000018'), findsOneWidget);
    expect(find.text('Barang Jadi'), findsOneWidget);
    expect(find.text('25/100 label'), findsOneWidget);
    // Spinner halaman pertama harus hilang setelah data masuk.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Menampilkan 2 dari 2 sesi'), findsOneWidget);
  });

  testWidgets('error di halaman pertama menampilkan tombol Coba lagi', (
    tester,
  ) async {
    final vm = SoV2RiwayatViewModel(
      repository: _ErrorRepository(),
    );
    await tester.pumpWidget(_wrap(vm));
    await tester.pumpAndSettle();

    expect(find.text('Coba lagi'), findsOneWidget);
  });
}

class _ErrorRepository extends SoV2Repository {
  _ErrorRepository();

  @override
  Future<SoV2RiwayatPage> fetchRiwayat({
    required int page,
    int pageSize = 20,
    String? search,
    SoV2Status? status,
  }) async {
    throw Exception('Endpoint riwayat belum tersedia');
  }
}
