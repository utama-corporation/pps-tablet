// lib/features/production/crusher/widgets/crusher_output_tile.dart
import 'package:flutter/material.dart';
import '../../shared/shared.dart';
import '../../shared/widgets/production_output_detail_dialog.dart';
import '../../../label/crusher/repository/crusher_repository.dart';
import '../../../../core/network/endpoints.dart';
import '../model/crusher_output_model.dart';

const _kCrusherOutput = Color(0xFF00796B);
const _kCrusherBorder = Color(0xFFE2E6EA);

// ── Output tile ───────────────────────────────────────────────────────────────

class CrusherOutputTile extends StatelessWidget {
  final CrusherOutput output;

  const CrusherOutputTile({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCrusherBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => ProductionOutputDetailDialog(
            labelCode: output.noCrusher,
            namaJenis: output.namaJenis,
            printCount: output.hasBeenPrinted,
            accentColor: _kCrusherOutput,
            pdfUrl: ApiConstants.crusherLabelPdf(output.noCrusher),
            feature: 'crusher',
            markAsPrinted: () => CrusherRepository().markAsPrinted(output.noCrusher),
            metrics: [
              ProductionMetric(
                icon: Icons.scale_outlined,
                text: '${num2(output.berat)} kg',
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      output.namaJenis.isNotEmpty
                          ? output.namaJenis
                          : output.noCrusher,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1D23),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '×${output.hasBeenPrinted}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: output.hasBeenPrinted > 0
                          ? _kCrusherOutput
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.print_outlined,
                    size: 11,
                    color: output.hasBeenPrinted > 0
                        ? _kCrusherOutput
                        : Colors.grey.shade400,
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                output.noCrusher,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
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

class CrusherOutputSummaryTile extends StatelessWidget {
  final int totalLabel;
  final double totalBerat;

  const CrusherOutputSummaryTile({
    super.key,
    required this.totalLabel,
    required this.totalBerat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kCrusherOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kCrusherOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: _kCrusherOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Berat',
            value: '${num2(totalBerat)} kg',
            color: _kCrusherOutput,
          ),
        ],
      ),
    );
  }
}

// ── Grand total bar ───────────────────────────────────────────────────────────

class CrusherOutputGrandTotalBar extends StatelessWidget {
  final int totalLabel;
  final double totalBerat;

  const CrusherOutputGrandTotalBar({
    super.key,
    required this.totalLabel,
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
                color: _kCrusherOutput,
              ),
              const SizedBox(width: 5),
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kCrusherOutput,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Label',
                value: '$totalLabel',
                color: _kCrusherOutput,
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Berat',
                value: '${num2(totalBerat)} kg',
                color: _kCrusherOutput,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

