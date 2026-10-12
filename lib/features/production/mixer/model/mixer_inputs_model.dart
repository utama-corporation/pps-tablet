// lib/features/production/mixer/model/mixer_inputs_model.dart

import '../../shared/models/broker_item.dart';
import '../../shared/models/bb_item.dart';
import '../../shared/models/washing_item.dart';
import '../../shared/models/gilingan_item.dart';
import '../../shared/models/mixer_item.dart';
import '../../shared/models/crusher_item.dart';
import '../../../../core/utils/model_helpers.dart';

export '../../shared/models/broker_item.dart';
export '../../shared/models/bb_item.dart';
export '../../shared/models/washing_item.dart';
export '../../shared/models/gilingan_item.dart';
export '../../shared/models/mixer_item.dart';
export '../../shared/models/crusher_item.dart';

/* ===================== ROOT AGGREGATOR ===================== */

class MixerInputs {
  final List<BrokerItem> broker;
  final List<BbItem> bb;
  final List<WashingItem> washing;
  final List<GilinganItem> gilingan;
  final List<MixerItem> mixer;
  final List<CrusherItem> crusher;

  final Map<String, int> summary;

  MixerInputs({
    required this.broker,
    required this.bb,
    required this.washing,
    required this.gilingan,
    required this.mixer,
    required this.crusher,
    required this.summary,
  });

  factory MixerInputs.fromJson(Map<String, dynamic> j) {
    List<T> _listOf<T>(dynamic v, T Function(Map<String, dynamic>) f) {
      final list = (v ?? []) as List;
      return list.map<T>((e) => f(Map<String, dynamic>.from(e as Map))).toList();
    }

    Map<String, int> _toSummary(dynamic v) {
      final m = Map<String, dynamic>.from((v ?? {}) as Map);
      return m.map((k, v) => MapEntry(k, asInt(v) ?? 0));
    }

    return MixerInputs(
      broker: _listOf(j['broker'], (m) => BrokerItem.fromJson(m)),
      bb: _listOf(j['bb'], (m) => BbItem.fromJson(m)),
      washing: _listOf(j['washing'], (m) => WashingItem.fromJson(m)),
      gilingan: _listOf(j['gilingan'], (m) => GilinganItem.fromJson(m)),
      mixer: _listOf(j['mixer'], (m) => MixerItem.fromJson(m)),
      crusher: _listOf(j['crusher'], (m) => CrusherItem.fromJson(m)),
      summary: _toSummary(j['summary']),
    );
  }

  double totalBeratBroker() => broker.fold(0.0, (s, it) => s + (it.berat ?? 0));
  double totalBeratBb() => bb.fold(0.0, (s, it) => s + (it.berat ?? 0));
  double totalBeratWashing() => washing.fold(0.0, (s, it) => s + (it.berat ?? 0));
  double totalBeratGilingan() => gilingan.fold(0.0, (s, it) => s + (it.berat ?? 0));
  double totalBeratMixer() => mixer.fold(0.0, (s, it) => s + (it.berat ?? 0));
  double totalBeratCrusher() => crusher.fold(0.0, (s, it) => s + (it.berat ?? 0));

  double totalBerat() =>
      totalBeratBroker() +
      totalBeratBb() +
      totalBeratWashing() +
      totalBeratGilingan() +
      totalBeratMixer() +
      totalBeratCrusher();

  int totalItems() =>
      broker.length +
      bb.length +
      washing.length +
      gilingan.length +
      mixer.length +
      crusher.length;

  bool get isEmpty =>
      broker.isEmpty &&
      bb.isEmpty &&
      washing.isEmpty &&
      gilingan.isEmpty &&
      mixer.isEmpty &&
      crusher.isEmpty;

  bool get isNotEmpty => !isEmpty;

  MixerInputs copyWith({
    List<BrokerItem>? broker,
    List<BbItem>? bb,
    List<WashingItem>? washing,
    List<GilinganItem>? gilingan,
    List<MixerItem>? mixer,
    List<CrusherItem>? crusher,
    Map<String, int>? summary,
  }) {
    return MixerInputs(
      broker: broker ?? this.broker,
      bb: bb ?? this.bb,
      washing: washing ?? this.washing,
      gilingan: gilingan ?? this.gilingan,
      mixer: mixer ?? this.mixer,
      crusher: crusher ?? this.crusher,
      summary: summary ?? this.summary,
    );
  }

  factory MixerInputs.empty() {
    return MixerInputs(
      broker: [],
      bb: [],
      washing: [],
      gilingan: [],
      mixer: [],
      crusher: [],
      summary: {},
    );
  }

  int countBroker() => summary['broker'] ?? broker.length;
  int countBb() => summary['bb'] ?? bb.length;
  int countWashing() => summary['washing'] ?? washing.length;
  int countGilingan() => summary['gilingan'] ?? gilingan.length;
  int countMixer() => summary['mixer'] ?? mixer.length;
  int countCrusher() => summary['crusher'] ?? crusher.length;
}