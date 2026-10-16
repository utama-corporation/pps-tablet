// lib/core/network/api_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'endpoints.dart';
import '../services/token_storage.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? responseBody;

  /// Pesan yang sudah enak dibaca user, diwujudkan lewat [friendly]. Kalau
  /// null, [apiErrorMessage] jatuh ke pemetaan berdasarkan status code.
  final String? friendly;

  ApiException(
    this.statusCode,
    this.message, {
    this.responseBody,
    this.friendly,
  });

  /// "25 detik" / "10 menit" untuk pesan timeout.
  static String _humanDuration(Duration d) {
    if (d.inMinutes >= 1) {
      final s = d.inSeconds % 60;
      return s == 0 ? '${d.inMinutes} menit' : '${d.inMinutes} menit $s detik';
    }
    return '${d.inSeconds} detik';
  }

  /// Timeout yang sudah dibungkus pesan ramah, untuk operasi yang memang
  /// lama di server (mis. render PDF laporan). Tanpa ini yang tampil ke
  /// operator adalah "TimeoutException after ..." yang tidak berguna.
  ApiException.timeout(Duration limit, {required String what})
    : statusCode = 408,
      message = '$what timeout setelah ${_humanDuration(limit)}',
      responseBody = null,
      friendly =
          '$what belum selesai dalam ${_humanDuration(limit)}. '
          'Coba perkecil rentang tanggal, atau coba lagi beberapa saat lagi.';

  // Pesan ramah untuk ditampilkan ke user — ambil field "message" dari body JSON
  // server jika ada (mis. pesan validasi), fallback ke [message] teknis.
  String get friendlyMessage {
    final f = friendly;
    if (f != null && f.trim().isNotEmpty) return f.trim();

    final body = responseBody;
    if (body == null || body.isEmpty) return message;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {}
    return message;
  }

  /// `error.code` dari body JSON server, kalau ada.
  ///
  /// Beberapa modul backend memakai kode mesin untuk membedakan jenis kegagalan
  /// pada status yang sama — mis. hapus Label Bahan Pendukung membalas 409
  /// dengan `BP_ALREADY_USED` (sudah terpakai penuh) vs `BP_ALREADY_PARTIAL`
  /// (sudah terpakai sebagian). Tanpa getter ini tiap modul harus parse
  /// [responseBody] sendiri.
  String? get errorCode {
    final body = responseBody;
    if (body == null || body.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final err = decoded['error'];
      if (err is Map && err['code'] != null) return err['code'].toString();
      if (err is String && err.trim().isNotEmpty) return err.trim();
      if (decoded['code'] != null) return decoded['code'].toString();
    } catch (_) {}
    return null;
  }

  @override
  String toString() =>
      'ApiException($statusCode): $message ${responseBody ?? ''}';
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 25);

  String get _base => ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');

  /// Build URL from path + query
  Uri _buildUri(String path, [Map<String, dynamic>? query]) {
    final base = _base;
    final cleanPath = path.startsWith('/') ? path : '/$path';

    return Uri.parse('$base$cleanPath').replace(
      queryParameters: query?.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    );
  }

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final url = _buildUri(path, query);
    final headers = await _headers();

    print('➡️ [$method] $url');
    if (body != null) {
      print('📦 Body: $body');
    }

    late http.Response resp;
    final started = DateTime.now();

    try {
      switch (method) {
        case 'GET':
          resp = await _client.get(url, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          resp = await _client
              .post(url, headers: headers, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'PUT':
          resp = await _client
              .put(url, headers: headers, body: json.encode(body))
              .timeout(_timeout);
          break;
        case 'DELETE':
          resp = await _client
              .delete(
                url,
                headers: headers,
                body: body != null ? json.encode(body) : null,
              )
              .timeout(_timeout);
          break;
        default:
          throw ArgumentError('HTTP method not supported: $method');
      }
    } on TimeoutException {
      throw ApiException(408, 'Request timeout: $method $url');
    } catch (e) {
      print('❌ [$method] $url error: $e');
      rethrow;
    }

    print(
      '⬅️ [${resp.statusCode}] in '
      '${DateTime.now().difference(started).inMilliseconds}ms',
    );
    if (resp.body.isNotEmpty) {
      print('📨 Body: ${resp.body}');
    }

    return resp;
  }

  Map<String, dynamic> _decodeJsonBody(http.Response resp) {
    if (resp.body.isEmpty) return <String, dynamic>{};

    final decoded = utf8.decode(resp.bodyBytes);
    final dynamic jsonBody = json.decode(decoded);

    if (jsonBody is Map<String, dynamic>) return jsonBody;

    // Kalau API kadang balikin list, bungkus jadi map
    return {'data': jsonBody};
  }

  // ---------------------------
  // Public helpers
  // ---------------------------

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    final resp = await _send('GET', path, query: query);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        resp.statusCode,
        'GET $path failed',
        responseBody: resp.body,
      );
    }

    return _decodeJsonBody(resp);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final resp = await _send('POST', path, query: query, body: body);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        resp.statusCode,
        'POST $path failed',
        responseBody: resp.body,
      );
    }

    return _decodeJsonBody(resp);
  }

  Future<Map<String, dynamic>> putJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final resp = await _send('PUT', path, query: query, body: body);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        resp.statusCode,
        'PUT $path failed',
        responseBody: resp.body,
      );
    }

    return _decodeJsonBody(resp);
  }

  Future<Map<String, dynamic>> patchJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final url = _buildUri(path, query);
    final headers = await _headers();

    print('➡️ [PATCH] $url');
    if (body != null) print('📦 Body: $body');

    final resp = await _client
        .patch(
          url,
          headers: headers,
          body: body != null ? json.encode(body) : null,
        )
        .timeout(_timeout);

    print('⬅️ [${resp.statusCode}]');

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        resp.statusCode,
        'PATCH $path failed',
        responseBody: resp.body,
      );
    }

    if (resp.statusCode == 204 || resp.body.isEmpty) {
      return <String, dynamic>{};
    }

    return _decodeJsonBody(resp);
  }

  /// Sama seperti [getPdfBytes], tapi menerima path relatif (di-resolve
  /// lewat [_buildUri]) alih-alih [Uri] absolut yang harus dirakit caller.
  Future<Uint8List> getPdfBytesForPath(
    String path, {
    Map<String, dynamic>? query,
    Duration? timeout,
  }) {
    return getPdfBytes(_buildUri(path, query), timeout: timeout);
  }

  /// Download PDF dengan auth header. Validasi signature %PDF.
  ///
  /// [timeout]_override untuk laporan yang render-nya lama di server (mis.
  /// 10 menit di [ReportListViewModel.generateReport]). Default-nya tetap
  /// [_timeout] supaya request lain tidak ikut melonggar.
  Future<Uint8List> getPdfBytes(Uri uri, {Duration? timeout}) async {
    final limit = timeout ?? _timeout;
    final headers = await _headers();
    final pdfHeaders = Map<String, String>.from(headers)
      ..['Accept'] = 'application/pdf'
      ..remove('Content-Type');

    // PDF laporan dirender di server dan tidak streaming, jadi timeout di sini
    // normal terjadi saat server lambat - bukan hanya saat server mati.
    // Bungkus jadi ApiException(408) supaya apiErrorMessage() menampilkan
    // pesan yang jelas, bukan "TimeoutException after ..." mentah.
    final resp = await _client
        .get(uri, headers: pdfHeaders)
        .timeout(
          limit,
          onTimeout: () {
            throw ApiException.timeout(limit, what: 'Download PDF');
          },
        );

    if (resp.statusCode != 200) {
      final preview = resp.body.length > 300
          ? resp.body.substring(0, 300)
          : resp.body;
      throw ApiException(
        resp.statusCode,
        'PDF download failed',
        responseBody: preview,
      );
    }

    final bytes = resp.bodyBytes;
    if (bytes.isEmpty) throw ApiException(0, 'PDF kosong (bytes=0)');

    final head = String.fromCharCodes(bytes.take(4));
    if (head != '%PDF') {
      throw ApiException(0, 'Data bukan PDF valid. Head="$head"');
    }

    return bytes;
  }

  /// Delete yang mungkin mengembalikan body (200) atau tidak (204).
  Future<Map<String, dynamic>> deleteJson(
    String path, {
    Map<String, dynamic>? query,
    Object? body,
  }) async {
    final resp = await _send('DELETE', path, query: query, body: body);

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(
        resp.statusCode,
        'DELETE $path failed',
        responseBody: resp.body,
      );
    }

    // 204 No Content
    if (resp.statusCode == 204 || resp.body.isEmpty) {
      return <String, dynamic>{};
    }

    return _decodeJsonBody(resp);
  }
}
