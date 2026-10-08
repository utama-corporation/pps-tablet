import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/features/production/inject/widgets/inject_split_time_dialog_v3.dart';

void main() {
  // Shift 3: 01 Sep 23:00 - 02 Sep 07:00 (melewati tengah malam).
  final shift3Start = DateTime(2026, 9, 1, 23, 0);
  final shift3End = DateTime(2026, 9, 2, 7, 0);
  final tglProduksi = DateTime(2026, 9, 1);

  DateTime? resolve(String hhmm, {DateTime? start, DateTime? end}) {
    return resolveSplitDateTime(
      hhmm: hhmm,
      windowStart: start ?? shift3Start,
      windowEnd: end ?? shift3End,
      fallbackDate: tglProduksi,
    );
  }

  group('resolveSplitDateTime', () {
    test('sebelum tengah malam tetap di tanggal tglProduksi', () {
      expect(resolve('23:30'), DateTime(2026, 9, 1, 23, 30));
    });

    test('jam setelah tengah malam jatuh ke tanggal berikutnya', () {
      expect(resolve('00:30'), DateTime(2026, 9, 2, 0, 30));
      expect(resolve('03:15'), DateTime(2026, 9, 2, 3, 15));
    });

    test('jam tepat di ujung shift tetap di tanggal berikutnya', () {
      expect(resolve('07:00'), DateTime(2026, 9, 2, 7, 0));
    });

    test('jam di luar window shift tetap dihitung, tidak digeser diam-diam', () {
      // 22:00 tidak ada dalam shift 3 (23:00-07:00) -> jadi 02 Sep 22:00,
      // yaitu di luar window; pemanggil yang harus menolak.
      expect(resolve('22:00'), DateTime(2026, 9, 2, 22, 0));
    });

    test('window tanpa rollover (shift 1 07:00-15:00) tidak geser tanggal', () {
      expect(
        resolve('14:00',
            start: DateTime(2026, 9, 1, 7, 0), end: DateTime(2026, 9, 1, 15, 0)),
        DateTime(2026, 9, 1, 14, 0),
      );
    });

    test('window yang sudah bergeser (bucket anchor di tanggal 2) tetap benar', () {
      //.Split hanya boleh dari bucket 02 Sep 00:00, tapi jam 23:00 masih
      // harus dipetakan ke 02 Sep 23:00 (di luar window, ditolak pemanggil).
      final anchor = DateTime(2026, 9, 2, 0, 0);
      expect(resolve('00:30', start: anchor), DateTime(2026, 9, 2, 0, 30));
      expect(resolve('23:00', start: anchor), DateTime(2026, 9, 2, 23, 0));
    });

    test('format jam tidak valid ditolak', () {
      expect(resolve(''), isNull);
      expect(resolve('abc'), isNull);
      expect(resolve('25:00'), isNull);
      expect(resolve('10:70'), isNull);
      expect(resolve('10'), isNull);
    });

    test('tanpa window, jatuh ke tanggal tglProduksi', () {
      expect(
        resolveSplitDateTime(
          hhmm: '00:30',
          windowStart: tglProduksi,
          windowEnd: null,
          fallbackDate: tglProduksi,
        ),
        DateTime(2026, 9, 1, 0, 30),
      );
    });
  });
}
