import 'dart:typed_data';

import 'bt_escpos_printer.dart';
import 'network_tspl_printer.dart';
import 'printer_target.dart';

typedef PrintStatus = void Function(String message);
typedef PrintError = void Function(String error);

/// Abstraksi "kirim satu dokumen PDF label ke sebuah printer fisik".
///
/// Memisahkan *transport + bahasa printer* (Bluetooth/ESC/POS vs jaringan/TSPL)
/// dari kode pemanggil (`PdfPrintService`), sehingga alur preview + pilih printer
/// tidak perlu tahu jenis koneksinya.
abstract class LabelPrinter {
  /// Cetak [pdfBytes] (satu label / satu dokumen multi-halaman).
  /// Return `true` jika berhasil terkirim ke printer.
  Future<bool> printPdf(
    Uint8List pdfBytes, {
    PrintStatus? onStatus,
    PrintError? onError,
  });

  /// Pilih implementasi cetak sesuai jenis [target].
  static LabelPrinter forTarget(PrinterTarget target) => switch (target) {
    BtPrinterTarget t => BtEscPosPrinter(t),
    NetworkPrinterTarget t => NetworkTsplPrinter(t),
  };
}
