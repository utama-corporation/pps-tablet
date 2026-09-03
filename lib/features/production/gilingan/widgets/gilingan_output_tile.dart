import 'package:flutter/material.dart';
import '../../shared/shared.dart';
import '../../shared/widgets/production_output_detail_dialog.dart';
import '../../../label/gilingan/repository/gilingan_repository.dart';
import '../../../../core/network/endpoints.dart';
import '../model/gilingan_output_model.dart';

const _kGilinganOutput = Color(0xFF00796B);
const _kGilinganBorder = Color(0xFFE2E6EA);

class GilinganOutputTile extends StatelessWidget {
  final GilinganOutput output;
  final VoidCallback? onTap;
  final bool canPrint;

  const GilinganOutputTile({
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
        border: Border.all(color: _kGilinganBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap:
            onTap ??
            () => showDialog<void>(
          context: context,
          builder: (_) => ProductionOutputDetailDialog(
            labelCode: output.noGilingan,
            namaJenis: output.namaJenis,
            printCount: output.hasPrinted,
            accentColor: _kGilinganOutput,
            pdfUrl: ApiConstants.gilinganLabelPdf(output.noGilingan),
            feature: 'gilingan',
            canPrint: canPrint,
            markAsPrinted: () => GilinganRepository().markAsPrinted(output.noGilingan),
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
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      output.namaJenis.isNotEmpty
                          ? output.namaJenis
                          : output.noGilingan,
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
                        ? _kGilinganOutput
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'x${output.hasPrinted}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: output.hasPrinted > 0
                          ? _kGilinganOutput
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 1),
              Text(
                output.noGilingan,
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

class GilinganOutputSummaryTile extends StatelessWidget {
  final int totalLabel;
  final double totalBerat;

  const GilinganOutputSummaryTile({
    super.key,
    required this.totalLabel,
    required this.totalBerat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _kGilinganOutput.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kGilinganOutput.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          ProductionInlineStat(
            label: 'Label',
            value: '$totalLabel',
            color: _kGilinganOutput,
          ),
          const SizedBox(width: 10),
          ProductionInlineStat(
            label: 'Berat',
            value: '${num2(totalBerat)} kg',
            color: _kGilinganOutput,
          ),
        ],
      ),
    );
  }
}

class GilinganOutputGrandTotalBar extends StatelessWidget {
  final int totalLabel;
  final double totalBerat;

  const GilinganOutputGrandTotalBar({
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
              const Icon(Icons.summarize_outlined, size: 13, color: _kGilinganOutput),
              const SizedBox(width: 5),
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kGilinganOutput,
                ),
              ),
              const SizedBox(width: 10),
              ProductionInlineStat(label: 'Label', value: '$totalLabel', color: _kGilinganOutput),
              const SizedBox(width: 10),
              ProductionInlineStat(
                label: 'Berat',
                value: '${num2(totalBerat)} kg',
                color: _kGilinganOutput,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

