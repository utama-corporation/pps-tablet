import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

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

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  List<FavoritRow> get rows => List.unmodifiable(_rows);

  bool isFavorite(String tipe, String kode) =>
      _rows.any((r) => r.tipe == tipe && r.kode == kode);

  Future<void> load() async {
    if (_disposed) return;
    // Muat yang sedang jalan dipakai ulang, jangan di-skip diam-diam —
    // toggle() memanggil load() setelah add, jadi caller harus menunggu
    // fetch yang asli, bukan kembali langsung sementara data belum masuk.
    final inflight = _inflight;
    if (inflight != null) return inflight;
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
      final existing = _rows.where(
        (r) => r.tipe == tipe && r.kode == kode,
      );
      if (existing.isNotEmpty) {
        // Optimistik: buang dari daftar langsung; rollback bila gagal.
        _rows = [
          for (final r in _rows)
            if (!(r.tipe == tipe && r.kode == kode)) r,
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
          tipe: tipe,
          kode: kode,
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
              if (r.tipe != tipe || r.kode != kode) r,
          ];
          rethrow;
        }
        // Reload untuk relasi & urutan konsisten dengan server.
        await load();
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
          if (!(r.tipe == row.tipe && r.kode == row.kode)) r,
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
