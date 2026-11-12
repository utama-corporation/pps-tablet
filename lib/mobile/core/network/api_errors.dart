// lib/core/network/api_errors.dart
import 'dart:io';

enum ApiFailureType {
  auth,
  validation,
  network,
  server,
  maintenance,
  unknown,
}

class ApiFailure implements Exception {
  final ApiFailureType type;
  final String message;

  /// optional details
  final int? statusCode;
  final String detailCode;

  ApiFailure({
    required this.type,
    required this.message,
    this.statusCode,
    this.detailCode = 'unknown',
  });

  @override
  String toString() =>
      'ApiFailure(type=$type, status=$statusCode, detail=$detailCode, message=$message)';

  static ApiFailure fromStatus({
    required int statusCode,
    required String message,
    String? backendErrorType,
  }) {
    if (statusCode == 503) {
      return ApiFailure(
        type: ApiFailureType.maintenance,
        statusCode: 503,
        detailCode: 'server_503',
        message: message.isNotEmpty ? message : 'Server sedang maintenance (503).',
      );
    }

    if (statusCode >= 500) {
      return ApiFailure(
        type: ApiFailureType.server,
        statusCode: statusCode,
        detailCode: 'server_${statusCode}',
        message: message.isNotEmpty ? message : 'Terjadi kesalahan di server.',
      );
    }

    if (statusCode == 400) {
      return ApiFailure(
        type: ApiFailureType.validation,
        statusCode: 400,
        detailCode: 'validation_400',
        message: message.isNotEmpty ? message : 'Input tidak valid.',
      );
    }

    if (statusCode == 401 || statusCode == 403 || statusCode == 404) {
      return ApiFailure(
        type: ApiFailureType.auth,
        statusCode: statusCode,
        detailCode: 'auth_${statusCode}',
        message: message.isNotEmpty ? message : 'Autentikasi gagal.',
      );
    }

    // fallback pakai backend errorType bila ada
    final be = (backendErrorType ?? '').toLowerCase();
    if (be.contains('validation')) {
      return ApiFailure(type: ApiFailureType.validation, statusCode: statusCode, detailCode: 'validation', message: message);
    }
    if (be.contains('invalid') || be.contains('wrong') || be.contains('auth')) {
      return ApiFailure(type: ApiFailureType.auth, statusCode: statusCode, detailCode: 'auth', message: message);
    }

    return ApiFailure(
      type: ApiFailureType.unknown,
      statusCode: statusCode,
      detailCode: 'unknown',
      message: message.isNotEmpty ? message : 'Terjadi kesalahan.',
    );
  }

  static String socketDetail(SocketException e) {
    final m = e.message.toLowerCase();
    if (m.contains('failed host lookup') || m.contains('name not known')) return 'dns';
    if (m.contains('connection refused')) return 'backend_offline';
    if (m.contains('no route to host') || m.contains('network is unreachable') || m.contains('unreachable')) return 'no_route';
    if (m.contains('timed out')) return 'timeout';
    return 'network_error';
  }
}
