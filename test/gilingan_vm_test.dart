import 'package:flutter_test/flutter_test.dart';

import 'package:pps_tablet/features/production/gilingan/model/gilingan_production_model.dart';
import 'package:pps_tablet/features/production/gilingan/repository/gilingan_production_repository.dart';
import 'package:pps_tablet/features/production/gilingan/view_model/gilingan_production_view_model.dart';

void main() {
  late GilinganProductionViewModel vm;

  setUp(() {
    vm = GilinganProductionViewModel(
      repository: FakeGilinganRepository(), // pakai fake, bukan DB beneran
    );
  });

  test('Create Produksi Gilingan', () async {
    final result = await vm.createProduksi(
      tglProduksi: DateTime(2025, 01, 01),
      idMesin: 1,
      idOperators: [2],
      shift: 1,
      jam: 2,
      hourStart: "08:00:00",
      hourEnd: "10:00:00",
      jmlhAnggota: 5,
      hadir: 4,
      hourMeter: 120,
    );

    expect(result != null, true);
    expect(vm.saveError, null);

    print("LOG CREATE: noProduksi = ${result?.noProduksi}");
    print("LOG CREATE: hourRange = ${result?.hourRangeText}");
  });

  test('Update Produksi Gilingan', () async {
    final result = await vm.updateProduksi(
      noProduksi: "W.00001",
      tglProduksi: DateTime(2025, 01, 02),
      idMesin: 1,
      idOperator: 3,
      shift: 2,
      hourStart: "09:00:00",
      hourEnd: "11:00:00",
      jmlhAnggota: 4,
      hadir: 4,
      hourMeter: 130,
    );

    expect(result != null, true);
    expect(vm.saveError, null);

    print("LOG UPDATE: noProduksi = ${result?.noProduksi}");
    print("LOG UPDATE: operator = ${result?.namaOperator}");
    print("LOG UPDATE: hourRange = ${result?.hourRangeText}");
  });

  test('Delete Produksi Gilingan', () async {
    final result = await vm.deleteProduksi("W.00001");

    expect(result, true);
    expect(vm.saveError, null);

    print("LOG DELETE: W.00001 OK");
  });
}

/// Fake Repository (supaya tidak hit database)
class FakeGilinganRepository extends GilinganProductionRepository {
  @override
  Future<Map<String, dynamic>> fetchAll({
    required int page,
    int pageSize = 20,
    String? search,
    String? noProduksi,
    bool exactNoProduksi = false,
    int? shift,
    DateTime? date,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? idMesin,
    int? idOperator,
  }) async {
    // Dummy response → kosong tapi valid
    return {
      'items': <GilinganProduction>[],
      'totalPages': 1,
    };
  }

  @override
  Future<GilinganProduction> createProduksi({
    required DateTime tglProduksi,
    required int idMesin,
    required List<int> idOperators,
    required int shift,
    required double jam,
    int? outputJenisId,
    int? idRegu,
    String? hourStart,
    String? hourEnd,
    int? jmlhAnggota,
    int? hadir,
    double? hourMeter,
  }) async {
    // Konversi hourMeter (double?) → int?
    final intHourMeter = hourMeter?.toInt();

    return GilinganProduction(
      noProduksi: "W.TEST_CREATE",
      idOperator: idOperators.isNotEmpty ? idOperators.first : 0,
      idMesin: idMesin,
      namaMesin: "Mesin Fake",
      namaOperator: "Operator Fake",
      tglProduksi: tglProduksi,
      shift: shift,
      createBy: "UNIT_TEST",
      jmlhAnggota: jmlhAnggota,
      hadir: hadir,
      hourMeter: intHourMeter,
      hourStart: hourStart, // simpan format "HH:mm:00" atau "HH:mm"
      hourEnd: hourEnd,
      outputJenisId: outputJenisId,
      idRegu: idRegu,
    );
  }

  @override
  Future<GilinganProduction> updateProduksi({
    required String noProduksi,
    DateTime? tglProduksi,
    int? idMesin,
    int? idOperator,
    int? shift,
    String? hourStart,
    String? hourEnd,
    int? jmlhAnggota,
    int? hadir,
    double? hourMeter,
    String? approveBy,
    String? checkBy1,
    String? checkBy2,
  }) async {
    final intHourMeter = hourMeter?.toInt();

    return GilinganProduction(
      noProduksi: noProduksi,
      idOperator: idOperator ?? 99,
      idMesin: idMesin ?? 88,
      namaMesin: "Mesin Update",
      namaOperator: "Operator Update",
      tglProduksi: tglProduksi ?? DateTime(2025, 01, 02),
      shift: shift ?? 2,
      createBy: "UNIT_TEST",
      jmlhAnggota: jmlhAnggota ?? 3,
      hadir: hadir ?? 3,
      hourMeter: intHourMeter ?? 100,
      checkBy1: checkBy1,
      checkBy2: checkBy2,
      approveBy: approveBy,
      hourStart: hourStart ?? "09:00",
      hourEnd: hourEnd ?? "11:00",
    );
  }

  @override
  Future<void> deleteProduksi(String noProduksi) async {
    // Anggap selalu sukses
    return;
  }
}
