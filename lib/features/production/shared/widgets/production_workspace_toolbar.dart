import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'marquee_text.dart';

class ProductionWorkspaceToolbar extends StatelessWidget {
  final String? noProduksi;
  final bool isLocked;
  final int? idMesin;
  final int? shift;
  final DateTime? tglProduksi;
  final String? hourStart;
  final String? hourEnd;
  final String? namaJenis;
  final String? namaCetakan;
  final String? namaWarna;
  final String? namaFurnitureMaterial;
  final List<String>? namaJenisList;
  final Color primaryColor;

  final bool showTimeInfo;
  final VoidCallback? onGanti;
  // Jika diset, tombol Ganti tetap tampil tapi disabled; pesan muncul saat long-press
  final String? gantiDisabledReason;
  final VoidCallback? onTerminate;
  // Jika diset, tombol Terminate tetap tampil tapi disabled; pesan muncul saat long-press
  final String? terminateDisabledReason;
  final VoidCallback? onComplete;
  // Label + ikon tombol aksi "selesai" (default: "Selesai" / centang). Beberapa
  // modul memakai istilah berbeda, mis. mixer pakai "Kunci" / gembok.
  final String completeLabel;
  final IconData completeIcon;
  // Jika diset (dan tidak ada completeDisabledReason/approve/pending), tombol
  // di slot "Selesai" berubah jadi tombol amber pemanggil callback ini —
  // dipakai saat produksi sudah complete untuk membalik statusnya.
  final VoidCallback? onUncomplete;
  final String uncompleteLabel;
  final IconData uncompleteIcon;
  // Jika diset, tombol Selesai tetap tampil tapi disabled; pesan muncul saat long-press
  final String? completeDisabledReason;
  // Jika diset, tombol Selesai tampil amber (menunggu) dengan ikon jam; tooltip dari sini
  final String? completePendingReason;
  // Approval actions — muncul saat CompleteRequestStatus == 'PENDING'
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onRiwayat;
  final VoidCallback? onRefresh;
  final List<Widget>? trailingActions;
  final bool showGantiRiwayat;
  final String? produksiStatus;

  const ProductionWorkspaceToolbar({
    super.key,
    this.noProduksi,
    required this.isLocked,
    required this.primaryColor,
    this.idMesin,
    this.shift,
    this.tglProduksi,
    this.hourStart,
    this.hourEnd,
    this.namaJenis,
    this.namaCetakan,
    this.namaWarna,
    this.namaFurnitureMaterial,
    this.namaJenisList,
    this.showTimeInfo = true,
    this.onGanti,
    this.gantiDisabledReason,
    this.onTerminate,
    this.terminateDisabledReason,
    this.onComplete,
    this.completeLabel = 'Kunci',
    this.completeIcon = Icons.lock_outline,
    this.onUncomplete,
    this.uncompleteLabel = 'Buka Kunci',
    this.uncompleteIcon = Icons.lock_open_outlined,
    this.completeDisabledReason,
    this.completePendingReason,
    this.onApprove,
    this.onReject,
    this.onRiwayat,
    this.onRefresh,
    this.trailingActions,
    this.showGantiRiwayat = true,
    this.produksiStatus,
  });

  bool _isWithinTimeRange() {
    final now = DateTime.now();
    final hStart = (hourStart ?? '').trim();
    final hEnd = (hourEnd ?? '').trim();
    if (tglProduksi == null) return false;

    final isToday =
        tglProduksi!.year == now.year &&
        tglProduksi!.month == now.month &&
        tglProduksi!.day == now.day;
    if (!isToday) return false;
    if (hStart.isEmpty && hEnd.isEmpty) return false;

    int toMin(String hhmm) {
      final p = hhmm.split(':');
      if (p.length < 2) return -1;
      final h = int.tryParse(p[0]) ?? -1;
      final m = int.tryParse(p[1]) ?? -1;
      if (h < 0 || m < 0) return -1;
      return h * 60 + m;
    }

    final nowMin = now.hour * 60 + now.minute;
    final startMin = hStart.isNotEmpty ? toMin(hStart) : 0;
    final endMin = hEnd.isNotEmpty ? toMin(hEnd) : 23 * 60 + 59;
    if (startMin < 0 || endMin < 0) return false;
    if (endMin < startMin) return nowMin >= startMin || nowMin <= endMin;
    return nowMin >= startMin && nowMin <= endMin;
  }

  @override
  Widget build(BuildContext context) {
    const activeAccent = Color(0xFF00897B);
    const pastAccent = Color(0xFFF59E0B);
    const lockedAccent = Color(0xFFF97316);
    const borderColor = Color(0xFFE2E6EA);

    final tglText = tglProduksi == null
        ? null
        : DateFormat('dd MMM yyyy', 'id_ID').format(tglProduksi!.toLocal());

    final hStart = (hourStart ?? '').trim();
    final hEnd = (hourEnd ?? '').trim();
    final isActive = !isLocked && _isWithinTimeRange();
    final hasJenis = (namaJenis ?? '').trim().isNotEmpty;
    final canGanti = isActive && idMesin != null && shift != null && tglProduksi != null;

    final hasJenisList =
        namaJenisList != null && namaJenisList!.isNotEmpty;
    final hasCetakanInfo = !hasJenisList &&
        ((namaCetakan ?? '').trim().isNotEmpty ||
            (namaWarna ?? '').trim().isNotEmpty ||
            (namaFurnitureMaterial ?? '').trim().isNotEmpty);

    final accentColor = isLocked
        ? lockedAccent
        : switch (produksiStatus) {
            'current' => const Color(0xFF2563EB), // realtime → biru
            'complete' => const Color(0xFF059669), // complete → hijau
            'pending' => const Color(0xFFF59E0B), // pending → kuning
            _ => isActive ? activeAccent : pastAccent,
          };
    final statusLabel = isLocked
        ? 'Locked'
        : switch (produksiStatus) {
            'current' => 'Real-Time',
            'pending' => 'Pending',
            'complete' => 'Complete',
            _ => isActive ? 'Real-Time' : 'Pending',
          };
    final statusIcon = isLocked
        ? Icons.lock_outline
        : switch (produksiStatus) {
            'current' => Icons.play_circle_outline,
            'complete' => Icons.check_circle_outline,
            _ => isActive ? Icons.play_circle_outline : Icons.history_rounded,
          };
    final jamText = (hStart.isNotEmpty || hEnd.isNotEmpty)
        ? '${hStart.isNotEmpty ? hStart : "--:--"} – ${hEnd.isNotEmpty ? hEnd : "--:--"}'
        : '-- : --';

    Widget infoTag(IconData icon, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: Colors.grey.shade400),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    Widget dot() => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade300,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget vline() => Container(
      width: 1,
      height: 18,
      color: Colors.grey.shade200,
      margin: const EdgeInsets.symmetric(horizontal: 10),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: accentColor, width: 4)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 10, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              vline(),
              if (hasJenisList)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (int i = 0; i < namaJenisList!.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        Flexible(
                          child: _InfoChip(
                            icon: Icons.inventory_2_outlined,
                            label: namaJenisList![i].trim(),
                            color: accentColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              else if (hasCetakanInfo)
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((namaCetakan ?? '').trim().isNotEmpty) ...[
                        Flexible(
                          child: _InfoChip(
                            icon: Icons.view_in_ar_rounded,
                            label: namaCetakan!.trim(),
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if ((namaWarna ?? '').trim().isNotEmpty) ...[
                        Flexible(
                          child: _InfoChip(
                            icon: Icons.palette_outlined,
                            label: namaWarna!.trim(),
                            color: accentColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      if ((namaFurnitureMaterial ?? '').trim().isNotEmpty)
                        Flexible(
                          child: _InfoChip(
                            icon: Icons.category_outlined,
                            label: namaFurnitureMaterial!.trim(),
                            color: accentColor,
                          ),
                        ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: Text(
                    hasJenis ? namaJenis!.trim() : 'Belum ada jenis',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasJenis ? accentColor : Colors.grey.shade400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (showGantiRiwayat && canGanti) ...[
                const SizedBox(width: 4),
                if (gantiDisabledReason != null)
                  Tooltip(
                    message: gantiDisabledReason!,
                    triggerMode: TooltipTriggerMode.longPress,
                    showDuration: const Duration(seconds: 3),
                    child: Material(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 13, color: Color(0xFF9CA3AF)),
                            SizedBox(width: 4),
                            Text(
                              'Ganti',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Material(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: onGanti,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swap_horiz_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Ganti',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (onTerminate != null || terminateDisabledReason != null) ...[
                  const SizedBox(width: 4),
                  if (terminateDisabledReason != null)
                    Tooltip(
                      message: terminateDisabledReason!,
                      triggerMode: TooltipTriggerMode.longPress,
                      showDuration: const Duration(seconds: 3),
                      child: Material(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stop_circle_outlined, size: 13, color: Color(0xFF9CA3AF)),
                              SizedBox(width: 4),
                              Text(
                                'Terminate',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Material(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        onTap: onTerminate,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.stop_circle_outlined, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Terminate',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
              if (showGantiRiwayat && canGanti) ...[
                const SizedBox(width: 6),
                Material(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    onTap: onRiwayat,
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.timeline_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Riwayat',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (onComplete != null ||
                  completeDisabledReason != null ||
                  completePendingReason != null ||
                  onApprove != null ||
                  onUncomplete != null) ...[
                const SizedBox(width: 6),
                if (completeDisabledReason != null)
                  Tooltip(
                    message: completeDisabledReason!,
                    triggerMode: TooltipTriggerMode.longPress,
                    showDuration: const Duration(seconds: 3),
                    child: Material(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(completeIcon, size: 13, color: const Color(0xFF9CA3AF)),
                            const SizedBox(width: 4),
                            Text(
                              completeLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (onApprove != null) ...[
                  Material(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: onApprove,
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Setujui',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (onReject != null) ...[
                    const SizedBox(width: 6),
                    Material(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        onTap: onReject,
                        borderRadius: BorderRadius.circular(6),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Tolak',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ]
                else if (completePendingReason != null)
                  Tooltip(
                    message: completePendingReason!,
                    triggerMode: TooltipTriggerMode.longPress,
                    showDuration: const Duration(seconds: 3),
                    child: Material(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.access_time, size: 13, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'Menunggu',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else if (onUncomplete != null)
                  Material(
                    color: const Color(0xFFD97706),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: onUncomplete,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(uncompleteIcon, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              uncompleteLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Material(
                    color: const Color(0xFF059669),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: onComplete,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(completeIcon, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              completeLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              if (showTimeInfo) ...[
                vline(),
                if (tglText != null) ...[
                  infoTag(Icons.calendar_today_outlined, tglText),
                  dot(),
                ],
                if (shift != null) ...[
                  infoTag(Icons.group_outlined, 'Shift $shift'),
                  dot(),
                ],
                infoTag(Icons.schedule_outlined, jamText),
              ],
              const Spacer(),
              if ((noProduksi ?? '').isNotEmpty) ...[
                Text(
                  noProduksi!,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(width: 2),
              ],
              if (onRefresh != null)
                SizedBox(
                  width: 26,
                  height: 26,
                  child: IconButton(
                    tooltip: 'Refresh',
                    padding: EdgeInsets.zero,
                    onPressed: onRefresh,
                    icon: Icon(
                      Icons.refresh,
                      size: 15,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              if (trailingActions != null) ...trailingActions!,
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Flexible(
            child: MarqueeText(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
