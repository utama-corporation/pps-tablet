import 'package:flutter/material.dart';

import '../../../production/inject/model/inject_production_model.dart';
import 'production_small_info_row.dart';
import 'production_status_dot.dart';

class MesinCardData {
  final String namaMesin;
  final bool isActive;

  /// Opsional — hanya diisi oleh inject production (3 state).
  /// Modul lain cukup pakai [isActive].
  final MachineStatus? machineStatus;

  final String? shiftTimeText;
  final String? namaRegu;
  final String? namaOperators;
  final String? outputJenisNama;
  final String? namaCetakan;
  final String? namaWarna;
  final String? namaFurnitureMaterial;
  final VoidCallback? onQcTap;

  const MesinCardData({
    required this.namaMesin,
    required this.isActive,
    this.machineStatus,
    this.shiftTimeText,
    this.namaRegu,
    this.namaOperators,
    this.outputJenisNama,
    this.namaCetakan,
    this.namaWarna,
    this.namaFurnitureMaterial,
    this.onQcTap,
  });

  bool get isPending => machineStatus == MachineStatus.pending;
  bool get hasProduction => isActive || isPending;
}

class ProductionMesinCard extends StatelessWidget {
  const ProductionMesinCard({
    super.key,
    required this.data,
    required this.onTap,
    this.onLongPress,
  });

  final MesinCardData data;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color? bgColor;

    if (data.machineStatus != null) {
      switch (data.machineStatus!) {
        case MachineStatus.active:
          // Aktif = current / sedang berjalan → biru
          borderColor = const Color(0xFF93C5FD);
          bgColor = null;
        case MachineStatus.pending:
          borderColor = const Color(0xFFFCD34D);
          bgColor = const Color(0xFFFFFBEB);
        case MachineStatus.inactive:
          borderColor = const Color(0xFFFCA5A5);
          bgColor = null;
      }
    } else {
      borderColor = data.isActive ? const Color(0xFF93C5FD) : const Color(0xFFFCA5A5);
      bgColor = null;
    }

    final showInfo = data.machineStatus != null ? data.hasProduction : data.isActive;

    return Material(
      color: bgColor ?? Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: bgColor ?? Colors.white,
            border: Border.all(color: borderColor, width: 1.2),
          ),
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      data.namaMesin,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (data.isActive && data.onQcTap != null)
                    GestureDetector(
                      onTap: data.onQcTap,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0277BD).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: const Icon(
                          Icons.checklist_outlined,
                          size: 13,
                          color: Color(0xFF0277BD),
                        ),
                      ),
                    ),
                  if (data.isActive && data.onQcTap != null)
                    const SizedBox(width: 4),
                  data.machineStatus != null
                      ? ProductionStatusDot(machineStatus: data.machineStatus)
                      : ProductionStatusDot(active: data.isActive),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 6),
              if (showInfo) ...[
                if (data.shiftTimeText != null && data.shiftTimeText!.isNotEmpty)
                  ProductionSmallInfoRow(
                    icon: Icons.access_time_outlined,
                    text: data.shiftTimeText!,
                    bold: true,
                  ),
                if ((data.namaRegu ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ProductionSmallInfoRow(
                    icon: Icons.groups_outlined,
                    text: data.namaRegu!,
                  ),
                ],
                if ((data.namaOperators ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ProductionSmallInfoRow(
                    icon: Icons.person_outline,
                    text: data.namaOperators!.trim(),
                    maxLines: 2,
                  ),
                ],
                if ((data.namaCetakan ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ProductionSmallInfoRow(
                    icon: Icons.view_in_ar_rounded,
                    text: data.namaCetakan!.trim(),
                    color: const Color(0xFF374151),
                  ),
                ],
                if ((data.namaWarna ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ProductionSmallInfoRow(
                    icon: Icons.palette_outlined,
                    text: data.namaWarna!.trim(),
                    color: const Color(0xFF374151),
                  ),
                ],
                if ((data.namaFurnitureMaterial ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ProductionSmallInfoRow(
                    icon: Icons.category_outlined,
                    text: data.namaFurnitureMaterial!.trim(),
                    color: const Color(0xFF374151),
                  ),
                ] else if ((data.outputJenisNama ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  ProductionSmallInfoRow(
                    icon: Icons.inventory_2_outlined,
                    text: data.outputJenisNama!.trim(),
                    color: const Color(0xFF374151),
                    maxLines: 3,
                    bold: true,
                  ),
                ],
              ] else
                const Text(
                  'Belum aktif',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFFB91C1C),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
