// lib/features/report/service/report_pdf_service.dart
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/network/api_client.dart';

class ReportPdfService {
  ReportPdfService({
    http.Client? client,
    Map<String, String> Function()? getAuthHeader,
  }) : _client = client ?? http.Client(),
       _getAuthHeader = getAuthHeader;

  final http.Client _client;
  final Map<String, String> Function()? _getAuthHeader;

  /// Batas waktu download PDF. Default 30 detik; laporan yang render-nya
  /// lama di server bisa meng-oper [timeout] sendiri (lihat
  /// [ReportListViewModel.generateReport]).
  static const Duration _defaultTimeout = Duration(seconds: 30);

  Future<void> downloadSaveAndOpenPdf({
    required Uri uri,
    required String filename,
    Duration? timeout,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/pdf',
      if (_getAuthHeader != null) ..._getAuthHeader!(),
    };

    final resp = await _client
        .get(uri, headers: headers)
        .timeout(
          timeout ?? _defaultTimeout,
          onTimeout: () => throw ApiException.timeout(
            timeout ?? _defaultTimeout,
            what: 'Download PDF',
          ),
        );

    final ct = resp.headers['content-type'] ?? '';
    if (resp.statusCode != 200) {
      final preview = resp.body.length > 300
          ? resp.body.substring(0, 300)
          : resp.body;
      throw Exception('HTTP ${resp.statusCode}\n$preview');
    }

    final bytes = resp.bodyBytes;
    if (bytes.isEmpty) throw Exception('PDF kosong (bytes=0)');

    // Validasi cepat PDF signature
    final head = String.fromCharCodes(bytes.take(4));
    if (head != '%PDF') {
      throw Exception('Data bukan PDF valid. Head="$head". content-type="$ct"');
    }

    final file = await _saveTemp(bytes: bytes, filename: filename);

    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      throw Exception('Open file gagal: ${result.message}');
    }
  }

  /// Hanya download dan kembalikan bytes — tanpa simpan/buka.
  Future<Uint8List> downloadPdfBytes({
    required Uri uri,
    Duration? timeout,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/pdf',
      if (_getAuthHeader != null) ..._getAuthHeader(),
    };

    final limit = timeout ?? _defaultTimeout;
    final resp = await _client
        .get(uri, headers: headers)
        .timeout(
          limit,
          onTimeout: () =>
              throw ApiException.timeout(limit, what: 'Download PDF'),
        );

    final ct = resp.headers['content-type'] ?? '';
    if (resp.statusCode != 200) {
      final preview = resp.body.length > 300
          ? resp.body.substring(0, 300)
          : resp.body;
      throw Exception('HTTP ${resp.statusCode}\n$preview');
    }

    final bytes = resp.bodyBytes;
    if (bytes.isEmpty) throw Exception('PDF kosong (bytes=0)');

    final head = String.fromCharCodes(bytes.take(4));
    if (head != '%PDF') {
      throw Exception('Data bukan PDF valid. Head="$head". content-type="$ct"');
    }

    return bytes;
  }

  /// Simpan bytes ke temp lalu buka dengan PDF viewer.
  Future<void> saveAndOpen({
    required Uint8List bytes,
    required String filename,
  }) async {
    final file = await _saveTemp(bytes: bytes, filename: filename);
    final result = await OpenFilex.open(file.path, type: 'application/pdf');
    if (result.type != ResultType.done) {
      throw Exception('Open file gagal: ${result.message}');
    }
  }

  Future<File> _saveTemp({
    required Uint8List bytes,
    required String filename,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }
}
