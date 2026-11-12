import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/features/report/view/report_excel_exporter.dart';
import 'package:pps_tablet/features/report/view_model/report_table_view_model.dart';

void main() {
  const columns = [
    ReportTableColumn(key: 'kode', label: 'Kode', numeric: false),
    ReportTableColumn(key: 'qty', label: 'Qty', numeric: true),
  ];

  test('buildReportWorkbookBytes produces valid xlsx with header and rows', () {
    final bytes = buildReportWorkbookBytes(
      title: 'Mutasi Washing',
      columns: columns,
      rows: [
        {'kode': 'A', 'qty': 3},
        {'kode': 'B', 'qty': 2.5},
        {'kode': null, 'qty': null},
      ],
    );

    expect(bytes.length, greaterThan(100));
    expect(bytes.take(2).toList(), [0x50, 0x4B]);

    final excel = Excel.decodeBytes(bytes);
    final sheet = excel['Mutasi Washing'];
    final rows = sheet.rows;

    String? text(int row, int col) =>
        (rows[row][col]?.value as TextCellValue?)?.value.toString();

    expect(text(0, 0), 'Mutasi Washing');
    expect(text(3, 0), 'Kode');
    expect(text(3, 1), 'Qty');
    expect(text(4, 0), 'A');
    expect((rows[4][1]?.value as IntCellValue?)?.value, 3);
    expect(text(5, 0), 'B');
    expect((rows[5][1]?.value as DoubleCellValue?)?.value, 2.5);
    expect(text(6, 0), '');
    expect(text(6, 1), '');
  });

  test('sheet name is sanitized and truncated to 31 chars', () {
    final bytes = buildReportWorkbookBytes(
      title: 'L${'a' * 40}:/\\[]*?',
      columns: columns,
      rows: const [],
    );
    final excel = Excel.decodeBytes(bytes);
    expect(excel.tables.keys.single.length, lessThanOrEqualTo(31));
    expect(excel.tables.keys.single, isNot(contains(RegExp(r'[\[\]:*?/\\]'))));
  });
}
