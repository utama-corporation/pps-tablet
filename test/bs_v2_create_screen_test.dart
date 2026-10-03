import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/features/bongkar_susun_v2/model/bs_v2_label_info.dart';
import 'package:pps_tablet/features/bongkar_susun_v2/model/bs_v2_transaction.dart';
import 'package:pps_tablet/features/bongkar_susun_v2/repository/bs_v2_repository.dart';
import 'package:pps_tablet/features/bongkar_susun_v2/view/bs_v2_create_screen.dart';
import 'package:pps_tablet/features/bongkar_susun_v2/view_model/bs_v2_create_view_model.dart';

class _FakeRepo extends BsV2Repository {
  _FakeRepo() : super(apiClient: null);
  @override
  Future<BsV2Transaction> submit({
    required String note,
    required List<String> inputs,
    required List<Map<String, dynamic>> outputs,
  }) async {
    return BsV2Transaction(noBongkarSusun: 'BG.TEST', category: 'barangJadi');
  }
}

BsV2LabelInfo _bj(String code, double pcs, {int idJenis = 1}) =>
    BsV2LabelInfo(
      labelCode: code,
      category: 'barangJadi',
      idJenis: idJenis,
      namaJenis: 'Jenis A',
      totalBerat: pcs,
    );

Future<BsV2CreateViewModel> _pump(WidgetTester tester) async {
  // Tablet landscape supaya panel tidak sempit.
  tester.view.physicalSize = const Size(2560, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);

  final vm = BsV2CreateViewModel(repository: _FakeRepo());
  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<BsV2CreateViewModel>.value(
        value: vm,
        child: const BsV2CreateScreen(),
      ),
    ),
  );
  return vm;
}

void main() {
  testWidgets('input 5+5 dengan 1 output 10 pcs: 2 baris, submit aktif', (
    tester,
  ) async {
    final vm = await _pump(tester);

    vm.inputs.add(_bj('BA.001', 5));
    vm.inputs.add(_bj('BA.002', 5));
    vm.addOutput();
    vm.updateOutputBerat(vm.outputs.first.id, 10);
    await tester.pumpAndSettle();

    // Alokasi per label: KEDUA baris harus terisi, bukan cuma baris pertama.
    final a = vm.inputAllocations;
    expect(a.length, 2);
    expect(a[0].allocated, 5.0);
    expect(a[1].allocated, 5.0);
    expect(a[1].remaining, 0.0);

    // Tidak boleh ada pesan tidak seimbang.
    expect(vm.isBalanced, isTrue);
    expect(vm.balanceError, isNull);
    expect(find.textContaining('belum seimbang'), findsNothing);

    // Submit harus aktif (tidak greyed-out).
    final submitBtn = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.text('Submit Transaksi'),
        matching: find.byType(AnimatedContainer),
      ).first,
    );
    final box =
        (submitBtn.decoration as BoxDecoration?)?.color ??
        submitBtn.decoration;
    expect(box, isNot(const Color(0xFFE0E0E0)));

    //_unit_ pcs, bukan kg.
    expect(find.text('10 pcs'), findsOneWidget);
    expect(find.text('10 kg'), findsNothing);
  });

  testWidgets('output 7 dari 5+5: baris kedua jadi sisa 3 dan diblokir', (
    tester,
  ) async {
    final vm = await _pump(tester);

    vm.inputs.add(_bj('BA.001', 5));
    vm.inputs.add(_bj('BA.002', 5));
    vm.addOutput();
    vm.updateOutputBerat(vm.outputs.first.id, 7);
    await tester.pumpAndSettle();

    final a = vm.inputAllocations;
    expect(a[0].allocated, 5.0);
    expect(a[1].allocated, 2.0);
    expect(a[1].remaining, 3.0);

    expect(vm.isBalanced, isFalse);
    expect(vm.balanceError, contains('kurang 3 pcs'));
    expect(find.textContaining('belum seimbang'), findsWidgets);
  });

  testWidgets('dua jenis berbeda: 1 output 10 tidak bisa menutup dua jenis', (
    tester,
  ) async {
    final vm = await _pump(tester);

    vm.inputs.add(_bj('BA.001', 5, idJenis: 1));
    vm.inputs.add(_bj('BA.002', 5, idJenis: 2));
    vm.addOutput();
    vm.updateOutputBerat(vm.outputs.first.id, 10);
    await tester.pumpAndSettle();

    // Output 10 pcs semuanya nempel ke jenis 1 (yang cuma punya 5).
    final a = vm.inputAllocations;
    expect(a[0].allocated, 5.0);
    expect(a[0].remaining, 0.0);
    expect(a[1].allocated, 0.0);
    expect(a[1].remaining, 5.0);

    expect(vm.isBalanced, isFalse);
    expect(vm.balanceError, contains('lebih 5 pcs'));
  });
}