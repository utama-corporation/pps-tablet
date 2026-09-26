import 'package:flutter/material.dart';

import '../../common/widgets/master_printer_selector.dart';
import '../utils/bt_print_service.dart';
import '../utils/device_printer_service.dart';
import '../utils/pdf_print_service.dart';
import 'label_printer.dart';
import 'printer_target.dart';

/// Menyatukan pemilihan + pencetakan printer untuk dialog yang mencetak
/// label langsung (tanpa lewat [PdfViewerScreen]).
///
/// Dialog Multiple/Quick lama (`BtAutoPrintDialog`, `AutoRepeatPrintDialog`)
/// hanya menyimpan MAC dan selalu memanggil `BtPrintService`, sehingga saat
/// operator memilih printer **jaringan** IP-nya tetap diteruskan ke
/// `PrintBluetoothThermal.connect(mac: '192.168.x.x')` — Pasti gagal dengan
/// pesan "Gagal terhubung ke printer" yang menyesatkan.
///
/// Mixin ini menyimpan [PrinterTarget] utuh dan mencetak lewat
/// [LabelPrinter.forTarget], sehingga Bluetooth (ESC/POS) dan jaringan (TSPL
/// lewat relay device-service) keduanya bekerja otomatis.
///
/// Nama field sengaja tanpa underscore agar bisa dipakai lintas library.
mixin LabelPrinterTargetMixin<T extends StatefulWidget> on State<T> {
  String? printerId;
  String? printerMac;
  String? printerName;

  /// Target konkret hasil pilihan operator. Null = belum memilih.
  PrinterTarget? printerTarget;

  /// Fallback lama `device_printer_id` hanya berisi MAC, jadi hanya dipakai
  /// kalau memang berbentuk MAC — kalau tidak, diasumsikan IP dan diabaikan
  /// (sudah ditangani [DevicePrinterService.loadLastTarget]).
  static final _macRe = RegExp(r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');

  bool get hasPrinter =>
      printerTarget != null || (printerMac?.isNotEmpty ?? false);

  bool get isNetworkPrinter => printerTarget is NetworkPrinterTarget;

  /// Deskripsi target untuk UI — operator perlu tahu akan cetak ke BT atau LAN.
  String get printerTargetSubtitle => switch (printerTarget) {
    NetworkPrinterTarget t => 'Jaringan · TSPL · ${t.host}:${t.port}',
    BtPrinterTarget t => 'Bluetooth · ESC/POS · ${t.mac}',
    _ => 'Pilih printer',
  };

  /// Muat printer terakhir: [DevicePrinterService.loadLastTarget] (BT + jaringan,
  /// stores PrinterTarget utuh), lalu fallback ke default lama yang MAC-only.
  Future<void> loadTargetPrinter() async {
    final last = await DevicePrinterService.loadLastTarget();
    if (last != null && mounted) {
      setState(() {
        printerTarget = last.target;
        printerId = last.id;
        printerMac = last.target.identifier;
        printerName = last.name;
      });
      return;
    }
    final saved = await DevicePrinterService.loadDefaultPrinter();
    if (saved != null && _macRe.hasMatch(saved.mac) && mounted) {
      setState(() {
        printerId = saved.id;
        printerMac = saved.mac;
        printerName = saved.name;
      });
      return;
    }
    // Store paling lama (dikirim juga oleh MasterPrinterSelector), tetap
    // Bluetooth-only — dipakai agar user lama tidak kehilangan printer.
    final legacy = await BtPrintService.loadSavedPrinter();
    if (legacy != null && _macRe.hasMatch(legacy.mac) && mounted) {
      setState(() {
        printerMac = legacy.mac;
        printerName = legacy.name;
      });
    }
  }

  /// Buka [MasterPrinterSelector]. Return true kalau operator memilih printer.
  ///
  /// Pemilihan juga otomatis disimpan oleh selector itu sendiri
  /// (`saveLastTarget`), jadi tidak perlu persistence tambahan di sini.
  Future<bool> pickTargetPrinter() async {
    final outcome = await MasterPrinterSelector.show(
      context: context,
      currentMac: printerMac,
    );
    if (outcome == null || !mounted) return false;
    setState(() {
      printerId = outcome.id;
      printerMac = outcome.mac;
      printerName = outcome.printerName;
      printerTarget = outcome.target;
    });
    return true;
  }

  /// Cetak satu PDF dari [url] ke printer terpilih.
  ///
  /// Equivalent dengan `BtPrintService.printLabelFromUrl` untuk target
  /// Bluetooth (fetch bytes + `printBytes`), tapi otomatis memakai TSPL relay
  /// bila target-nya printer jaringan.
  ///
  /// Tidak pernah melempar exception — kegagalan dilaporkan lewat [onError] dan
  /// dikembalikan `false`, sama seperti `BtPrintService.printLabelFromUrl`, jadi
  /// pemanggil tidak perlu try/catch dan tidak akan menggantung di state "busy".
  Future<bool> printPdfViaTarget(
    Uri url, {
    PrintStatus? onStatus,
    PrintError? onError,
  }) async {
    // Fallback: printer lama yang tersimpan sebagai MAC saja.
    final target =
        printerTarget ??
        (printerMac != null && _macRe.hasMatch(printerMac!)
            ? BtPrinterTarget(mac: printerMac!, name: printerName ?? '')
            : null);
    if (target == null) {
      onError?.call('Pilih printer terlebih dahulu.');
      return false;
    }

    try {
      onStatus?.call('Mengunduh PDF dari server...');
      final bytes = await PdfPrintService.fetchPdfBytes(url);
      debugPrint(
        '🖨️ [${target.runtimeType}] PDF ${bytes.length} bytes → ${target.identifier}',
      );
      onStatus?.call('Mengirim ke printer...');
      return await LabelPrinter.forTarget(
        target,
      ).printPdf(bytes, onStatus: onStatus, onError: onError);
    } catch (e, st) {
      debugPrint('❌ printPdfViaTarget gagal: $e\n$st');
      onError?.call('$e');
      return false;
    }
  }
}
