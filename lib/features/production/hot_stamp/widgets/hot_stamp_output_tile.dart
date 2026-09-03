import 'package:flutter/material.dart';

import '../../shared/shared.dart';
import '../model/hot_stamp_output_model.dart';

const _kStampOutput = Color(0xFF00796B);
const _kStampBorder = Color(0xFFE2E6EA);

// ── Output tile ───────────────────────────────────────────────────────────────

class HotStampOutputTile extends StatelessWidget {
  final HotStampOutput output;
  final VoidCallback? onTap;

  const HotStampOutputTile({super.key, required this.output, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kStampBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            onTap ??
            () => showDialog<void>(
              context: context,
              builder: (_) => HotStampOutputDetailDialog(output: output),
            ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      output.namaJenis.isNotEmpty
                          ? output.namaJenis
                          : output.labelCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D23),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.print_outlined,
                    size: 11,
                    color: output.hasBeenPrinted
                        ? _kStampOutput
                        : Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                output.labelCode,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  if (!output.isReject)
                    ProductionMiniMetric(
                      icon: Icons.inventory_2_outlined,
                      text: '${output.pcs} pcs',
                    ),
                  if (output.berat > 0)
                    ProductionMiniMetric(
                      icon: Icons.scale_outlined,
                      text: '${num2(output.berat)} kg',
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Summary tile ──────────────────────────────────────────────────────────────

class HotStampOutputSummaryTile extends StatelessWidget {
  final int totalLabel;
  final int totalPcs;

  const HotStampOutputSummaryTile({
    super.key,
    required this.totalLabel,
    required this.totalPcs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kStampOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kStampOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: _kStampOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'PCS',
            value: '$totalPcs',
            color: _kStampOutput,
          ),
        ],
      ),
    );
  }
}

// ── Grand total bar ───────────────────────────────────────────────────────────

class HotStampOutputOverallSummaryBar extends StatelessWidget {
  final int totalLabel;
  final int totalFwipPcs;
  final double totalRejectBerat;

  const HotStampOutputOverallSummaryBar({
    super.key,
    required this.totalLabel,
    required this.totalFwipPcs,
    required this.totalRejectBerat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              const Icon(
                Icons.summarize_outlined,
                size: 13,
                color: _kStampOutput,
              ),
              const SizedBox(width: 5),
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kStampOutput,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Label',
                value: '$totalLabel',
                color: _kStampOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'PCS',
                value: '$totalFwipPcs',
                color: _kStampOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Berat',
                value: '${num2(totalRejectBerat)} kg',
                color: _kStampOutput,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HotStampOutputGrandTotalBar extends StatelessWidget {
  final int totalLabel;
  final int totalPcs;

  const HotStampOutputGrandTotalBar({
    super.key,
    required this.totalLabel,
    required this.totalPcs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(
            children: [
              const Icon(Icons.summarize_outlined,
                  size: 13, color: _kStampOutput),
              const SizedBox(width: 5),
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kStampOutput,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Label',
                value: '$totalLabel',
                color: _kStampOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'PCS',
                value: '$totalPcs',
                color: _kStampOutput,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Detail dialog ─────────────────────────────────────────────────────────────

class HotStampOutputDetailDialog extends StatelessWidget {
  final HotStampOutput output;

  const HotStampOutputDetailDialog({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: _kStampOutput,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          output.namaJenis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          output.labelCode,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.print_outlined,
                            size: 12, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          output.hasBeenPrinted ? 'Printed' : 'Belum Print',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close,
                        color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kStampBorder),
            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: _InfoCell(
                      label: output.codeLabel,
                      value: output.labelCode,
                    ),
                  ),
                  Expanded(
                    child: _InfoCell(
                      label: 'PCS',
                      value: '${output.pcs} pcs',
                    ),
                  ),
                  if (output.berat > 0)
                    Expanded(
                      child: _InfoCell(
                        label: 'Berat',
                        value: '${num2(output.berat)} kg',
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kStampBorder),
            // Footer
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kStampBorder),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;

  const _InfoCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
        const SizedBox(height: 3),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
