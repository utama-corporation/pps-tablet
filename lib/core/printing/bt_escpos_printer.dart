import 'dart:typed_data';

import '../network/endpoints.dart';
import '../utils/bt_print_service.dart';
import 'label_printer.dart';
import 'printer_target.dart';

/// Jalur cetak lama: thermal 80mm via classic Bluetooth, payload ESC/POS.
///
/// Tipis — hanya membungkus [BtPrintService] yang sudah teruji di produksi.
/// Semua logika raster/ESC/POS/koneksi BT tetap di [BtPrintService].
class BtEscPosPrinter implements LabelPrinter {
  BtEscPosPrinter(this.target);

  final BtPrinterTarget target;

  @override
  Future<bool> printPdf(
    Uint8List pdfBytes, {
    PrintStatus? onStatus,
    PrintError? onError,
  }) {
    return BtPrintService(baseUrl: ApiConstants.baseUrl).printBytes(
      pdfBytes: pdfBytes,
      mac: target.mac,
      onStatus: onStatus,
      onError: onError,
    );
  }
}
