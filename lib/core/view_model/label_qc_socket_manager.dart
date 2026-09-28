import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../network/endpoints.dart';

/// Jenis label yang mendukung QC realtime.
class LabelQcKind {
  static const washing = 'washing';
  static const broker = 'broker';

  static String? normalize(dynamic v) {
    final s = (v ?? '').toString().trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == washing || s == broker) return s;
    return null;
  }
}

/// Payload event `label_qc_updated` yang dikirim server setiap QC label
/// disimpan dari tablet mana pun.
///
/// Bentuk payload (server):

/// ```json
/// {
///   "kind": "washing" | "broker",
///   "noLabel": "W.000123",
///   "dateQc": "2026-01-15",
///   "density": 0.95, "density2": 0.95, "density3": 0.95,
///   "moisture": 0.4, "moisture2": 0.4, "moisture3": 0.4,
///   "maxMeltTemp": 285, "minMeltTemp": 250, "mfi": 2.1,
///   "visualNote": "aman",
///   "updatedByUsername": "qc01"
/// }
/// ```

///
/// Field QC yang tidak dikirim server (mis. broker tidak punya melt temp)
/// akan null — pemanggil cukup pakai nilainya apa adanya.
class LabelQcUpdatedEvent {
  final String? kind;
  final String noLabel;
  final String? dateQc;
  final double? density;
  final double? density2;
  final double? density3;
  final double? moisture;
  final double? moisture2;
  final double? moisture3;
  final double? maxMeltTemp;
  final double? minMeltTemp;
  final double? mfi;
  final String? visualNote;
  final String? updatedBy;

  const LabelQcUpdatedEvent({
    required this.kind,
    required this.noLabel,
    this.dateQc,
    this.density,
    this.density2,
    this.density3,
    this.moisture,
    this.moisture2,
    this.moisture3,
    this.maxMeltTemp,
    this.minMeltTemp,
    this.mfi,
    this.visualNote,
    this.updatedBy,
  });

  factory LabelQcUpdatedEvent.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      final s = v.toString().trim().replaceAll(',', '.');
      if (s.isEmpty || s == 'null') return null;
      return double.tryParse(s);
    }

    String? asString(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s.toLowerCase() == 'null') return null;
      return s;
    }

    return LabelQcUpdatedEvent(
      kind: LabelQcKind.normalize(
        json['kind'] ?? json['jenis'] ?? json['type'],
      ),
      noLabel: (json['noLabel'] ?? json['nomorLabel'] ?? '').toString().trim(),
      dateQc: asString(json['dateQc'] ?? json['DateQc']),
      density: asDouble(json['density'] ?? json['Density']),
      density2: asDouble(json['density2'] ?? json['Density2']),
      density3: asDouble(json['density3'] ?? json['Density3']),
      moisture: asDouble(json['moisture'] ?? json['Moisture']),
      moisture2: asDouble(json['moisture2'] ?? json['Moisture2']),
      moisture3: asDouble(json['moisture3'] ?? json['Moisture3']),
      maxMeltTemp: asDouble(json['maxMeltTemp'] ?? json['MaxMeltTemp']),
      minMeltTemp: asDouble(json['minMeltTemp'] ?? json['MinMeltTemp']),
      mfi: asDouble(json['mfi'] ?? json['MFI']),
      visualNote: asString(json['visualNote'] ?? json['VisualNote']),
      updatedBy: asString(
        json['updatedByUsername'] ?? json['updatedBy'] ?? json['qcBy'],
      ),
    );
  }
}

/// Socket.IO client global untuk sinkronisasi QC label washing & broker —
/// connect sekali per sesi app (didaftarkan di main.dart). Broadcast, jadi
/// tidak perlu join/leave room seperti Stock Opname v2.
class LabelQcSocketManager extends ChangeNotifier
    with WidgetsBindingObserver {
  io.Socket? _socket;
  bool _isInitialized = false;
  final List<void Function(LabelQcUpdatedEvent)> _listeners = [];

  bool get isConnected => _socket?.connected ?? false;

  void connect() {
    if (_isInitialized && _socket != null) return;
    WidgetsBinding.instance.addObserver(this);

    final fallback = ApiConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    final baseUrl = ApiConstants.socketBaseUrl.trim().isNotEmpty
        ? ApiConstants.socketBaseUrl
        : fallback;

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1200)
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) => notifyListeners());
    _socket!.onDisconnect((_) => notifyListeners());
    _socket!.onConnectError((_) => notifyListeners());

    _socket!.on('label_qc_updated', (data) {
      if (data is! Map) return;
      final event = LabelQcUpdatedEvent.fromJson(data.cast<String, dynamic>());
      if (event.kind == null || event.noLabel.isEmpty) return;
      for (final listener in List.of(_listeners)) {
        listener(event);
      }
    });

    _isInitialized = true;
    _socket!.connect();
  }

  /// Daftarkan callback untuk event `label_qc_updated`. Panggil hasil
  /// (unsubscribe function) saat screen dispose.
  VoidCallback addQcUpdatedListener(
    void Function(LabelQcUpdatedEvent event) listener,
  ) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_socket == null || !_socket!.connected) {
        _socket?.connect();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
    _listeners.clear();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    super.dispose();
  }
}
