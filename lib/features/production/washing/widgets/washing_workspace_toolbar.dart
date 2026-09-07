import 'package:flutter/material.dart';

import '../../shared/shared.dart';

const _kWashingPrimary = Color(0xFF0277BD);

class WashingWorkspaceToolbar extends StatelessWidget {
  final String? noProduksi;
  final bool isLocked;
  final String? namaJenis;
  final DateTime? tglProduksi;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;
  final int? idMesin;
  final VoidCallback? onRefresh;
  final VoidCallback? onGanti;
  final VoidCallback? onRiwayat;
  final bool showGantiRiwayat;
  final VoidCallback? onComplete;
  final VoidCallback? onUncomplete;
  final String? completeDisabledReason;
  final String? produksiStatus;

  const WashingWorkspaceToolbar({
    super.key,
    this.noProduksi,
    required this.isLocked,
    this.namaJenis,
    this.tglProduksi,
    this.shift,
    this.hourStart,
    this.hourEnd,
    this.idMesin,
    this.onRefresh,
    this.onGanti,
    this.onRiwayat,
    this.showGantiRiwayat = true,
    this.onComplete,
    this.onUncomplete,
    this.completeDisabledReason,
    this.produksiStatus,
  });

  @override
  Widget build(BuildContext context) {
    return ProductionWorkspaceToolbar(
      noProduksi: noProduksi,
      isLocked: isLocked,
      idMesin: idMesin,
      shift: shift,
      tglProduksi: tglProduksi,
      hourStart: hourStart,
      hourEnd: hourEnd,
      namaJenis: namaJenis,
      primaryColor: _kWashingPrimary,
      onGanti: onGanti,
      onRiwayat: onRiwayat,
      onRefresh: onRefresh,
      showGantiRiwayat: showGantiRiwayat,
      onComplete: onComplete,
      onUncomplete: onUncomplete,
      completeDisabledReason: completeDisabledReason,
      produksiStatus: produksiStatus,
    );
  }
}
