import 'package:flutter/material.dart';

import '../../../production/inject/model/inject_production_model.dart';

/// Dot indikator status mesin.
/// - Gunakan [active] (bool) untuk modul yang hanya punya 2 state.
/// - Gunakan [machineStatus] untuk inject yang punya 3 state (active/pending/inactive).
class ProductionStatusDot extends StatelessWidget {
  const ProductionStatusDot({
    super.key,
    this.active,
    this.machineStatus,
  });

  final bool? active;
  final MachineStatus? machineStatus;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (machineStatus != null) {
      color = switch (machineStatus!) {
        // Aktif = current / sedang berjalan → biru
        MachineStatus.active => const Color(0xFF2563EB),
        MachineStatus.pending => const Color(0xFFD97706),
        MachineStatus.inactive => const Color(0xFFDC2626),
      };
    } else {
      color = (active ?? false) ? const Color(0xFF2563EB) : const Color(0xFFDC2626);
    }

    return Container(
      width: 7,
      height: 7,
      margin: const EdgeInsets.only(top: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
