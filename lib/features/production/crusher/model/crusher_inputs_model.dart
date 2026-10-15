// lib/features/production/crusher/model/crusher_inputs_model.dart

import '../../shared/models/bb_item.dart';
import '../../shared/models/bonggolan_item.dart';
import '../../shared/models/reject_item.dart';
import '../../../../core/utils/model_helpers.dart';

// ✅ Export item models
export '../../shared/models/bb_item.dart';
export '../../shared/models/bonggolan_item.dart';
export '../../shared/models/reject_item.dart';

/* ===================== ROOT AGGREGATOR ===================== */

class CrusherInputs {
  final List<BbItem> bb;
  final List<BonggolanItem> bonggolan;

  /// Full dan partial digabung di backend pada satu array; baris partial
  /// ditandai oleh `noRejectPartial` (lihat crusher-production-service.js:1360).
  final List<RejectItem> reject;

  final Map<String, int> summary;

  CrusherInputs({
    required this.bb,
    required this.bonggolan,
    required this.summary,
    this.reject = const [],
  });

  factory CrusherInputs.fromJson(Map<String, dynamic> j) {
    List<T> _listOf<T>(dynamic v, T Function(Map<String, dynamic>) f) {
      final list = (v ?? []) as List;
      return list.map<T>((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    }

    Map<String, int> _toSummary(dynamic v) {
      final m = Map<String, dynamic>.from((v ?? {}) as Map);
      return m.map((k, v) => MapEntry(k, asInt(v) ?? 0));
    }

    return CrusherInputs(
      bb: _listOf(j['bb'], (m) => BbItem.fromJson(m)),
      bonggolan: _listOf(j['bonggolan'], (m) => BonggolanItem.fromJson(m)),
      reject: _listOf(j['reject'], (m) => RejectItem.fromJson(m)),
      summary: _toSummary(j['summary']),
    );
  }

  // Quick totals
  double totalBeratBb() => bb.fold(0.0, (s, it) => s + (it.berat ?? 0));
  double totalBeratBonggolan() => bonggolan.fold(0.0, (s, it) => s + (it.berat ?? 0));
  double totalBeratReject() => reject.fold(0.0, (s, it) => s + (it.berat ?? 0));

  // Total keseluruhan
  double totalBeratAll() => totalBeratBb() + totalBeratBonggolan() + totalBeratReject();
}