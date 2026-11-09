// test/berat_compare_test.dart
//
// Regresi: validasi berat dialog harus tahan terhadap residu
// floating-point dari berat sisa hasil hitung backend.
// Skenario nyata: label 20kg, partial 17.28 → sisa dihitung backend
// 20 - 17.28 = 2.7199999999999989. Input "2.72" yang di-parse Dart
// menjadi 2.7200000000000002 dan TIDAK BOLEH dianggap melebihi sisa.

import 'package:flutter_test/flutter_test.dart';

import 'package:pps_tablet/features/production/shared/utils/format.dart';

void main() {
  test('residu sisa 20 - 17.28 tidak melempar input 2.72 jadi over', () {
    final sisaResidu = 20.0 - 17.28; // 2.7199999999999989
    final inputDiketik = double.parse('2.72'); // 2.7200000000000002

    // kondisi bug lama: input > sisa → ditolak padahal sama
    expect(inputDiketik > sisaResidu, isTrue,
        reason: 'sanity: tanpa pembulatan memang terjadi false-positive');

    // helper baru: dibulatkan ke presisi timbangan dulu
    expect(beratLebihDari(inputDiketik, sisaResidu), isFalse,
        reason: 'input sisa persis tidak boleh dianggap melebihi');
    expect(beratLebihDari(sisaResidu, inputDiketik), isFalse);

    // masih mendeteksi pelanggaran beneran
    expect(beratLebihDari(2.73, sisaResidu), isTrue);
    expect(beratLebihDari(20.5, 20), isTrue);
    expect(beratLebihDari(0, 20), isFalse);
  });

  test('deteksi partial (kurang dari berat asli) bebas residu', () {
    // input sisa sama dengan berat asli (residu kecil BAIK di satu sisi)
    expect(beratKurangDari(double.parse('2.72'), 20.0 - 17.28), isFalse,
        reason: 'mengambil sisa persis tidak boleh dianggap partial');
    // residu besar arah sebaliknya: berat asli > tampilan
    expect(beratKurangDari(double.parse('17.28'), 17.280000000000001), isFalse,
        reason: 'berat penuh tidak boleh dianggap partial kena residu');
    // partial sungguhan
    expect(beratKurangDari(17.28, 20), isTrue);
  });

  test('round2 membulatkan ke presisi timbangan', () {
    expect(round2(2.7199999999999989), 2.72);
    expect(round2(round2(2.72)), 2.72);
    expect(round2(17.285), 17.29); // toStringAsFixed: half-up float behavior
    expect(round2(0), 0);
  });
}
