import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/features/stock_opname_v2/model/so_v2_kategori.dart';
import 'package:pps_tablet/features/stock_opname_v2/model/so_v2_riwayat_sesi.dart';

/// Payload ini hasil NYATA dari
/// `stockOpnameV2Service.getAllStockOpnameRiwayat({page:1, pageSize:3})`
/// terhadap DB dev `PPS_TEST6` (17 sesi). Disalin supaya parser di sisi app
/// ikut ter-cover kalau bentuk JSON server berubah.
const String _payloadAsli = '''
{
  "data": [
    {
      "stockOpnameNo": "SO.0000000018",
      "categoryId": 9,
      "categoryCode": "barangjadi",
      "categoryName": "Barang Jadi",
      "status": "in_progress",
      "labelCount": 13631,
      "scannedCount": 0,
      "startDate": "2026-09-29T00:00:00.000Z",
      "completedAt": null
    },
    {
      "stockOpnameNo": "SO.0000000017",
      "categoryId": 4,
      "categoryCode": "crusher",
      "categoryName": "Crusher",
      "status": "in_progress",
      "labelCount": 85,
      "scannedCount": 0,
      "startDate": "2026-09-15T00:00:00.000Z",
      "completedAt": null
    },
    {
      "stockOpnameNo": "SO.0000000016",
      "categoryId": 4,
      "categoryCode": "crusher",
      "categoryName": "Crusher",
      "status": "completed",
      "labelCount": 85,
      "scannedCount": 0,
      "startDate": "2026-09-15T00:00:00.000Z",
      "completedAt": "2026-09-15T10:56:29.007Z"
    }
  ],
  "currentPage": 1,
  "pageSize": 3,
  "totalRecords": 17,
  "totalPages": 6
}
''';

void main() {
  test('payload asli dari backend ter-parse tanpa error', () {
    final page = SoV2RiwayatPage.fromJson(
      json.decode(_payloadAsli) as Map<String, dynamic>,
    );

    expect(page.totalRecords, 17);
    expect(page.totalPages, 6);
    expect(page.currentPage, 1);
    expect(page.pageSize, 3);
    expect(page.data, hasLength(3));

    final first = page.data.first;
    expect(first.stockOpnameNo, 'SO.0000000018');
    expect(first.categoryName, 'Barang Jadi');
    expect(first.categoryId, 9);
    expect(first.labelCount, 13631);
    expect(first.status, SoV2Status.inProgress);
    expect(first.startDate, isNotNull);
    expect(first.completedAt, isNull);

    final last = page.data.last;
    expect(last.status, SoV2Status.completed);
    expect(last.completedAt, isNotNull);
    expect(last.progress, 0);
  });

  test('payload dengan field hilang sebagian tetap aman', () {
    final page = SoV2RiwayatPage.fromJson({
      'data': [
        {'stockOpnameNo': 'SO.1'},
      ],
      'totalRecords': 1,
    });

    expect(page.data.single.categoryId, 0);
    expect(page.data.single.status, SoV2Status.notStarted);
    expect(page.data.single.labelCount, 0);
    expect(page.currentPage, 1);
    expect(page.pageSize, 20);
    expect(page.data.single.progress, 0);
  });
}
