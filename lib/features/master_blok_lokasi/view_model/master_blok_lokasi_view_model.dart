import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/master_blok_lokasi_models.dart';
import '../repository/master_blok_lokasi_repository.dart';

class MasterBlokLokasiViewModel extends ChangeNotifier {
  MasterBlokLokasiViewModel(this.repository);

  final MasterBlokLokasiRepository repository;

  // Master comboboxes (warehouses + kategoris)
  BlokMaster? master;
  bool masterLoading = false;
  String masterError = '';

  // Blok (left panel)
  List<BlokRow> _bloks = [];
  String blokQuery = '';
  bool blokLoading = false;
  String blokError = '';

  // Lokasi (right panel, per blok terpilih)
  String? selectedBlok;
  List<LokasiRow> _lokasis = [];
  String lokasiQuery = '';
  bool lokasiLoading = false;
  String lokasiError = '';

  // Lokasi terpilih untuk relasi jenis
  LokasiRow? selectedLokasi;
  List<LokasiJenisRow> _lokasiJenis = [];
  bool jenisLoading = false;
  String jenisError = '';

  // Cache opsi jenis dinamis per kategori (null value = gagal memuat)
  final Map<int, List<JenisOption>?> _jenisCache = {};
  final Map<int, bool> _jenisLoadingMap = {};

  // notifyListeners() pada ChangeNotifier yang sudah di-dispose melempar
  // error dari dalam listener provider saat tree dibongkar
  // (assert framework _dependents.isEmpty).
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

  // ── Filter list (client-side; dataset kecil) ──────────────────────────────

  List<BlokRow> get bloks {
    final q = blokQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_bloks);
    return List.unmodifiable(
      _bloks.where(
        (b) =>
            '${b.blok} ${b.namaWarehouse}'.toLowerCase().contains(q),
      ),
    );
  }

  int get blokTotal => _bloks.length;

  List<LokasiRow> get lokasis {
    final q = lokasiQuery.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_lokasis);
    return List.unmodifiable(
      _lokasis.where(
        (l) =>
            '${l.idLokasi} ${l.description}'.toLowerCase().contains(q),
      ),
    );
  }

  int get lokasiTotal => _lokasis.length;

  List<LokasiJenisRow> get lokasiJenis => List.unmodifiable(_lokasiJenis);

  List<JenisOption>? jenisFor(int? idKategori) {
    if (idKategori == null) return null;
    return _jenisCache[idKategori];
  }

  bool isJenisLoading(int? idKategori) =>
      idKategori != null && (_jenisLoadingMap[idKategori] ?? false);

  bool isJenisFailed(int? idKategori) =>
      idKategori != null &&
      _jenisCache.containsKey(idKategori) &&
      _jenisCache[idKategori] == null;

  // ── Pencarian ──────────────────────────────────────────────────────────────

  void setBlokQuery(String value) {
    if (blokQuery == value.trim()) return;
    blokQuery = value.trim();
    _notify();
  }

  void setLokasiQuery(String value) {
    if (lokasiQuery == value.trim()) return;
    lokasiQuery = value.trim();
    _notify();
  }

  // ── Master ─────────────────────────────────────────────────────────────────

  Future<void> loadMaster() async {
    if (_disposed) return;
    if (masterLoading) return;
    masterLoading = true;
    masterError = '';
    _notify();
    try {
      master = await repository.fetchMaster();
    } catch (e) {
      if (!_disposed) masterError = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        masterLoading = false;
        _notify();
      }
    }
  }

  // ── Blok ───────────────────────────────────────────────────────────────────

  Future<void> loadBloks({bool force = false}) async {
    if (_disposed) return;
    if (blokLoading && !force) return;
    blokLoading = true;
    blokError = '';
    _notify();
    try {
      _bloks = await repository.fetchBloks();
    } catch (e) {
      if (!_disposed) blokError = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        blokLoading = false;
        _notify();
      }
    }
  }

  Future<String> saveBlok({
    String? editBlok,
    required String blok,
    required int idWarehouse,
  }) async {
    final code = blok.trim().toUpperCase();
    if (editBlok == null) {
      await repository.createBlok(blok: code, idWarehouse: idWarehouse);
    } else {
      await repository.updateBlok(blok: editBlok, idWarehouse: idWarehouse);
    }
    if (!_disposed) await loadBloks(force: true);
    return code;
  }

  Future<void> deleteBlok(String blok) async {
    await repository.deleteBlok(blok);
    if (_disposed) return;
    if (selectedBlok == blok) {
      selectedBlok = null;
      _lokasis = [];
      selectedLokasi = null;
      _lokasiJenis = [];
    }
    await loadBloks(force: true);
  }

  // ── Lokasi ─────────────────────────────────────────────────────────────────

  Future<void> selectBlok(String? blok) async {
    if (_disposed) return;
    if (selectedBlok == blok) return;
    selectedBlok = blok;
    _lokasis = [];
    lokasiQuery = '';
    lokasiError = '';
    selectedLokasi = null;
    _lokasiJenis = [];
    _notify();
    if (blok != null) await loadLokasi();
  }

  Future<void> loadLokasi() async {
    if (_disposed) return;
    final blok = selectedBlok;
    if (blok == null) return;
    lokasiLoading = true;
    lokasiError = '';
    _notify();
    try {
      _lokasis = await repository.fetchLokasi(blok);
    } catch (e) {
      if (!_disposed) lokasiError = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        lokasiLoading = false;
        _notify();
      }
    }
  }

  Future<int> nextIdLokasi() async {
    final blok = selectedBlok;
    if (blok == null) return 0;
    return repository.fetchNextIdLokasi(blok);
  }

  Future<String> saveLokasi({
    LokasiRow? edit,
    required String description,
    required bool enable,
  }) async {
    final blok = selectedBlok;
    if (blok == null) {
      throw StateError('Pilih blok terlebih dahulu');
    }
    if (edit == null) {
      await repository.createLokasi(
        blok: blok,
        description: description,
        enable: enable,
      );
    } else {
      await repository.updateLokasi(
        blok: blok,
        idLokasi: edit.idLokasi,
        description: description,
        enable: enable,
      );
    }
    if (!_disposed) await loadLokasi();
    return description;
  }

  Future<void> deleteLokasi(LokasiRow row) async {
    await repository.deleteLokasi(blok: row.blok, idLokasi: row.idLokasi);
    if (_disposed) return;
    if (selectedLokasi?.idLokasi == row.idLokasi) {
      selectedLokasi = null;
      _lokasiJenis = [];
    }
    await loadLokasi();
  }

  // ── Relasi lokasi ↔ jenis ──────────────────────────────────────────────────

  Future<void> selectLokasi(LokasiRow? row) async {
    if (_disposed) return;
    if (selectedLokasi?.idLokasi == row?.idLokasi &&
        selectedLokasi?.blok == row?.blok) {
      if (row == null) {
        selectedLokasi = null;
        _lokasiJenis = [];
        _notify();
      }
      return;
    }
    selectedLokasi = row;
    _lokasiJenis = [];
    jenisError = '';
    _notify();
    if (row != null) await loadLokasiJenis();
  }

  Future<void> loadLokasiJenis() async {
    if (_disposed) return;
    final row = selectedLokasi;
    if (row == null) return;
    jenisLoading = true;
    jenisError = '';
    _notify();
    try {
      _lokasiJenis = await repository.fetchLokasiJenis(
        blok: row.blok,
        idLokasi: row.idLokasi,
      );
    } catch (e) {
      if (!_disposed) jenisError = apiErrorMessage(e);
    } finally {
      if (!_disposed) {
        jenisLoading = false;
        _notify();
      }
    }
  }

  Future<void> loadJenis(int idKategori, {bool force = false}) async {
    if (_disposed) return;
    if (!force && _jenisCache.containsKey(idKategori)) return;
    if (_jenisLoadingMap[idKategori] == true) return;
    _jenisLoadingMap[idKategori] = true;
    _notify();
    try {
      _jenisCache[idKategori] = await repository.fetchJenis(idKategori);
    } catch (e) {
      if (!_disposed) _jenisCache[idKategori] = null;
    } finally {
      if (!_disposed) {
        _jenisLoadingMap[idKategori] = false;
        _notify();
      }
    }
  }

  Future<String> addLokasiJenis({
    required int idKategori,
    required int idJenis,
  }) async {
    final row = selectedLokasi;
    if (row == null) {
      throw StateError('Pilih lokasi terlebih dahulu');
    }
    await repository.addLokasiJenis(
      blok: row.blok,
      idLokasi: row.idLokasi,
      idKategori: idKategori,
      idJenis: idJenis,
    );
    if (!_disposed) await loadLokasiJenis();
    return 'Jenis berhasil ditambahkan';
  }

  Future<void> removeLokasiJenis(LokasiJenisRow row) async {
    await repository.removeLokasiJenis(
      blok: row.blok,
      idLokasi: row.idLokasi,
      idKategori: row.idKategori,
      idJenis: row.idJenis,
    );
    if (!_disposed) await loadLokasiJenis();
  }
}
