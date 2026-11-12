import '../../../core/network/api_errors.dart';

/// Penyebab kegagalan saat submit label ke server.
///
/// Retryable berarti transient — request kemungkinan belum tercatat di
/// server sehingga aman dikirim ulang. Permanent berarti backend sudah
/// menolak dengan alasan bisnis (duplikat, kategori salah, label di luar SO)
/// atau masalah auth, sehingga retry akan gagal dengan hasil yang sama.
enum SoV2FailedReason {
  network,
  server,
  maintenance,
  unknown,
  validation,
  auth;

  bool get isRetryable =>
      this == network || this == server || this == maintenance || this == unknown;

  static SoV2FailedReason fromApiFailure(ApiFailureType type) {
    switch (type) {
      case ApiFailureType.validation:
        return SoV2FailedReason.validation;
      case ApiFailureType.auth:
        return SoV2FailedReason.auth;
      case ApiFailureType.server:
        return SoV2FailedReason.server;
      case ApiFailureType.maintenance:
        return SoV2FailedReason.maintenance;
      case ApiFailureType.network:
        return SoV2FailedReason.network;
      case ApiFailureType.unknown:
        return SoV2FailedReason.unknown;
    }
  }
}

/// Satu label yang gagal dikirim ke server dan disimpan sebagai antrean
/// lokal supaya bisa dikirim ulang tanpa mengulang seluruh sesi scan.
class SoV2FailedScan {
  const SoV2FailedScan({
    required this.stockOpnameNo,
    required this.labelNo,
    required this.blok,
    required this.locationId,
    required this.reason,
    required this.message,
    required this.createdAt,
    required this.lastAttemptAt,
    this.retryCount = 0,
    this.lastRetryMessage,
  });

  final String stockOpnameNo;
  final String labelNo;
  final String blok;
  final int locationId;
  final SoV2FailedReason reason;
  final String message;
  final DateTime createdAt;
  final DateTime lastAttemptAt;
  final int retryCount;
  final String? lastRetryMessage;

  bool get isRetryable => reason.isRetryable;

  /// Kunci unik antrean. Label yang sama di lokasi berbeda tetap menjadi dua
  /// entri terpisah karena memang harus dikirim ke endpoint yang berbeda.
  String get key => '$stockOpnameNo#$labelNo#$blok#$locationId';

  bool matchesLocation({
    required String stockOpnameNo,
    required String blok,
    required int locationId,
  }) {
    return this.stockOpnameNo == stockOpnameNo &&
        this.blok == blok &&
        this.locationId == locationId;
  }

  SoV2FailedScan copyWith({
    SoV2FailedReason? reason,
    String? message,
    DateTime? lastAttemptAt,
    int? retryCount,
    String? lastRetryMessage,
  }) {
    return SoV2FailedScan(
      stockOpnameNo: stockOpnameNo,
      labelNo: labelNo,
      blok: blok,
      locationId: locationId,
      reason: reason ?? this.reason,
      message: message ?? this.message,
      createdAt: createdAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      retryCount: retryCount ?? this.retryCount,
      lastRetryMessage: lastRetryMessage ?? this.lastRetryMessage,
    );
  }

  factory SoV2FailedScan.fromJson(Map<String, dynamic> json) {
    return SoV2FailedScan(
      stockOpnameNo: _asString(json['stockOpnameNo']),
      labelNo: _asString(json['labelNo']),
      blok: _asString(json['blok']),
      locationId: _asInt(json['locationId']),
      reason: SoV2FailedReason.values.firstWhere(
        (value) => value.name == json['reason'],
        orElse: () => SoV2FailedReason.unknown,
      ),
      message: _asString(json['message']),
      createdAt: _asDate(json['createdAt']),
      lastAttemptAt: _asDate(json['lastAttemptAt']),
      retryCount: _asInt(json['retryCount']),
      lastRetryMessage: json['lastRetryMessage']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stockOpnameNo': stockOpnameNo,
      'labelNo': labelNo,
      'blok': blok,
      'locationId': locationId,
      'reason': reason.name,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'lastAttemptAt': lastAttemptAt.toIso8601String(),
      'retryCount': retryCount,
      'lastRetryMessage': lastRetryMessage,
    };
  }
}

/// Ringkasan hasil satu proses kirim ulang antrean gagal.
class SoV2RetryReport {
  const SoV2RetryReport({
    required this.total,
    required this.succeeded,
    required this.skippedAlreadyScanned,
    required this.failed,
    this.lastMessages = const [],
  });

  final int total;
  final int succeeded;
  final int skippedAlreadyScanned;
  final int failed;
  final List<String> lastMessages;

  bool get isEmpty => total == 0;
  bool get hasChanges => succeeded > 0 || skippedAlreadyScanned > 0;

  String get summary {
    if (isEmpty) return 'Tidak ada label gagal untuk dikirim ulang.';
    final parts = <String>[];
    if (succeeded > 0) parts.add('$succeeded berhasil');
    if (skippedAlreadyScanned > 0) {
      parts.add('$skippedAlreadyScanned sudah tercatat di server');
    }
    if (failed > 0) parts.add('$failed masih gagal');
    return parts.join(' · ');
  }
}

String _asString(dynamic value) => value?.toString() ?? '';

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

DateTime _asDate(dynamic value) {
  final parsed = DateTime.tryParse('$value');
  return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
}
