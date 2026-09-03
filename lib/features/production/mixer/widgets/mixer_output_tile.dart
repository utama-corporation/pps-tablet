import 'package:flutter/material.dart';
import '../../shared/shared.dart';
import '../../shared/widgets/production_output_detail_dialog.dart';
import '../../../label/mixer/repository/mixer_repository.dart';
import '../../../../core/network/endpoints.dart';
import '../model/mixer_output_model.dart';

const _kMixerOutput = Color(0xFF1565C0);
const _kMixerBorder = Color(0xFFE2E6EA);

// ── Output tile ───────────────────────────────────────────────────────────────

class MixerOutputTile extends StatelessWidget {
  final MixerOutput output;

  const MixerOutputTile({super.key, required this.output});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kMixerBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => ProductionOutputDetailDialog(
            labelCode: output.noMixer,
            namaJenis: output.namaJenis,
            printCount: output.hasPrinted,
            accentColor: _kMixerOutput,
            pdfUrl: ApiConstants.mixerLabelPdf(output.noMixer),
            feature: 'mixer',
            markAsPrinted: () => MixerRepository().markAsPrinted(output.noMixer),
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      output.namaJenis.isNotEmpty ? output.namaJenis : output.noMixer,
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1A1D23),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.print_outlined, size: 11,
                      color: output.hasPrinted > 0 ? _kMixerOutput : Colors.grey.shade400),
                  const SizedBox(width: 2),
                  Text(
                    'x${output.hasPrinted}',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: output.hasPrinted > 0 ? _kMixerOutput : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(output.noMixer,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6, runSpacing: 2,
                children: [
                  ProductionMiniMetric(icon: Icons.inventory_2_outlined, text: '${output.totalSak} sak'),
                  ProductionMiniMetric(icon: Icons.scale_outlined, text: '${num2(output.totalBerat)} kg'),
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

class MixerOutputSummaryTile extends StatelessWidget {
  final int totalLabel;
  final int totalSak;
  final double totalBerat;

  const MixerOutputSummaryTile({
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
        color: _kMixerOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kMixerOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(label: 'Label', value: '$totalLabel', color: _kMixerOutput),
          const SizedBox(width: 10),
          ProductionInlineStat(label: 'Sak', value: '$totalSak', color: _kMixerOutput),
          const SizedBox(width: 10),
          ProductionInlineStat(label: 'Berat', value: '${num2(totalBerat)} kg', color: _kMixerOutput),
        ],
      ),
    );
  }
}

// ── Grand total bar ───────────────────────────────────────────────────────────

class MixerOutputGrandTotalBar extends StatelessWidget {
  final int totalLabel;
  final int totalSak;
  final double totalBerat;

  const MixerOutputGrandTotalBar({
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
              const Icon(Icons.summarize_outlined, size: 13, color: _kMixerOutput),
              const SizedBox(width: 5),
              const Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kMixerOutput)),
              const SizedBox(width: 10),
              ProductionInlineStat(label: 'Label', value: '$totalLabel', color: _kMixerOutput),
              const SizedBox(width: 10),
              ProductionInlineStat(label: 'Sak', value: '$totalSak', color: _kMixerOutput),
              const SizedBox(width: 10),
              ProductionInlineStat(label: 'Berat', value: '${num2(totalBerat)} kg', color: _kMixerOutput),
            ],
          ),
        ),
      ],
    );
  }
}
