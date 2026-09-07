import 'package:flutter/material.dart';

import '../../shared/shared.dart';

const _kBrokerPrimary = Color(0xFF1E6FD9);

class BrokerWorkspaceToolbar extends StatelessWidget {
  final String? noProduksi;
  final int? idMesin;
  final int? shift;
  final DateTime? tglProduksi;
  final bool isLocked;
  final String? hourStart;
  final String? hourEnd;
  final String? namaJenis;
  final VoidCallback? onGanti;
  final VoidCallback? onTimeline;
  final VoidCallback? onRefresh;
  final bool showGantiRiwayat;
  final VoidCallback? onComplete;
  final VoidCallback? onUncomplete;
  final String? completeDisabledReason;
  final String? produksiStatus;

  const BrokerWorkspaceToolbar({
    super.key,
    this.noProduksi,
    required this.isLocked,
    this.idMesin,
    this.shift,
    this.tglProduksi,
    this.hourStart,
    this.hourEnd,
    this.namaJenis,
    this.onGanti,
    this.onTimeline,
    this.onRefresh,
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
      primaryColor: _kBrokerPrimary,
      onGanti: onGanti,
      onRiwayat: onTimeline,
      onRefresh: onRefresh,
      showGantiRiwayat: showGantiRiwayat,
      onComplete: onComplete,
      onUncomplete: onUncomplete,
      completeDisabledReason: completeDisabledReason,
      produksiStatus: produksiStatus,
    );
  }
}
