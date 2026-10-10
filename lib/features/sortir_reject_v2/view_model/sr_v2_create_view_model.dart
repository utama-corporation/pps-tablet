import 'package:flutter/foundation.dart';

import '../../../core/network/api_error.dart';
import '../../warehouse/model/warehouse_model.dart';
import '../model/sr_v2_label_info.dart';
import '../model/sr_v2_transaction.dart';
import '../repository/sr_v2_repository.dart';

enum SrV2OutputType { barangJadi, reject }

class SrV2OutputEntry {
  final String id;
  SrV2OutputType type;
  int idJenis;
  String namaJenis;
  int pcs;
  double berat;

  SrV2OutputEntry({
    required this.id,
    required this.type,
    required this.idJenis,
    required this.namaJenis,
    this.pcs = 0,
    this.berat = 0,
  });

  bool get isReject => type == SrV2OutputType.reject;
  bool get isBarangJadi => type == SrV2OutputType.barangJadi;
}

class SrV2CreateViewModel extends ChangeNotifier {
  final SrV2Repository repository;

  SrV2CreateViewModel({SrV2Repository? repository})
      : repository = repository ?? SrV2Repository();

  // === Input state ===
  final List<SrV2LabelInfo> inputs = [];
  bool isLookingUp = false;
  String? lookupError;

  // === Output state ===
  final List<SrV2OutputEntry> outputs = [];
  SrV2OutputType? outputMode;

  // === Form state ===
  MstWarehouse? selectedWarehouse;
  bool isSubmitting = false;
  String? submitError;
  SrV2Transaction? lastResult;

  // === Derived ===
  int get totalPcsInput => inputs.fold(0, (s, l) => s + l.pcs);
  double get totalQtyInput => inputs.fold(0.0, (s, l) => s + l.qty);
  int get totalPcsOutput =>
      outputs.fold(0, (s, o) => s + (o.isBarangJadi ? o.pcs : 0));
  double get totalBeratReject =>
      outputs.fold(0.0, (s, o) => s + (o.isReject ? o.berat : 0));
  int get remainingPcs => totalPcsInput - totalPcsOutput;
  bool get hasRejectOutput => outputs.any((o) => o.isReject);

  bool get isBahanPendukungInput =>
      inputs.isNotEmpty && inputs.every((l) => l.isBahanPendukung);

  /// Label yang backend hanya izinkan jadi output reject: furniture WIP
  /// (`BB.`), reject (`BF.`), dan bahan pendukung (`BP.`). Backend menolak
  /// output pcs untuk bahan pendukung
  /// ("outputs reject (berat) wajib diisi untuk input bahanPendukung").
  bool get isRejectPrefixInput =>
      inputs.isNotEmpty &&
      inputs.every((l) {
        if (l.isBahanPendukung) return true;
        final code = l.labelCode.toUpperCase();
        return code.startsWith('BF') || code.startsWith('BB');
      });
  SrV2OutputType? get nextOutputType =>
      isRejectPrefixInput ? SrV2OutputType.reject : outputMode;
  bool get canChangeOutputMode => !isRejectPrefixInput;
  bool get allOutputsSameType =>
      outputs.isEmpty || outputs.every((o) => o.type == outputs.first.type);

  bool get allOutputsValid =>
      outputs.isNotEmpty &&
      outputs.every(
        (o) =>
            o.idJenis > 0 && (o.isReject ? o.berat > 0 : o.pcs > 0),
      );

  bool get isBalanced =>
      outputs.isNotEmpty &&
      allOutputsSameType &&
      allOutputsValid &&
      (hasRejectOutput || (inputs.isNotEmpty && remainingPcs == 0));

  // === Actions ===

  String _labelGroup(String labelCode) {
    final code = labelCode.toUpperCase();
    if (code.startsWith('BA')) return 'BA';
    if (code.startsWith('BB')) return 'BB';
    if (code.startsWith('BF')) return 'BF';
    if (code.startsWith('BP')) return 'BP';
    return '';
  }

  Future<void> lookupLabel(String labelCode) async {
    final code = labelCode.trim();
    if (code.isEmpty) return;

    if (inputs.any((l) => l.labelCode == code)) {
      lookupError = 'Label $code sudah ditambahkan';
      notifyListeners();
      return;
    }

    if (inputs.isNotEmpty) {
      final existingGroup = _labelGroup(inputs.first.labelCode);
      final newGroup = _labelGroup(code);
      if (existingGroup != newGroup) {
        lookupError =
            'Tidak bisa mencampur label $existingGroup dan $newGroup dalam satu transaksi';
        notifyListeners();
        return;
      }
    }

    isLookingUp = true;
    lookupError = null;
    notifyListeners();

    try {
      final info = await repository.fetchLabelInfo(code);
      inputs.add(info);
      if (isRejectPrefixInput) {
        outputMode = SrV2OutputType.reject;
        outputs.removeWhere((o) => !o.isReject);
      }
    } catch (e) {
      lookupError = apiErrorMessage(e);
    } finally {
      isLookingUp = false;
      notifyListeners();
    }
  }

  void removeInput(String labelCode) {
    inputs.removeWhere((l) => l.labelCode == labelCode);
    if (inputs.isEmpty && outputs.isEmpty) outputMode = null;
    notifyListeners();
  }

  void addOutput({
    required SrV2OutputType type,
    required int idJenis,
    required String namaJenis,
  }) {
    final actualType = isRejectPrefixInput
        ? SrV2OutputType.reject
        : (outputMode ?? type);
    outputMode ??= actualType;
    final id = '${DateTime.now().millisecondsSinceEpoch}_${outputs.length}';
    outputs.add(
      SrV2OutputEntry(
        id: id,
        type: actualType,
        idJenis: idJenis,
        namaJenis: namaJenis,
      ),
    );
    notifyListeners();
  }

  void clearOutputMode() {
    if (isRejectPrefixInput) return;
    outputMode = null;
    outputs.clear();
    notifyListeners();
  }

  void removeOutput(String outputId) {
    outputs.removeWhere((o) => o.id == outputId);
    if (outputs.isEmpty && inputs.isEmpty) outputMode = null;
    notifyListeners();
  }

  void updateOutputJenis(String outputId, int idJenis, String namaJenis) {
    final out = outputs.firstWhere((o) => o.id == outputId);
    out.idJenis = idJenis;
    out.namaJenis = namaJenis;
    notifyListeners();
  }

  void updateOutputPcs(String outputId, int pcs) {
    final out = outputs.firstWhere((o) => o.id == outputId);
    out.pcs = pcs;
    notifyListeners();
  }

  void updateOutputBerat(String outputId, double berat) {
    final out = outputs.firstWhere((o) => o.id == outputId);
    out.berat = berat;
    notifyListeners();
  }

  void setWarehouse(MstWarehouse? warehouse) {
    selectedWarehouse = warehouse;
    notifyListeners();
  }

  Future<SrV2Transaction?> submit() async {
    if (!isBalanced) return null;
    isSubmitting = true;
    submitError = null;
    notifyListeners();

    try {
      final inputCodes = inputs.map((l) => l.labelCode).toList();
      final outputsJson = outputs
          .map(
            (o) => o.isReject
                ? <String, dynamic>{'idJenis': o.idJenis, 'berat': o.berat}
                : <String, dynamic>{'idJenis': o.idJenis, 'pcs': o.pcs},
          )
          .toList();

      final result = await repository.submit(
        idWarehouse: selectedWarehouse!.idWarehouse,
        inputs: inputCodes,
        outputs: outputsJson,
      );
      lastResult = result;
      _reset();
      return result;
    } catch (e) {
      submitError = apiErrorMessage(e);
      return null;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void _reset() {
    inputs.clear();
    outputs.clear();
    outputMode = null;
    selectedWarehouse = null;
    lookupError = null;
    submitError = null;
  }

  void reset() {
    _reset();
    notifyListeners();
  }
}
