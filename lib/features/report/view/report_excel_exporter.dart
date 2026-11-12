// lib/features/report/view/report_excel_exporter.dart
import 'dart:io';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../view_model/report_table_view_model.dart';

/// Bangun bytes workbook .xlsx dari kolom & baris tabel laporan.
/// Pure function — bisa di-test tanpa filesystem.
List<int> buildReportWorkbookBytes({
  required String title,
  required List<ReportTableColumn> columns,
  required List<Map<String, dynamic>> rows,
}) {
  final excel = Excel.createExcel();

  final safeSheetName = title
      .replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
  final sheetName =
      safeSheetName.length <= 31 ? safeSheetName : safeSheetName.substring(0, 31);
  if (sheetName.isNotEmpty && sheetName != 'Sheet1') {
    excel.rename('Sheet1', sheetName);
  }
  final sheet = excel[sheetName.isEmpty ? 'Sheet1' : sheetName];

  final headerStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
  );
  final titleStyle = CellStyle(bold: true, fontSize: 14);
  final metaStyle = CellStyle(italic: true, fontColorHex: ExcelColor.grey);

  sheet.appendRow([TextCellValue(title)]);
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle =
      titleStyle;
  sheet.appendRow([
    TextCellValue('Dibuat: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
  ]);
  sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle =
      metaStyle;
  sheet.appendRow([TextCellValue('')]);

  sheet.appendRow([for (final c in columns) TextCellValue(c.label)]);
  final headerRowIndex = 3;
  for (var i = 0; i < columns.length; i++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRowIndex))
        .cellStyle = headerStyle;
  }

  for (final row in rows) {
    sheet.appendRow([for (final c in columns) _cellValue(row[c.key])]);
  }

  for (var i = 0; i < columns.length; i++) {
    final labelLength = columns[i].label.length;
    final longest = rows.fold<int>(labelLength, (max, row) {
      final v = row[columns[i].key];
      return v == null ? max : (v.toString().length > max ? v.toString().length : max);
    });
    sheet.setColumnWidth(i, (longest + 2).clamp(10, 60).toDouble());
  }

  final bytes = excel.encode();
  if (bytes == null) {
    throw StateError('Gagal membangun file Excel.');
  }
  return bytes;
}

CellValue _cellValue(dynamic value) {
  if (value == null) return TextCellValue('');
  if (value is bool) return BoolCellValue(value);
  if (value is int) return IntCellValue(value);
  if (value is double) return DoubleCellValue(value);
  if (value is num) {
    return value % 1 == 0
        ? IntCellValue(value.toInt())
        : DoubleCellValue(value.toDouble());
  }
  return TextCellValue(value.toString());
}

/// Export tabel laporan ke file .xlsx di dokumen aplikasi, lalu kembalikan File-nya.
Future<File> exportReportToExcel({
  required String title,
  required List<ReportTableColumn> columns,
  required List<Map<String, dynamic>> rows,
}) async {
  final bytes = buildReportWorkbookBytes(
    title: title,
    columns: columns,
    rows: rows,
  );
  final directory = await getApplicationDocumentsDirectory();
  final safeTitle = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
  final file = File('${directory.path}/${safeTitle.isEmpty ? 'laporan' : safeTitle}_$stamp.xlsx');
  await file.writeAsBytes(bytes, flush: true);
  return file;
}
