import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_errors.dart';
import '../model/so_v2_failed_scan.dart';
import '../model/so_v2_models.dart';
import '../repository/so_v2_repository.dart';

/// Antrean lokal label yang gagal dikirim ke server.
///
/// Berdiri sendiri dari ViewModel detail karena harus diisi dari layar scan
/// sekaligus dibaca dari layar detail setelah scanner ditutup.
class SoV2FailedScanViewModel extends ChangeNotifier {
  SoV2FailedScanViewModel({SoV2Repository? repository})
      : _repository = repository ?? SoV2Repository() {
    unawaited(_load());
  }

  static const String _prefsKey = 'so_v2_failed_scans';
  final Connectivity _connectivity = Connectivity();

  final SoV2Repository _repository;

  List<SoV2FailedScan> _entries = const [];
  bool _isLoaded = false;
  bool _isRetrying = false;
  bool _connectivityAttached = false;

  List<SoV2FailedScan> get entries => List.unmodifiable(_entries);
  bool get isLoaded => _isLoaded;
  bool get isRetrying => _isRetrying;
  bool get isEmpty => _entries.isEmpty;

  List<SoV2FailedScan> entriesFor({
    required String stockOpnameNo,
    required String blok,
    required int locationId,
  }) {
    return _entries
        .where(
          (entry) => entry.matchesLocation(
            stockOpnameNo: stockOpnameNo,
            blok: blok,
            locationId: locationId,
          ),
        )
        .toList();
  }

  int retryableCountFor({
    required String stockOpnameNo,
    required String blok,
    required int locationId,
  }) {
    return entriesFor(
      stockOpnameNo: stockOpnameNo,
      blok: blok,
      locationId: locationId,
    ).where((entry) => entry.isRetryable).length;
  }

  /// Simpan atau perbarui entri untuk label yang sama. Vote record terakhir
  /// menang supaya hasil retry yang lebih baru tidak tertimpa data lama.
  Future<void> record({
    required String stockOpnameNo,
    required String labelNo,
    required String blok,
    required int locationId,
    required Object error,
    SoV2FailedReason? reason,
    String? message,
  }) async {
    await _ensureLoaded();
    final resolvedReason =
        reason ??
        (error is ApiFailure
            ? SoV2FailedReason.fromApiFailure(error.type)
            : SoV2FailedReason.unknown);
    final resolvedMessage =
        message ??
        (error is ApiFailure
            ? error.message
            : error.toString().replaceFirst('Exception: ', ''));

    final now = DateTime.now();
    final normalizedLabel = labelNo.trim();
    final key = '$stockOpnameNo#$normalizedLabel#$blok#$locationId';
    final index = _entries.indexWhere((entry) => entry.key == key);
    final existing = index >= 0 ? _entries[index] : null;

    final entry = SoV2FailedScan(
      stockOpnameNo: stockOpnameNo,
      labelNo: normalizedLabel,
      blok: blok,
      locationId: locationId,
      reason: resolvedReason,
      message: resolvedMessage,
      createdAt: existing?.createdAt ?? now,
      lastAttemptAt: now,
      retryCount: existing?.retryCount ?? 0,
    );

    final next = [..._entries];
    if (index >= 0) {
      next[index] = entry;
    } else {
      next.add(entry);
    }
    _entries = next;
    notifyListeners();
    await _persist();
    _ensureAutoRetry();
  }

  Future<void> remove(SoV2FailedScan entry) async {
    await _ensureLoaded();
    _entries = _entries.where((item) => item.key != entry.key).toList();
    notifyListeners();
    await _persist();
  }

  Future<void> clearLocation({
    required String stockOpnameNo,
    required String blok,
    required int locationId,
  }) async {
    await _ensureLoaded();
    _entries = _entries
        .where(
          (entry) => !entry.matchesLocation(
            stockOpnameNo: stockOpnameNo,
            blok: blok,
            locationId: locationId,
          ),
        )
        .toList();
    notifyListeners();
    await _persist();
  }

  /// Kirim ulang seluruh entri retryable pada satu lokasi, berurutan.
  ///
  /// Entri permanen dilewati — mengirim ulang label duplikat atau salah
  /// kategori hanya menghasilkan error yang sama.
  Future<SoV2RetryReport> retryLocation({
    required String stockOpnameNo,
    required String blok,
    required int locationId,
    void Function(int done, int total)? onProgress,
  }) async {
    await _ensureLoaded();
    final targets = entriesFor(
      stockOpnameNo: stockOpnameNo,
      blok: blok,
      locationId: locationId,
    ).where((entry) => entry.isRetryable).toList();

    if (targets.isEmpty || _isRetrying) {
      return SoV2RetryReport(
        total: targets.length,
        succeeded: 0,
        skippedAlreadyScanned: 0,
        failed: 0,
      );
    }

    _isRetrying = true;
    notifyListeners();

    var succeeded = 0;
    var skipped = 0;
    var failed = 0;
    final messages = <String>[];

    try {
      for (var i = 0; i < targets.length; i++) {
        final entry = targets[i];
        onProgress?.call(i, targets.length);

        // Timeout bisa berarti request sudah berhasil di server lalu responsnya
        // hilang. Cek dulu supaya tidak mengirim label yang sama dua kali.
        if (await _alreadyScanned(entry)) {
          skipped++;
          await remove(entry);
          continue;
        }

        try {
          await _repository.submitResult(
            stockOpnameNo: entry.stockOpnameNo,
            labelNo: entry.labelNo,
            blok: entry.blok,
            locationId: entry.locationId,
          );
          succeeded++;
          messages.add('${entry.labelNo} berhasil dikirim');
          await remove(entry);
        } catch (e) {
          failed++;
          messages.add('${entry.labelNo}: ${_message(e)}');
          await _updateAfterFailedRetry(entry, e);
        }
      }
    } finally {
      _isRetrying = false;
      notifyListeners();
    }

    onProgress?.call(targets.length, targets.length);
    return SoV2RetryReport(
      total: targets.length,
      succeeded: succeeded,
      skippedAlreadyScanned: skipped,
      failed: failed,
      lastMessages: messages.take(20).toList(),
    );
  }

  Future<void> _updateAfterFailedRetry(SoV2FailedScan entry, Object error) async {
    final reason = error is ApiFailure
        ? SoV2FailedReason.fromApiFailure(error.type)
        : SoV2FailedReason.unknown;
    final index = _entries.indexWhere((item) => item.key == entry.key);
    if (index < 0) return;
    final next = [..._entries];
    next[index] = next[index].copyWith(
      reason: reason,
      message: _message(error),
      lastAttemptAt: DateTime.now(),
      retryCount: next[index].retryCount + 1,
      lastRetryMessage: _message(error),
    );
    _entries = next;
    notifyListeners();
    await _persist();
  }

  /// Verifikasi lewat endpoint label yang sudah ada (query `search`), tanpa
  /// perlu endpoint baru per label.
  ///
  /// Sengaja konservatif: label hanya dianggap sudah tercatat kalau SEMUA baris
  /// yang cocok sudah discan. Kalau pencarian gagal atau label tidak ditemukan,
  /// tetap coba kirim — biarkan backend yang memutuskan. Salah hapus (skip
  /// label yang seharusnya dikirim) jauh lebih berbahaya daripada retry sia-sia.
  Future<bool> _alreadyScanned(SoV2FailedScan entry) async {
    final queries = <String>[entry.labelNo];
    final explicit = RegExp(r'^(.+)-(\d+)$').firstMatch(entry.labelNo);
    if (explicit != null) queries.add(explicit.group(1)!.trim());

    final matches = <SoV2LabelRow>[];
    for (final query in queries) {
      try {
        final page = await _repository.fetchLabels(
          stockOpnameNo: entry.stockOpnameNo,
          blok: entry.blok,
          locationId: entry.locationId,
          page: 1,
          search: query,
        );
        for (final row in page.groups.expand((group) => group.labels)) {
          if (_rowMatchesLabel(row, entry.labelNo)) matches.add(row);
        }
      } on ApiFailure {
        return false;
      }
    }

    if (matches.isEmpty) return false;
    return matches.every((row) => row.isScanned);
  }

  bool _rowMatchesLabel(SoV2LabelRow row, String labelNo) {
    final target = labelNo.trim().toUpperCase();
    if (row.primaryValue.trim().toUpperCase() == target) return true;
    final noBahanBaku = row.raw['NoBahanBaku'];
    if (noBahanBaku != null &&
        '$noBahanBaku'.trim().toUpperCase() == target) {
      return true;
    }
    return false;
  }

  static String _message(Object error) {
    if (error is ApiFailure) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  Future<void> _ensureLoaded() async {
    if (_isLoaded) return;
    await _load();
  }

  Future<void> _load() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _entries = decoded
              .whereType<Map>()
              .map((item) => SoV2FailedScan.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      } catch (_) {
        _entries = const [];
      }
    }
    _isLoaded = true;
    notifyListeners();
    _ensureAutoRetry();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
    );
  }

  void _ensureAutoRetry() {
    if (_connectivityAttached) return;
    if (_entries.where((entry) => entry.isRetryable).isEmpty) return;
    _connectivityAttached = true;
    _connectivity.onConnectivityChanged.listen((results) {
      if (results.isEmpty) return;
      unawaited(_autoRetryPending());
    });
  }

  /// Kirim ulang diam-diam begitu perangkat kembali online. Kegagalan tetap
  /// ditahan di antrean, jadi pemanggilan berulang aman.
  Future<void> _autoRetryPending() async {
    if (_isRetrying) return;
    final retryable = _entries.where((entry) => entry.isRetryable).toList();
    if (retryable.isEmpty) return;

    _isRetrying = true;
    notifyListeners();
    try {
      for (final entry in retryable) {
        if (await _alreadyScanned(entry)) {
          await remove(entry);
          continue;
        }
        try {
          await _repository.submitResult(
            stockOpnameNo: entry.stockOpnameNo,
            labelNo: entry.labelNo,
            blok: entry.blok,
            locationId: entry.locationId,
          );
          await remove(entry);
        } catch (e) {
          await _updateAfterFailedRetry(entry, e);
        }
      }
    } finally {
      _isRetrying = false;
      notifyListeners();
    }
  }
}
