import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/network/api_error.dart';
import '../model/favorit_row.dart';
import '../repository/favorit_repository.dart';

/// Favorit per user — dipakai bersama app bar + laporan cards + layar Favorit.
class FavoritViewModel extends ChangeNotifier {
  FavoritViewModel(this.repository);

  final FavoritRepository repository;

  List<FavoritRow> _rows = [];
  bool loading = false;
  bool busy = false;
  String error = '';
  Future<void>? _inflight;

  // notifyListeners() pada VM yang sudah di-dispose melempar error saat
  // tree dibongkar (assert framework _dependents.isEmpty).
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  bool _notifyScheduled = false;

  /// notifyListeners() di tengah fase build/layout (mis. load() dipanggil dari
  /// initState) ditolak assert di debug, tapi di RELEASE provider jadi
  /// ditandai dirty pada saat yang salah dan notifikasi berikutnya tidak lagi
  /// me-rebuild bintang favorit — gejala "data masuk DB tapi ikon tidak
  /// kuning" yang hanya muncul di APK production. Tunda ke setelah frame.
  void _notify() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (!_disposed) notifyListeners();
      });
      SchedulerBinding.instance.ensureVisualUpdate();
      return;
    }
    notifyListeners();
  }

  List<FavoritRow> get rows => List.unmodifiable(_rows);

  bool isFavorite(String tipe, String kode) =>
      _rows.any((r) => r.matches(tipe, kode));

  /// Muat daftar dari server. Muat yang sedang jalan dipakai ulang, kecuali
  /// [fresh]: setelah tulis (POST) fetch yang dimulai SEBELUM tulis berisi
  /// data lama — di jaringan production yang lambat fetch awal app shell bisa
  /// masih berjalan, dan hasilnya menimpa status favorit yang baru disimpan.
  Future<void> load({bool fresh = false}) async {
    if (_disposed) return;
    final inflight = _inflight;
    if (inflight != null) {
      if (!fresh) return inflight;
      try {
        await inflight;
      } catch (_) {}
      if (_disposed) return;
      if (_inflight != null && !identical(_inflight, inflight)) {
        // Fetch lain sudah dimulai setelah tulis → ikut menunggunya.
        return _inflight;
      }
    }
    final future = _doLoad();
    _inflight = future;
    try {
      await future;
    } finally {
      if (identical(_inflight, future)) _inflight = null;
    }
  }

  Future<void> _doLoad() async {
    if (_disposed) return;
    loading = true;
    error = '';
    _notify();
    try {
      _rows = await repository.fetchAll();
    } catch (e) {
      if (!_disposed) error = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        loading = false;
        _notify();
      }
    }
  }

  /// Toggle favorit; bila [komentar] terisi dan entri belum ada, komentar
  /// disimpan bersama penambahan.
  Future<void> toggle({
    required String tipe,
    required String kode,
    String? komentar,
  }) async {
    if (busy) return;
    busy = true;
    _notify();
    final snapshot = List<FavoritRow>.from(_rows);
    try {
      final existing = _rows.where((r) => r.matches(tipe, kode));
      if (existing.isNotEmpty) {
        // Optimistik: buang dari daftar langsung; rollback bila gagal.
        _rows = [
          for (final r in _rows)
            if (!r.matches(tipe, kode)) r,
        ];
        _notify();
        try {
          await repository.remove(tipe: tipe, kode: kode);
        } catch (e) {
          _rows = snapshot;
          rethrow;
        }
      } else {
        // Optimistik: tampilkan sebagai favorit langsung; rollback bila gagal.
        final optimistic = FavoritRow(
          tipe: tipe.trim().toLowerCase(),
          kode: kode.trim(),
          urutan: _rows.isEmpty
              ? 1
              : _rows.map((r) => r.urutan).reduce(math.max) + 1,
          komentar: komentar?.trim() ?? '',
        );
        _rows = [..._rows, optimistic];
        _notify();
        try {
          await repository.add(tipe: tipe, kode: kode, komentar: komentar);
        } catch (e) {
          _rows = [
            for (final r in _rows)
              if (!r.matches(tipe, kode)) r,
          ];
          rethrow;
        }
        // Reload (fetch baru, bukan fetch lama yang masih jalan) supaya urutan
        // konsisten dengan server.
        await load(fresh: true);
        // Server sudah menerima POST (201). Bila daftar hasil reload belum
        // memuatnya (replika/caching lambat, format kolom berbeda), status
        // favorit tetap ditampilkan — jangan dibalik jadi abu-abu.
        if (!_disposed && !isFavorite(tipe, kode)) {
          _rows = [..._rows, optimistic];
        }
      }
    } finally {
      if (!_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> removeItem(FavoritRow row) async {
    if (busy) return;
    busy = true;
    _notify();
    final snapshot = List<FavoritRow>.from(_rows);
    try {
      _rows = [
        for (final r in _rows)
          if (!r.matches(row.tipe, row.kode)) r,
      ];
      _notify();
      try {
        await repository.remove(tipe: row.tipe, kode: row.kode);
      } catch (e) {
        _rows = snapshot;
        rethrow;
      }
    } finally {
      if (!_disposed) {
        busy = false;
        _notify();
      }
    }
  }

  // onReorderItem Flutter sudah menyesuaikan newIndex setelah item
  // lama dihapus — langsung insert.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (busy || loading) return;
    if (newIndex == oldIndex) return;
    if (oldIndex < 0 || oldIndex >= _rows.length) return;
    if (newIndex < 0 || newIndex >= _rows.length) return;
    final reordered = List<FavoritRow>.from(_rows);
    reordered.insert(newIndex, reordered.removeAt(oldIndex));
    _rows = reordered;
    busy = true;
    _notify();
    try {
      await repository.reorder(reordered);
    } catch (e) {
      // Reload penuh supaya urutan tidak dibiarkan setengah-jadinya.
      await load();
    } finally {
      if (!_disposed) {
        busy = false;
        _notify();
      }
    }
  }
}
