import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../features/bahan_pendukung/penerimaan/repository/penerimaan_bahan_pendukung_repository.dart';
import '../../features/label/broker/repository/broker_repository.dart';
import '../../features/label/bahan_baku/repository/bahan_baku_repository.dart';
import '../../features/label/bonggolan/repository/bonggolan_repository.dart';
import '../../features/label/crusher/repository/crusher_repository.dart';
import '../../features/label/gilingan/repository/gilingan_repository.dart';
import '../../features/label/mixer/repository/mixer_repository.dart';
import '../../features/label/furniture_wip/repository/furniture_wip_repository.dart';
import '../../features/label/packing/repository/packing_repository.dart';
import '../../features/label/reject/repository/reject_repository.dart';
import '../../features/label/washing/repository/washing_repository.dart';
import '../../features/penerimaan_barang_dagang/repository/penerimaan_barang_dagang_repository.dart';
import '../network/api_client.dart';
import '../network/label_print_lock_api.dart';

class LabelPrintSyncQueue extends ChangeNotifier with WidgetsBindingObserver {
  static const String _boxName = 'label_print_sync_queue_v1';
  static const Duration _processEvery = Duration(seconds: 8);

  final LabelPrintLockApi _lockApi = LabelPrintLockApi();
  final WashingRepository _washingRepo = WashingRepository();
  final BrokerRepository _brokerRepo = BrokerRepository(api: ApiClient());
  final BahanBakuRepository _bahanBakuRepo = BahanBakuRepository(
    api: ApiClient(),
  );
  final BonggolanRepository _bonggolanRepo = BonggolanRepository();
  final CrusherRepository _crusherRepo = CrusherRepository();
  final GilinganRepository _gilinganRepo = GilinganRepository();
  final MixerRepository _mixerRepo = MixerRepository();
  final FurnitureWipRepository _furnitureWipRepo = FurnitureWipRepository();
  final PackingRepository _packingRepo = PackingRepository(api: ApiClient());
  final RejectRepository _rejectRepo = RejectRepository(api: ApiClient());
  final PenerimaanBahanPendukungRepository _bahanPendukungRepo =
      PenerimaanBahanPendukungRepository(api: ApiClient());
  final PenerimaanBarangDagangRepository _barangDagangRepo =
      PenerimaanBarangDagangRepository(api: ApiClient());

  Box<dynamic>? _box;
  Timer? _timer;
  bool _isStarted = false;
  bool _isProcessing = false;

  Future<void> start() async {
    if (_isStarted) return;
    _isStarted = true;
    WidgetsBinding.instance.addObserver(this);

    _box = await Hive.openBox<dynamic>(_boxName);
    _timer = Timer.periodic(_processEvery, (_) => processNow());
    unawaited(processNow());
  }

  Future<void> stop() async {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _isStarted = false;
  }

  int pendingCountFor(String feature) {
    final box = _box;
    if (box == null) return 0;
    final f = feature.trim().toLowerCase();
    if (f.isEmpty) return 0;

    var count = 0;
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;
      final itemFeature = raw['feature']?.toString().toLowerCase();
      if (itemFeature == f) count++;
    }
    return count;
  }

  int get pendingCount => _box?.length ?? 0;

  Future<void> enqueue({
    required String feature,
    required String noLabel,
    Map<String, String>? extra,
    bool needsIncrement = false,
    bool needsReleaseLock = false,
  }) async {
    final f = feature.trim().toLowerCase();
    final no = noLabel.trim();
    if (f.isEmpty || no.isEmpty) return;
    if (!needsIncrement && !needsReleaseLock) return;

    await _ensureReady();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final key = _jobKey(f, no);
    final current = _readJob(key);
    final currentExtra = _readExtra(current?['extra']);
    final mergedExtra = <String, String>{
      ...currentExtra,
      ...?extra,
    };
    final merged = <String, dynamic>{
      'feature': f,
      'noLabel': no,
      if (mergedExtra.isNotEmpty) 'extra': mergedExtra,
      'needsIncrement': (current?['needsIncrement'] == true) || needsIncrement,
      'needsReleaseLock':
          (current?['needsReleaseLock'] == true) || needsReleaseLock,
      'retryCount': (current?['retryCount'] as int?) ?? 0,
      'nextRetryAtMs': nowMs,
      'updatedAtMs': nowMs,
      'createdAtMs': (current?['createdAtMs'] as int?) ?? nowMs,
    };

    await _box!.put(key, merged);
    notifyListeners();
    unawaited(processNow());
  }

  Future<void> processNow() async {
    if (_isProcessing) return;
    await _ensureReady();
    _isProcessing = true;

    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final keys = _box!.keys.cast<dynamic>().toList(growable: false);

      for (final keyRaw in keys) {
        final key = keyRaw.toString();
        final job = _readJob(key);
        if (job == null) continue;

        final nextRetryAtMs = (job['nextRetryAtMs'] as int?) ?? 0;
        if (nextRetryAtMs > nowMs) continue;

        final feature = (job['feature'] ?? '').toString().toLowerCase();
        final noLabel = (job['noLabel'] ?? '').toString();
        final extra = _readExtra(job['extra']);
        if (feature.isEmpty || noLabel.isEmpty) {
          await _box!.delete(key);
          continue;
        }

        var needsIncrement = job['needsIncrement'] == true;
        var needsReleaseLock = job['needsReleaseLock'] == true;
        var retryCount = (job['retryCount'] as int?) ?? 0;

        if (needsIncrement) {
          try {
            await _incrementPrinted(feature, noLabel, extra);
            needsIncrement = false;
          } catch (_) {}
        }

        if (needsReleaseLock) {
          try {
            await _lockApi.release(noLabel);
            needsReleaseLock = false;
          } catch (_) {}
        }

        if (!needsIncrement && !needsReleaseLock) {
          await _box!.delete(key);
          continue;
        }

        retryCount += 1;
        final waitMs = _nextBackoffMs(retryCount);
        await _box!.put(key, <String, dynamic>{
          ...job,
          'needsIncrement': needsIncrement,
          'needsReleaseLock': needsReleaseLock,
          'retryCount': retryCount,
          'nextRetryAtMs': nowMs + waitMs,
          'updatedAtMs': nowMs,
        });
      }
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<void> _incrementPrinted(
    String feature,
    String noLabel,
    Map<String, String> extra,
  ) async {
    switch (feature) {
      case 'washing':
        await _washingRepo.markAsPrinted(noLabel);
        return;
      case 'broker':
        await _brokerRepo.markAsPrinted(noLabel);
        return;
      case 'bonggolan':
        await _bonggolanRepo.markAsPrinted(noLabel);
        return;
      case 'crusher':
        await _crusherRepo.markAsPrinted(noLabel);
        return;
      case 'gilingan':
        await _gilinganRepo.markAsPrinted(noLabel);
        return;
      case 'mixer':
        await _mixerRepo.markAsPrinted(noLabel);
        return;
      case 'furniture_wip':
        await _furnitureWipRepo.markAsPrinted(noLabel);
        return;
      case 'packing':
        await _packingRepo.markAsPrinted(noLabel);
        return;
      case 'reject':
        await _rejectRepo.markAsPrinted(noLabel);
        return;
      case 'bahan_baku':
        final noBahanBaku = (extra['noBahanBaku'] ?? '').trim();
        final noPallet = (extra['noPallet'] ?? noLabel).trim();
        if (noBahanBaku.isEmpty || noPallet.isEmpty) {
          throw ArgumentError(
            'Missing noBahanBaku/noPallet for bahan_baku sync job',
          );
        }
        await _bahanBakuRepo.markAsPrinted(
          noBahanBaku: noBahanBaku,
          noPallet: noPallet,
        );
        return;
      case 'bahan_pendukung':
        await _bahanPendukungRepo.markItemPrinted(noLabel);
        return;
      case 'barang_dagang':
        await _barangDagangRepo.markItemPrinted(noLabel);
        return;
      default:
        throw UnsupportedError('Unsupported print feature: $feature');
    }
  }

  String _jobKey(String feature, String noLabel) => '$feature::$noLabel';

  int _nextBackoffMs(int retryCount) {
    final step = retryCount.clamp(1, 6);
    return 1000 * (1 << step); // 2s, 4s, 8s, ... max 64s
  }

  Map<String, dynamic>? _readJob(String key) {
    final raw = _box?.get(key);
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  Map<String, String> _readExtra(dynamic raw) {
    if (raw is! Map) return const <String, String>{};
    return raw.map(
      (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
    );
  }

  Future<void> _ensureReady() async {
    if (!_isStarted) {
      await start();
    } else if (_box == null) {
      _box = await Hive.openBox<dynamic>(_boxName);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(processNow());
    }
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }
}
