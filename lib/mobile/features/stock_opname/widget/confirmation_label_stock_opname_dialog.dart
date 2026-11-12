import 'package:flutter/material.dart';
import '../model/label_validation_result.dart';

class ConfirmationLabelStockOpnameSheet extends StatelessWidget {
  final String label;
  final LabelValidationResult result;
  final VoidCallback onConfirm;
  final VoidCallback onManualInput;

  const ConfirmationLabelStockOpnameSheet({
    super.key,
    required this.label,
    required this.result,
    required this.onConfirm,
    required this.onManualInput,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final maxHeight = mq.size.height * 0.5; // up to 50% of screen height

    // Nilai dari backend (null dianggap 0)
    final int qty = result.jmlhSak ?? 0;
    final double berat = result.berat ?? 0;

    // ❗ Aturan:
    // - Qty TIDAK BOLEH 0 / null  → qty > 0
    // - Berat juga harus > 0      → berat > 0
    // => Keduanya WAJIB > 0 baru boleh "Simpan Data"
    final bool canSave = qty > 0 && berat > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(100),
              ),
            ),

            // title
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Konfirmasi Label',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            // content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusBox(result),
                    const SizedBox(height: 16),

                    const Text(
                      'Detail Data',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    ..._buildInfoRow('Label', label),
                    ..._buildInfoRow('Jenis', result.labelType),
                    ..._buildInfoRow('Qty', qty > 0 ? '$qty' : '-'),
                    ..._buildInfoRow(
                      'Berat',
                      berat > 0 ? '${berat.toStringAsFixed(2)} kg' : '-',
                    ),
                    ..._buildInfoRow(
                      'Lokasi',
                      '${result.blok ?? ''}${result.idLokasi ?? '-'}',
                    ),

                    if (result.mesinInfo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(),
                      const Text(
                        'Data Mesin',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      for (final mesin in result.mesinInfo) ...[
                        ..._buildInfoRow('Mesin', mesin.namaMesin),
                        ..._buildInfoRow('Operator', mesin.namaOperator),
                        const Divider(height: 12),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            // action bar pinned at bottom
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black.withOpacity(0.05),
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: onManualInput,
                    child: const Text('Ubah'),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: canSave ? onConfirm : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      canSave ? Colors.blue[900] : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Simpan Data'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🟩 Determine color/icon scheme based on validation flags
  ({
  Color bg,
  Color border,
  Color text,
  IconData icon,
  }) _getStatusStyle(LabelValidationResult r) {
    // 🔴 Highest priority: label already in stock opname (invalid)
    // (ikuti kondisi yang kamu punya)
    if (r.foundInStockOpname == false) {
      return (
      bg: Colors.red.withOpacity(0.1),
      border: Colors.red.withOpacity(0.3),
      text: Colors.red.shade800,
      icon: Icons.cancel,
      );
    }

    // 🟡 Warning: invalid category or warehouse mismatch
    if (r.isValidCategory == false || r.isValidWarehouse == false) {
      return (
      bg: Colors.amber.withOpacity(0.1),
      border: Colors.amber.withOpacity(0.3),
      text: Colors.amber.shade800,
      icon: Icons.warning,
      );
    }

    // 🟢 All valid
    return (
    bg: Colors.green.withOpacity(0.1),
    border: Colors.green.withOpacity(0.3),
    text: Colors.green.shade800,
    icon: Icons.check_circle,
    );
  }

  // 🟦 Builds the colored status notification box
  Widget _buildStatusBox(LabelValidationResult result) {
    final style = _getStatusStyle(result);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: style.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(style.icon, color: style.text, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              result.message,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: style.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🟧 Builds info rows (label + value)
  List<Widget> _buildInfoRow(String label, String value) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                '$label:',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
