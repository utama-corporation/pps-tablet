import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../model/master_barang_models.dart';
import '../repository/master_barang_repository.dart';

class MasterBarangViewModel extends ChangeNotifier {
  MasterBarangViewModel(this.repository);

  final MasterBarangRepository repository;

  // ── Meta (types + summary + options) ─────────────────────
  MasterBarangMeta? meta;
  bool metaLoading = false;
  String metaError = '';

  // ── List (jenis terpilih) ────────────────────────────────
  String? selectedType; // null = overview
  List<MasterBarangItem> _items = [];
  String query = '';
  bool listLoading = false;
  String listError = '';

  MasterBarangTypeMeta? get currentType =>
      selectedType == null ? null : meta?.typeFor(selectedType!);

  List<MasterBarangItem> get items {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List.unmodifiable(_items);
    return List.unmodifiable(
      _items.where((item) {
        final texts = <String>[
          '${item.id}',
          item.nama,
          for (final f in currentType?.fields ?? const <MasterBarangFieldMeta>[])
            item.fieldLabel(f.key),
        ];
        return texts.join(' ').toLowerCase().contains(q);
      }),
    );
  }

  int get totalCount => _items.length;

  /// Ringkasan per jenis — untuk tile overview.
  MasterBarangSummary summaryOf(String typeKey) =>
      meta?.summary[typeKey] ?? const MasterBarangSummary(total: 0, aktif: 0);

  void setQuery(String value) {
    if (query == value.trim()) return;
    query = value.trim();
    notifyListeners();
  }

  Future<void> loadMeta() async {
    metaLoading = true;
    metaError = '';
    notifyListeners();
    try {
      meta = await repository.fetchMeta();
    } catch (e) {
      metaError = apiErrorMessage(e);
    } finally {
      metaLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectType(String? type) async {
    if (selectedType == type) return;
    selectedType = type;
    _items = [];
    query = '';
    listError = '';
    notifyListeners();
    if (type != null) await loadList();
  }

  Future<void> loadList() async {
    final type = selectedType;
    if (type == null) return;
    listLoading = true;
    listError = '';
    notifyListeners();
    try {
      final rows = await repository.fetchList(type);
      _items = List.of(rows)
        ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    } catch (e) {
      listError = apiErrorMessage(e);
    } finally {
      listLoading = false;
      notifyListeners();
    }
  }

  /// Simpan (create bila [id] null, update bila ada) lalu reload list & ringkasan.
  Future<String> save({
    int? id,
    required String nama,
    required Map<String, dynamic> values,
    required bool enable,
  }) async {
    final type = selectedType;
    if (type == null) throw StateError('Jenis master belum dipilih');
    final body = <String, dynamic>{
      'nama': nama.trim(),
      'enable': enable,
      ...values,
    };
    if (id == null) {
      await repository.create(type, body);
    } else {
      await repository.update(type, id, body);
    }
    await Future.wait([loadList(), _reloadMetaSilently()]);
    return nama.trim();
  }

  Future<void> disable(int id) async {
    final type = selectedType;
    if (type == null) return;
    await repository.disable(type, id);
    await Future.wait([loadList(), _reloadMetaSilently()]);
  }

  /// Ringkasan di overview ikut berubah setelah create/nonaktif — gagal pun
  /// tidak menampilkan error (angka di-tile saja yang basi).
  Future<void> _reloadMetaSilently() async {
    try {
      meta = await repository.fetchMeta();
      notifyListeners();
    } catch (_) {}
  }
}
