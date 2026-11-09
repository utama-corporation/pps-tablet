// test/gilingan_partial_staged_test.dart
//
// Regresi: partial kedua untuk label gilingan yang sama HARUS bisa
// di-stage walaupun partial pertama masih ada di temp (belum submit).
// Skenario nyata: label 20kg, partial 17.28 di-stage, operator lalu
// menginput sisa 2.72 -> sebelumnya ditolak frontend ("Gagal menambahkan
// atau sudah ada") karena base key collision.

import 'package:flutter_test/flutter_test.dart';

import 'package:pps_tablet/features/production/broker/repository/broker_production_input_repository.dart';
import 'package:pps_tablet/features/production/broker/view_model/broker_production_input_view_model.dart'
    hide TempCommitResult;
import 'package:pps_tablet/features/production/inject/repository/inject_production_input_repository.dart';
import 'package:pps_tablet/features/production/inject/view_model/inject_production_input_view_model.dart'
    hide TempCommitResult;
import 'package:pps_tablet/features/production/mixer/repository/mixer_production_input_repository.dart';
import 'package:pps_tablet/features/production/mixer/view_model/mixer_production_input_view_model.dart'
    hide TempCommitResult;
import 'package:pps_tablet/features/production/shared/models/gilingan_item.dart';
import 'package:pps_tablet/features/production/shared/models/production_label_lookup_result.dart';
import 'package:pps_tablet/features/production/washing/repository/washing_production_input_repository.dart';
import 'package:pps_tablet/features/production/washing/view_model/washing_production_input_view_model.dart'
    hide TempCommitResult;

void main() {
  Map<String, dynamic> gilinganRow({
    required String label,
    required num berat,
  }) =>
      {
        'NoGilingan': label,
        'Berat': berat,
        'IdJenis': 1,
        'NamaJenis': 'GRA',
      };

  /// Stage partial pertama (17.28) lalu commit — balikan hasil commit.
  ///
  /// Meniru alur nyata: dialog lookup row berat asli (20) lalu menulis
  /// berat yang dipetik + flag partial pada row DI DALAM ctx.
  dynamic stageFirstPartial(
    dynamic vm,
    ProductionLabelLookupResult Function(List<Map<String, dynamic>>) makeCtx,
    Map<String, dynamic> baseRow,
  ) {
    final firstRow = gilinganRow(label: baseRow['NoGilingan'], berat: 20.0);
    (vm as dynamic).lastLookup = makeCtx([firstRow]);

    // seperti MixerGilinganWeightDialog._commit: mutasi row ctx
    final row = (vm as dynamic).lastLookup.data.first;
    row['Berat'] = 17.28;
    row['berat'] = 17.28;
    row['isPartial'] = true;
    row['IsPartial'] = true;

    (vm as dynamic).togglePick(row);
    return (vm as dynamic).commitPickedToTemp(noProduksi: 'PRD-1');
  }

  /// Stage partial kedua (sisa 2.72) untuk label yang sama.
  dynamic stageRemainderPartial(
    dynamic vm,
    ProductionLabelLookupResult Function(List<Map<String, dynamic>>) makeCtx,
    Map<String, dynamic> baseRow,
  ) {
    final secondRow = gilinganRow(label: baseRow['NoGilingan'], berat: 20.0);
    (vm as dynamic).lastLookup = makeCtx([secondRow]);

    final row = (vm as dynamic).lastLookup.data.first;
    row['Berat'] = 2.72;
    row['berat'] = 2.72;
    row['isPartial'] = true;
    row['IsPartial'] = true;

    (vm as dynamic).togglePick(row);
    return (vm as dynamic).commitPickedToTemp(noProduksi: 'PRD-1');
  }

  void runMatrixFor(String name, dynamic Function() vmFactory) {
    group('$name — partial bertahap pada label gilingan yang sama', () {
      late Map<String, dynamic> baseRow;
      late dynamic vm;

      setUp(() {
        vm = vmFactory();
        baseRow = gilinganRow(label: 'V.0000012345', berat: 20.0);
      });

      ProductionLabelLookupResult makeCtx(
        List<Map<String, dynamic>> data,
      ) =>
          ProductionLabelLookupResult.success({
            'prefix': 'V.',
            'tableName': 'Gilingan',
            'data': data,
          });

      test(
        'partial kedua (sisa 2.72) diterima; keduanya masuk temp partial',
        () {
          final r1 = stageFirstPartial(vm, makeCtx, baseRow);
          expect(r1.added, 1, reason: 'partial pertama (17.28) harus masuk');

          final r2 = stageRemainderPartial(vm, makeCtx, baseRow);
          expect(r2.added, 1,
              reason: 'partial kedua (2.72) untuk label sama tidak boleh '
                  'ditolak frontend');

          final partials = (vm as dynamic).tempGilinganPartial
              .where((e) =>
                  (e as GilinganItem).noGilingan == 'V.0000012345')
              .cast<GilinganItem>()
              .toList();
          expect(partials.length, 2,
              reason: 'dua temp partial untuk label yang sama');
          expect(
            partials.map((e) => e.berat).toSet(),
            {17.28, 2.72},
          );
        },
      );

      test(
        're-input partial dengan berat yang sama idempoten (tidak terjadi '
        'double-counting)',
        () {
          final r1 = stageFirstPartial(vm, makeCtx, baseRow);
          expect(r1.added, 1);

          // re-scan, berat SAMA (17.28) -> skip; meniru dialog yang
          // mengubah row DI DALAM ctx sebelum pick/commit
          final againRow = gilinganRow(label: baseRow['NoGilingan'], berat: 20.0);
          (vm as dynamic).lastLookup = makeCtx([againRow]);
          final rowAgain = (vm as dynamic).lastLookup.data.first;
          rowAgain['Berat'] = 17.28;
          rowAgain['berat'] = 17.28;
          rowAgain['isPartial'] = true;
          rowAgain['IsPartial'] = true;

          (vm as dynamic).togglePick(rowAgain);
          final r2 = (vm as dynamic).commitPickedToTemp(noProduksi: 'PRD-1');
          expect(r2.added, 0,
              reason: 'partial dengan berat identik dianggap duplikat');

          final partials = (vm as dynamic).tempGilinganPartial
              .where((e) =>
                  (e as GilinganItem).noGilingan == 'V.0000012345')
              .toList();
          expect(partials.length, 1);
        },
      );

      test(
        'input FULL tidak boleh ditumpuk di atas temp partial label yang sama',
        () {
          final r1 = stageFirstPartial(vm, makeCtx, baseRow);
          expect(r1.added, 1);

          final fullRow = gilinganRow(label: baseRow['NoGilingan'], berat: 20.0);
          (vm as dynamic).lastLookup = makeCtx([fullRow]);
          // full input: row ctx digunakan utuh (tidak ada mutasi partial)
          final rowFull = (vm as dynamic).lastLookup.data.first;

          (vm as dynamic).togglePick(rowFull);
          final r2 = (vm as dynamic).commitPickedToTemp(noProduksi: 'PRD-1');
          expect(r2.added, 0,
              reason: 'buffer full seluruh label tidak konsisten '
                  'dengan partial yang sudah di-stage');

          expect((vm as dynamic).tempGilingan.length, 0);
        },
      );
    });
  }

  runMatrixFor(
    'mixer',
    () => MixerProductionInputViewModel(
      repository: MixerProductionInputRepository(),
    ),
  );

  runMatrixFor(
    'washing',
    () => WashingProductionInputViewModel(
      repository: WashingProductionInputRepository(),
    ),
  );

  runMatrixFor(
    'broker',
    () => BrokerProductionInputViewModel(
      repository: BrokerProductionInputRepository(),
    ),
  );

  runMatrixFor(
    'inject',
    () => InjectProductionInputViewModel(
      repository: InjectProductionInputRepository(),
    ),
  );
}
