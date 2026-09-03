// lib/features/production/washing/widgets/washing_output_tile.dart
//
// Tile kartu untuk satu item output washing (di grid panel output).
// Tap → dialog detail sak.
// Format identik dengan broker _BrokerOutputTile.

import 'package:flutter/material.dart';
import '../../shared/shared.dart';
import '../../shared/widgets/production_output_detail_dialog.dart';
import '../../../label/washing/repository/washing_repository.dart';
import '../../../../core/network/endpoints.dart';
import '../model/washing_output_model.dart';

const _kWashingOutput = Color(0xFF00796B); // teal output
const _kWashingBorder = Color(0xFFE2E6EA);

// ── Output tile ───────────────────────────────────────────────────────────────

class WashingOutputTile extends StatelessWidget {
  final WashingOutput output;
  final VoidCallback? onTap;

  final bool canPrint;

  const WashingOutputTile({
    super.key,
    required this.output,
    this.onTap,
    this.canPrint = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kWashingBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            onTap ??
            () => showDialog<void>(
          context: context,
          builder: (_) => ProductionOutputDetailDialog(
            labelCode: output.noWashing,
            namaJenis: output.namaJenis,
            printCount: output.hasPrinted,
            accentColor: _kWashingOutput,
            pdfUrl: ApiConstants.washingLabelPdf(output.noWashing),
            feature: 'washing',
            canPrint: canPrint,
            markAsPrinted: () => WashingRepository().markAsPrinted(output.noWashing),
            metrics: [
              ProductionMetric(
                icon: Icons.inventory_2_outlined,
                text: '${output.totalSak} sak',
              ),
              ProductionMetric(
                icon: Icons.scale_outlined,
                text: '${num2(output.totalBerat)} kg',
              ),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Title row: noWashing + print count
              Row(
                children: [
                  Expanded(
                    child: Text(
                      output.namaJenis.isNotEmpty
                          ? output.namaJenis
                          : output.noWashing,
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
                    color: output.hasPrinted > 0
                        ? _kWashingOutput
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'x${output.hasPrinted}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: output.hasPrinted > 0
                          ? _kWashingOutput
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              // Nomor label subtitle
              Text(
                output.noWashing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              // Metrics
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  ProductionMiniMetric(
                    icon: Icons.inventory_2_outlined,
                    text: '${output.totalSak} sak',
                  ),
                  ProductionMiniMetric(
                    icon: Icons.scale_outlined,
                    text: '${num2(output.totalBerat)} kg',
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

class WashingOutputSummaryTile extends StatelessWidget {
  final int totalLabel;
  final int totalSak;
  final double totalBerat;

  const WashingOutputSummaryTile({
    super.key,
    required this.totalLabel,
    required this.totalSak,
    required this.totalBerat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kWashingOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kWashingOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: _kWashingOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Sak',
            value: '$totalSak',
            color: _kWashingOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Berat',
            value: '${num2(totalBerat)} kg',
            color: _kWashingOutput,
          ),
        ],
      ),
    );
  }
}

// ── Grand total bar (di bawah category block, format identik broker) ──────────

class WashingOutputGrandTotalBar extends StatelessWidget {
  final int totalLabel;
  final int totalSak;
  final double totalBerat;

  const WashingOutputGrandTotalBar({
    super.key,
    required this.totalLabel,
    required this.totalSak,
    required this.totalBerat,
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
                color: _kWashingOutput,
              ),
              const SizedBox(width: 5),
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kWashingOutput,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Label',
                value: '$totalLabel',
                color: _kWashingOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Sak',
                value: '$totalSak',
                color: _kWashingOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Berat',
                value: '${num2(totalBerat)} kg',
                color: _kWashingOutput,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

