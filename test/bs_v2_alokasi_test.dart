import 'package:flutter_test/flutter_test.dart';

import 'package:pps_tablet/features/bongkar_susun_v2/model/bs_v2_label_info.dart';
import 'package:pps_tablet/features/bongkar_susun_v2/view_model/bs_v2_create_view_model.dart';

BsV2LabelInfo _bj(String code, double pcs, {int idJenis = 1, bool partial = false}) {
  return BsV2LabelInfo(
    labelCode: code,
    category: 'barangJadi',
    idJenis: idJenis,
    namaJenis: 'Jenis A',
    totalBerat: pcs,
    isPartial: partial,
  );
}

void main() {
  late BsV2CreateViewModel vm;

  setUp(() {
    vm = BsV2CreateViewModel();
  });

  void addInput(BsV2LabelInfo l) => vm.inputs.add(l);
  void addOutput(double pcs) {
    final id = 'out${vm.outputs.length}';
    vm.outputs.add(OutputEntry(id: id, idJenis: 1, namaJenis: 'Jenis A')..berat = pcs);
  }

  test('input 5 + 5, output 10 -> kedua baris terisi penuh', () {
    addInput(_bj('BA.001', 5));
    addInput(_bj('BA.002', 5));
    addOutput(10);

    final alloc = vm.inputAllocations;
    expect(alloc.length, 2, reason: 'harus 1 baris per label input');

    // Baris pertama PENUH, bukan cuma baris pertama yang tergerus.
    expect(alloc[0].allocated, 5.0);
    expect(alloc[0].remaining, 0.0);
    expect(alloc[0].isFullyAllocated, isTrue);

    // Baris kedua ikut terisi.
    expect(alloc[1].allocated, 5.0);
    expect(alloc[1].remaining, 0.0);
    expect(alloc[1].isFullyAllocated, isTrue);

    expect(vm.isBalanced, isTrue);
    expect(vm.balanceError, isNull);
  });

  test('input 5 + 5, output 7 -> berurutan, baris kedua sisanya', () {
    addInput(_bj('BA.001', 5));
    addInput(_bj('BA.002', 5));
    addOutput(7);

    final alloc = vm.inputAllocations;
    expect(alloc[0].allocated, 5.0);
    expect(alloc[0].remaining, 0.0);
    expect(alloc[1].allocated, 2.0);
    expect(alloc[1].remaining, 3.0);

    expect(vm.isBalanced, isFalse);
    expect(vm.balanceError, contains('kurang 3 pcs'));
  });

  test('input 5 + 5, output 12 -> over, pesan lebih', () {
    addInput(_bj('BA.001', 5));
    addInput(_bj('BA.002', 5));
    addOutput(12);

    final alloc = vm.inputAllocations;
    // Baris tidak boleh alokasi melebihi totalnya.
    expect(alloc[0].allocated, 5.0);
    expect(alloc[1].allocated, 5.0);
    expect(vm.isBalanced, isFalse);
    expect(vm.balanceError, contains('lebih 2 pcs'));
  });

  test('output kosong -> pesan output belum diisi', () {
    addInput(_bj('BA.001', 5));
    expect(vm.balanceError, 'Output belum diisi. Tambahkan minimal 1 output.');
  });

  test('input 0 pcs -> pesan output belum seimbang dengan input', () {
    addInput(_bj('BA.001', 5));
    addOutput(0);
    // pcs 0 tidak valid sebagai output
    expect(vm.balanceError, isNotNull);
  });

  test('sisa label yang sudah partial dipakai utuh', () {
    addInput(_bj('BA.001', 6, partial: true));
    addOutput(6);

    final alloc = vm.inputAllocations;
    expect(alloc.length, 1);
    expect(alloc[0].allocated, 6.0);
    expect(vm.isBalanced, isTrue);
  });

  test('dua jenis terpisah tidak saling mengurangi', () {
    addInput(_bj('BA.001', 5, idJenis: 1));
    addInput(_bj('BA.002', 5, idJenis: 2));
    final id = 'out0';
    vm.outputs.add(OutputEntry(id: id, idJenis: 1, namaJenis: 'Jenis A')..berat = 5);

    final alloc = vm.inputAllocations;
    expect(alloc[0].allocated, 5.0);
    expect(alloc[1].allocated, 0.0);
    expect(alloc[1].remaining, 5.0);
    expect(vm.isBalanced, isFalse);
  });

  test('detail: input parsial terbaca noPartial + totalPcs', () {
    final info = BsV2LabelInfo.fromJson(const {
      'labelCode': 'BA.0000015668',
      'category': 'barangJadi',
      'idJenis': 1,
      'namaJenis': 'Jenis A',
      'pcs': 9,
      'totalPcs': 15,
      'isPartial': true,
      'noPartial': 'BL.0000009999',
    });

    expect(info.isPartial, isTrue);
    expect(info.noPartial, 'BL.0000009999');
    expect(info.totalPcs, 15.0);
    // pcs terpakai = sisa label, bukan pcs asli
    expect(info.totalBerat, 9.0);
  });

  test('detail: input utuh tidak punya noPartial/totalPcs', () {
    final info = BsV2LabelInfo.fromJson(const {
      'labelCode': 'BA.0000000001',
      'category': 'barangJadi',
      'idJenis': 1,
      'namaJenis': 'Jenis A',
      'pcs': 12,
      'isPartial': false,
    });

    expect(info.isPartial, isFalse);
    expect(info.noPartial, isNull);
    expect(info.totalPcs, isNull);
    expect(info.totalBerat, 12.0);
  });

  test('detail: noPartial kosong string harus jadi null', () {
    final info = BsV2LabelInfo.fromJson(const {
      'labelCode': 'BA.0000000002',
      'category': 'barangJadi',
      'idJenis': 1,
      'namaJenis': 'Jenis A',
      'pcs': 5,
      'isPartial': 1,
      'noPartial': '',
    });

    expect(info.isPartial, isTrue, reason: 'flag isPartial=1 (int) harus truthy');
    expect(info.noPartial, isNull);
  });
}