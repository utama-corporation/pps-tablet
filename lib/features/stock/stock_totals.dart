import '../production/shared/repository/barang_jadi_stok_repository.dart';
import '../production/shared/repository/bonggolan_stok_repository.dart';
import '../production/shared/repository/broker_stok_repository.dart';
import '../production/shared/repository/crusher_stok_repository.dart';
import '../production/shared/repository/furniture_wip_stok_repository.dart';
import '../production/shared/repository/gilingan_stok_repository.dart';
import '../production/shared/repository/mixer_stok_repository.dart';
import '../production/shared/repository/reject_stok_repository.dart';
import '../production/shared/repository/stok_bahan_baku_pakai_repository.dart';
import '../production/shared/repository/stok_bahan_baku_repository.dart';
import '../production/shared/repository/washing_stok_repository.dart';
import '../production/shared/repository/inject_stok_repository.dart';
import '../production/shared/repository/stamping_stock_repository.dart';
import '../production/shared/repository/spanner_stock_repository.dart';
import '../production/shared/repository/bahan_pendukung_stok_repository.dart';
import '../production/shared/repository/packing_produksi_repository.dart';
import 'stock_proses_key.dart';

enum StockAmountUnit { kg, pcs }

/// Total keseluruhan (jumlah label + berat/pcs) untuk satu proses,
/// dijumlah dari seluruh jenis (dan, untuk Bahan Baku, dari kedua sumber
/// "Proses" + "Pakai") — dipakai sebagai ringkasan pada kartu proses di
/// [StockSelectionScreen].
class StockProsesTotals {
  const StockProsesTotals({
    required this.labelSisa,
    required this.amount,
    required this.unit,
  });

  final int labelSisa;
  final double amount;
  final StockAmountUnit unit;
}

Future<StockProsesTotals> fetchStockProsesTotals(StockProsesKey key) async {
  switch (key) {
    case StockProsesKey.washing:
      final items = await WashingStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.broker:
      final items = await BrokerStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.crusher:
      final items = await CrusherStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.bonggolan:
      final items = await BonggolanStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.gilingan:
      final items = await GilinganStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.mixer:
      final items = await MixerStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.reject:
      final items = await RejectStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.furnitureWip:
      final items = await FurnitureWipStokRepository().fetchStok();
      final labelSisa = items.fold<int>(0, (sum, i) => sum + i.labelSisa);
      final pcs = items.fold<int>(0, (sum, i) => sum + i.pcsSisa);
      return StockProsesTotals(
        labelSisa: labelSisa,
        amount: pcs.toDouble(),
        unit: StockAmountUnit.pcs,
      );
    case StockProsesKey.barangJadi:
      final items = await BarangJadiStokRepository().fetchStok();
      final labelSisa = items.fold<int>(0, (sum, i) => sum + i.labelSisa);
      final pcs = items.fold<int>(0, (sum, i) => sum + i.pcsSisa);
      return StockProsesTotals(
        labelSisa: labelSisa,
        amount: pcs.toDouble(),
        unit: StockAmountUnit.pcs,
      );
    case StockProsesKey.bahanBaku:
      final results = await Future.wait([
        StokBahanBakuRepository().fetchStok(),
        StokBahanBakuPakaiRepository().fetchStok(),
      ]);
      final items = [...results[0], ...results[1]];
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);


    case StockProsesKey.bahanBakuPakai:
      final items = await StokBahanBakuPakaiRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.bahanBakuProses:
      final items = await StokBahanBakuRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.wipInject:
      final items = await InjectStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.wipStamping:
      final items = await StampingStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.wipSpanner:
      final items = await SpannerStokRepository().fetchStok();
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.bahanPendukung:
      final items = await BahanPendukungStokRepository().fetchStok();
      final labelSisa = items.fold<int>(0, (sum, i) => sum + i.labelSisa);
      final qty = items.fold<int>(0, (sum, i) => sum + i.qtySisa);
      return StockProsesTotals(
        labelSisa: labelSisa,
        amount: qty.toDouble(),
        unit: StockAmountUnit.pcs,
      );
    case StockProsesKey.barangJadiGrande:
      final items = await PackingProduksiRepository().fetchStok(type: 'GRANDE');
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.barangJadiHana:
      final items = await PackingProduksiRepository().fetchStok(type: 'HANA');
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.barangJadiKursi:
      final items = await PackingProduksiRepository().fetchStok(type: 'PART KURSI');
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
    case StockProsesKey.barangJadiEnamel:
      final items = await PackingProduksiRepository().fetchStok(type: 'ENAMEL');
      return _sumBerat(items, (i) => i.labelSisa, (i) => i.beratSisa);
  }
}

StockProsesTotals _sumBerat<T>(
  List<T> items,
  int Function(T item) labelSisaOf,
  double Function(T item) beratSisaOf,
) {
  final labelSisa = items.fold<int>(0, (sum, i) => sum + labelSisaOf(i));
  final beratSisa = items.fold<double>(0, (sum, i) => sum + beratSisaOf(i));
  return StockProsesTotals(
    labelSisa: labelSisa,
    amount: beratSisa,
    unit: StockAmountUnit.kg,
  );
}
