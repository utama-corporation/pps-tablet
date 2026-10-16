// lib/features/inject_production/models/inject_production_inputs_model.dart

import '../../shared/models/broker_item.dart';
import '../../shared/models/mixer_item.dart';
import '../../shared/models/gilingan_item.dart';
import '../../shared/models/crusher_item.dart';
import '../../shared/models/furniture_wip_item.dart';
import '../../shared/models/cabinet_material_item.dart';
import '../../../../core/utils/model_helpers.dart';

// ✅ Export item models agar bisa diakses lewat satu import
export '../../shared/models/broker_item.dart';
export '../../shared/models/mixer_item.dart';
export '../../shared/models/gilingan_item.dart';
export '../../shared/models/crusher_item.dart';
export '../../shared/models/furniture_wip_item.dart';
export '../../shared/models/cabinet_material_item.dart';

/* ===================== ROOT AGGREGATOR ===================== */

class InjectProductionInputs {
  final List<BrokerItem> broker;
  final List<MixerItem> mixer;
  final List<GilinganItem> gilingan;
  final List<CrusherItem> crusher;
  final List<FurnitureWipItem> furnitureWip;
  final List<CabinetMaterialItem> cabinetMaterial;

  final Map<String, int> summary;

  InjectProductionInputs({
    required this.broker,
    required this.mixer,
    required this.gilingan,
    required this.crusher,
    required this.furnitureWip,
    required this.cabinetMaterial,
    required this.summary,
  });

  factory InjectProductionInputs.fromJson(Map<String, dynamic> j) {
    List<T> _listOf<T>(dynamic v, T Function(Map<String, dynamic>) f) {
      final list = (v ?? []) as List;
      return list
          .map<T>((e) => f(Map<String, dynamic>.from(e as Map)))
          .toList();
    }

    Map<String, int> _toSummary(dynamic v) {
      final m = Map<String, dynamic>.from((v ?? {}) as Map);
      return m.map((k, v) => MapEntry(k, asInt(v) ?? 0));
    }

    return InjectProductionInputs(
      broker: _listOf(j['broker'], (m) => BrokerItem.fromJson(m)),
      mixer: _listOf(j['mixer'], (m) => MixerItem.fromJson(m)),
      gilingan: _listOf(j['gilingan'], (m) => GilinganItem.fromJson(m)),
      crusher: _listOf(j['crusher'], (m) => CrusherItem.fromJson(m)),
      furnitureWip: _listOf(
        j['furnitureWip'],
        (m) => FurnitureWipItem.fromJson(m),
      ),
      cabinetMaterial: _listOf(
        j['cabinetMaterial'],
        (m) => CabinetMaterialItem.fromJson(m),
      ),
      summary: _toSummary(j['summary']),
    );
  }

  // ============ TOTAL BERAT BY CATEGORY ============

  double totalBeratBroker() => broker.fold(0.0, (s, it) => s + (it.berat ?? 0));

  double totalBeratMixer() => mixer.fold(0.0, (s, it) => s + (it.berat ?? 0));

  double totalBeratGilingan() =>
      gilingan.fold(0.0, (s, it) => s + (it.berat ?? 0));

  double totalBeratCrusher() =>
      crusher.fold(0.0, (s, it) => s + (it.berat ?? 0));

  double totalBeratFurnitureWip() =>
      furnitureWip.fold(0.0, (s, it) => s + (it.berat ?? 0));

  // ============ TOTAL PCS ============

  int totalPcsFurnitureWip() =>
      furnitureWip.fold(0, (s, it) => s + (it.pcs ?? 0));

  int totalPcsMaterial() =>
      cabinetMaterial.fold(0, (s, it) => s + (it.pcs ?? 0));

  // ============ GRAND TOTALS ============

  /// Total berat semua input (Broker + Mixer + Gilingan + Crusher + FurnitureWIP)
  double totalBerat() =>
      totalBeratBroker() +
      totalBeratMixer() +
      totalBeratGilingan() +
      totalBeratCrusher() +
      totalBeratFurnitureWip();

  /// Total items count (all categories)
  int totalItems() =>
      broker.length +
      mixer.length +
      gilingan.length +
      crusher.length +
      furnitureWip.length +
      cabinetMaterial.length;

  // ============ EMPTY CHECK ============

  bool get isEmpty =>
      broker.isEmpty &&
      mixer.isEmpty &&
      gilingan.isEmpty &&
      crusher.isEmpty &&
      furnitureWip.isEmpty &&
      cabinetMaterial.isEmpty;

  bool get isNotEmpty => !isEmpty;

  // ============ COPY WITH ============

  InjectProductionInputs copyWith({
    List<BrokerItem>? broker,
    List<MixerItem>? mixer,
    List<GilinganItem>? gilingan,
    List<CrusherItem>? crusher,
    List<FurnitureWipItem>? furnitureWip,
    List<CabinetMaterialItem>? cabinetMaterial,
    Map<String, int>? summary,
  }) {
    return InjectProductionInputs(
      broker: broker ?? this.broker,
      mixer: mixer ?? this.mixer,
      gilingan: gilingan ?? this.gilingan,
      crusher: crusher ?? this.crusher,
      furnitureWip: furnitureWip ?? this.furnitureWip,
      cabinetMaterial: cabinetMaterial ?? this.cabinetMaterial,
      summary: summary ?? this.summary,
    );
  }

  // ============ FACTORY ============

  factory InjectProductionInputs.empty() {
    return InjectProductionInputs(
      broker: [],
      mixer: [],
      gilingan: [],
      crusher: [],
      furnitureWip: [],
      cabinetMaterial: [],
      summary: {},
    );
  }

  // ============ SUMMARY GETTERS ============

  int countBroker() => summary['broker'] ?? broker.length;
  int countMixer() => summary['mixer'] ?? mixer.length;
  int countGilingan() => summary['gilingan'] ?? gilingan.length;
  int countCrusher() => summary['crusher'] ?? crusher.length;
  int countFurnitureWip() => summary['furnitureWip'] ?? furnitureWip.length;
  int countCabinetMaterial() =>
      summary['cabinetMaterial'] ?? cabinetMaterial.length;

  // ============ PARTIAL GROUPING (per category) ============

  // Broker
  List<BrokerItem> get fullBroker =>
      broker.where((it) => !it.isPartialRow).toList();
  List<BrokerItem> get partialBroker =>
      broker.where((it) => it.isPartialRow).toList();

  // Mixer
  List<MixerItem> get fullMixer =>
      mixer.where((it) => !it.isPartialRow).toList();
  List<MixerItem> get partialMixer =>
      mixer.where((it) => it.isPartialRow).toList();

  // Gilingan
  List<GilinganItem> get fullGilingan =>
      gilingan.where((it) => !it.isPartialRow).toList();
  List<GilinganItem> get partialGilingan =>
      gilingan.where((it) => it.isPartialRow).toList();

  // Crusher (selalu full, tidak mendukung partial)
  List<CrusherItem> get fullCrusher => crusher;

  // FurnitureWIP
  List<FurnitureWipItem> get fullFurnitureWip =>
      furnitureWip.where((it) => !it.isPartialRow).toList();
  List<FurnitureWipItem> get partialFurnitureWip =>
      furnitureWip.where((it) => it.isPartialRow).toList();

  // ============ COUNT BY MODE (Full vs Partial) ============

  int get totalFullItems =>
      fullBroker.length +
      fullMixer.length +
      fullGilingan.length +
      fullCrusher.length +
      fullFurnitureWip.length +
      cabinetMaterial.length; // material tidak ada partial

  int get totalPartialItems =>
      partialBroker.length +
      partialMixer.length +
      partialGilingan.length +
      partialFurnitureWip.length;

  // ============ CATEGORY GROUPING ============

  /// Group all items by category for UI display
  Map<String, List<dynamic>> get groupedByCategory => {
    'Broker': broker,
    'Mixer': mixer,
    'Gilingan': gilingan,
    'Crusher': crusher,
    'Furniture WIP': furnitureWip,
    'Cabinet Material': cabinetMaterial,
  };

  /// Get non-empty categories only
  Map<String, List<dynamic>> get nonEmptyCategories => Map.fromEntries(
    groupedByCategory.entries.where((e) => e.value.isNotEmpty),
  );
}
