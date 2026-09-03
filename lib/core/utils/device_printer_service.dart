import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/endpoints.dart';
import '../printing/printer_target.dart';
import '../services/token_storage.dart';
import '../services/user_session_storage.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

/// Parameter printer jaringan (TSPL / TCP 9100) dari device-service.
class DevicePrinterNetwork {
  final String ipAddress;
  final int port;
  final double labelWidthMm;
  final double labelHeightMm;

  const DevicePrinterNetwork({
    required this.ipAddress,
    required this.port,
    required this.labelWidthMm,
    required this.labelHeightMm,
  });

  factory DevicePrinterNetwork.fromJson(Map<String, dynamic> json) {
    return DevicePrinterNetwork(
      ipAddress: json['ipAddress']?.toString() ?? '',
      port: (json['port'] as num?)?.toInt() ?? 9100,
      labelWidthMm: (json['labelWidthMm'] as num?)?.toDouble() ?? 100,
      labelHeightMm: (json['labelHeightMm'] as num?)?.toDouble() ?? 150,
    );
  }
}

class DevicePrinter {
  final String id;
  final String identifier; // MAC address (BT) atau IP address (jaringan)
  final String name;
  final String connectionType; // 'BLUETOOTH' | 'NETWORK'
  final DevicePrinterNetwork? network;

  /// Status ICMP dari poller microservice (printer jaringan). null = belum dicek
  /// atau bukan printer jaringan.
  final bool? online;
  final int? latencyMs;

  final String printUsage;
  final String? lastUsedAt;
  final String status;

  const DevicePrinter({
    required this.id,
    required this.identifier,
    required this.name,
    this.connectionType = 'BLUETOOTH',
    this.network,
    this.online,
    this.latencyMs,
    required this.printUsage,
    this.lastUsedAt,
    required this.status,
  });

  static final _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

  /// Anggap NETWORK bila server bilang begitu, ada objek [network], atau
  /// identifier berbentuk IPv4 (jaga-jaga backend lama tanpa connectionType).
  bool get isNetwork =>
      connectionType == 'NETWORK' ||
      network != null ||
      _ipv4.hasMatch(identifier);

  factory DevicePrinter.fromJson(Map<String, dynamic> json) {
    final net = json['network'];
    return DevicePrinter(
      id: json['id']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      connectionType: json['connectionType']?.toString() ?? 'BLUETOOTH',
      network: net is Map<String, dynamic>
          ? DevicePrinterNetwork.fromJson(net)
          : (net is Map
                ? DevicePrinterNetwork.fromJson(Map<String, dynamic>.from(net))
                : null),
      online: json['online'] is bool ? json['online'] as bool : null,
      latencyMs: (json['latencyMs'] as num?)?.toInt(),
      printUsage: json['printUsage']?.toString() ?? '0/0',
      lastUsedAt: json['lastUsedAt']?.toString(),
      status: json['status']?.toString() ?? 'NORMAL',
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Service untuk berinteraksi dengan microservice printer
/// di endpoint [ApiConstants.deviceApiUrl].
class DevicePrinterService {
  DevicePrinterService._();

  static String get _base =>
      ApiConstants.deviceApiUrl.replaceFirst(RegExp(r'/*$'), '');

  static Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // ── List printers ──────────────────────────────────────────────────────────

  /// GET /api/devices/printers
  /// Returns list printer yang terdaftar di microservice.
  static Future<List<DevicePrinter>> fetchPrinters() async {
    final uri = Uri.parse('$_base/api/devices/printers');
    final resp = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      throw Exception('Gagal mengambil daftar printer (${resp.statusCode})');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final list = (body['printers'] as List<dynamic>? ?? []);
    return list
        .map((e) => DevicePrinter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Get single printer ─────────────────────────────────────────────────────

  /// GET /api/devices/printers/{id}
  /// Ambil detail printer + status + printUsage terkini.
  static Future<DevicePrinter> getPrinter(String id) async {
    final uri = Uri.parse('$_base/api/devices/printers/$id');
    final resp = await http
        .get(uri, headers: await _headers())
        .timeout(const Duration(seconds: 10));

    if (resp.statusCode != 200) {
      throw Exception('Gagal mengambil info printer (${resp.statusCode})');
    }

    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    return DevicePrinter.fromJson(body);
  }

  // ── Register printer ───────────────────────────────────────────────────────

  /// POST /api/devices/printers
  /// Daftarkan printer baru berdasarkan MAC address.
  static Future<DevicePrinter> registerPrinter({
    required String mac,
    required String name,
  }) async {
    final uri = Uri.parse('$_base/api/devices/printers');
    final resp = await http
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({'mac': mac, 'name': name}),
        )
        .timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200 && resp.statusCode != 201) {
      String detail = '';
      try {
        final b = jsonDecode(resp.body) as Map<String, dynamic>;
        detail = b['message']?.toString() ?? '';
      } catch (_) {}
      throw Exception(
        'Gagal mendaftarkan printer (${resp.statusCode})${detail.isNotEmpty ? ': $detail' : ''}',
      );
    }

    return _parsePrinter(resp.body);
  }

  // ── Register / update printer JARINGAN ────────────────────────────────────

  /// POST /api/devices/printers — daftar printer jaringan (identifier = IP).
  static Future<DevicePrinter> registerNetworkPrinter({
    required String ipAddress,
    required String name,
    int port = 9100,
    double labelWidthMm = 100,
    double labelHeightMm = 150,
  }) async {
    final uri = Uri.parse('$_base/api/devices/printers');
    final resp = await http
        .post(
          uri,
          headers: await _headers(),
          body: jsonEncode({
            'connectionType': 'NETWORK',
            'ipAddress': ipAddress,
            'port': port,
            'name': name,
            'labelWidthMm': labelWidthMm,
            'labelHeightMm': labelHeightMm,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfBad(resp, 'Gagal mendaftarkan printer jaringan');
    return _parsePrinter(resp.body);
  }

  /// PATCH /api/devices/printers/{id} — ubah nama / IP / port / ukuran label.
  static Future<DevicePrinter> updateNetworkPrinter({
    required String id,
    String? name,
    String? ipAddress,
    int? port,
    double? labelWidthMm,
    double? labelHeightMm,
  }) async {
    final uri = Uri.parse('$_base/api/devices/printers/$id');
    final resp = await http
        .patch(
          uri,
          headers: await _headers(),
          body: jsonEncode({
            if (name != null) 'name': name,
            if (ipAddress != null) 'ipAddress': ipAddress,
            if (port != null) 'port': port,
            if (labelWidthMm != null) 'labelWidthMm': labelWidthMm,
            if (labelHeightMm != null) 'labelHeightMm': labelHeightMm,
          }),
        )
        .timeout(const Duration(seconds: 15));
    _throwIfBad(resp, 'Gagal mengubah printer jaringan');
    return _parsePrinter(resp.body);
  }

  /// DELETE /api/devices/printers/{id}
  static Future<void> deletePrinter(String id) async {
    final uri = Uri.parse('$_base/api/devices/printers/$id');
    final resp = await http
        .delete(uri, headers: await _headers())
        .timeout(const Duration(seconds: 15));
    _throwIfBad(resp, 'Gagal menghapus printer');
  }

  /// POST /api/devices/printers/relay?ip=IP
  /// Kirim payload TSPL mentah ke device-service; device-service yang meneruskan
  /// ke printer jaringan lewat TCP (tablet tidak lagi socket langsung ke :9100).
  /// Melempar Exception dengan pesan jelas kalau gagal.
  static Future<void> relayNetworkPrint({
    required String ipAddress,
    required List<int> bytes,
  }) async {
    final token = await TokenStorage.getToken();
    final uri = Uri.parse(
      '$_base/api/devices/printers/relay'
      '?ip=${Uri.encodeQueryComponent(ipAddress)}',
    );

    debugPrint('➡️ [RELAY-PRINT] POST $uri — ${bytes.length} bytes TSPL');
    final sw = Stopwatch()..start();

    http.Response resp;
    try {
      resp = await http
          .post(
            uri,
            headers: {
              if (token != null && token.isNotEmpty)
                'Authorization': 'Bearer $token',
              'Content-Type': 'application/octet-stream',
            },
            body: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      debugPrint('⬅️ [RELAY-PRINT] gagal (${sw.elapsedMilliseconds}ms): $e');
      rethrow;
    }

    final body = resp.body.length > 300
        ? '${resp.body.substring(0, 300)}…'
        : resp.body;
    debugPrint(
      '⬅️ [RELAY-PRINT] ${resp.statusCode} in ${sw.elapsedMilliseconds}ms — $body',
    );

    _throwIfBad(resp, 'Gagal mengirim job cetak ke server (relay)');
  }

  /// GET /api/devices/printers/network/status
  /// Microservice melakukan TCP probe ke tiap printer NETWORK (port cetak).
  /// Return: { printerId → online(bool) }. Map kosong kalau gagal.
  static Future<Map<String, bool>> pingNetworkPrinters() async {
    try {
      final uri = Uri.parse('$_base/api/devices/printers/network/status');
      final resp = await http
          .get(uri, headers: await _headers())
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200) return {};
      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (body['printers'] as List<dynamic>? ?? []);
      return {
        for (final p in list) (p['id']?.toString() ?? ''): p['online'] == true,
      };
    } catch (e) {
      debugPrint('⚠️ pingNetworkPrinters gagal: $e');
      return {};
    }
  }

  static void _throwIfBad(http.Response resp, String prefix) {
    if (resp.statusCode == 200 || resp.statusCode == 201) return;
    String detail = '';
    try {
      final b = jsonDecode(resp.body) as Map<String, dynamic>;
      detail = (b['message'] ?? b['error'])?.toString() ?? '';
    } catch (_) {}
    throw Exception(
      '$prefix (${resp.statusCode})${detail.isNotEmpty ? ': $detail' : ''}',
    );
  }

  static DevicePrinter _parsePrinter(String rawBody) {
    final body = jsonDecode(rawBody) as Map<String, dynamic>;
    final obj = body['device'] is Map
        ? body['device']
        : (body['data'] is Map ? body['data'] : body);
    return DevicePrinter.fromJson(Map<String, dynamic>.from(obj as Map));
  }

  // ── Log print ──────────────────────────────────────────────────────────────

  /// POST /api/devices/printers/log
  /// Catat aktivitas print. [printerId] = MAC address printer.
  static Future<void> logPrint({
    required String printerId,
    required String printBy,
  }) async {
    final uri = Uri.parse('$_base/api/devices/printers/log');
    try {
      final resp = await http
          .post(
            uri,
            headers: await _headers(),
            body: jsonEncode({
              'printerId': printerId,
              'sourceApp': 'PPS',
              'printBy': printBy,
            }),
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('🖨️ Print log: ${resp.statusCode}');
    } catch (e) {
      // log gagal tidak boleh mengganggu flow utama
      debugPrint('⚠️ Gagal kirim print log: $e');
    }
  }

  // ── Save / load default printer ────────────────────────────────────────────

  static const _kDevicePrinterId = 'device_printer_id';
  static const _kDevicePrinterMac = 'device_printer_mac';
  static const _kDevicePrinterName = 'device_printer_name';

  static Future<void> saveDefaultPrinter(DevicePrinter printer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDevicePrinterId, printer.id);
    await prefs.setString(_kDevicePrinterMac, printer.identifier);
    await prefs.setString(_kDevicePrinterName, printer.name);
    debugPrint(
      '💾 Default printer disimpan: ${printer.name} (${printer.identifier})',
    );
  }

  static Future<({String id, String mac, String name})?>
  loadDefaultPrinter() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kDevicePrinterId);
    final mac = prefs.getString(_kDevicePrinterMac);
    final name = prefs.getString(_kDevicePrinterName);
    if (id == null || id.isEmpty || mac == null || mac.isEmpty) return null;
    return (id: id, mac: mac, name: name ?? mac);
  }

  // ── Printer default (BT ATAU jaringan) — simpan PrinterTarget lengkap ──────

  static const _kLastTargetJson = 'last_printer_target_v1';
  static const _kLastTargetId = 'last_printer_target_id';
  static const _kLastTargetName = 'last_printer_target_name';

  /// Simpan printer terakhir yang dipilih sebagai default cetak berikutnya.
  /// Menyimpan [PrinterTarget] lengkap → jenis (BT/jaringan) + parameternya
  /// (IP, port, ukuran label) ikut terjaga.
  static Future<void> saveLastTarget(
    PrinterTarget target, {
    String id = '',
    String? name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastTargetJson, target.encode());
    await prefs.setString(_kLastTargetId, id);
    await prefs.setString(_kLastTargetName, name ?? target.name);
    debugPrint(
      '💾 Default printer disimpan: ${name ?? target.name} '
      '(${target.identifier})',
    );
  }

  static Future<({PrinterTarget target, String id, String name})?>
  loadLastTarget() async {
    final prefs = await SharedPreferences.getInstance();
    final target = PrinterTarget.tryDecode(prefs.getString(_kLastTargetJson));
    if (target == null) return null;
    return (
      target: target,
      id: prefs.getString(_kLastTargetId) ?? '',
      name: prefs.getString(_kLastTargetName) ?? target.name,
    );
  }

  static Future<void> clearLastTarget() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastTargetJson);
    await prefs.remove(_kLastTargetId);
    await prefs.remove(_kLastTargetName);
  }

  // ── Get logged-in username ─────────────────────────────────────────────────

  static Future<String> getLoggedUsername() async {
    return UserSessionStorage.getUsername();
  }
}
