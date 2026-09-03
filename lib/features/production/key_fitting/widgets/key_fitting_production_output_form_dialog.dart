import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../label/furniture_wip/repository/furniture_wip_repository.dart';
import '../../../label/furniture_wip/view_model/furniture_wip_view_model.dart';

const _kAccent = Color(0xFF00796B); // teal — output
const _kBorder = Color(0xFFE2E6EA);

class KeyFittingProductionOutputFormDialog extends StatelessWidget {
  final String noProduksi;
  final DateTime? tglProduksi;
  final int? outputJenisId;
  final String? namaJenis;

  const KeyFittingProductionOutputFormDialog({
    super.key,
    required this.noProduksi,
    this.tglProduksi,
    this.outputJenisId,
    this.namaJenis,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FurnitureWipViewModel(repository: FurnitureWipRepository()),
      child: _Body(
        noProduksi: noProduksi,
        tglProduksi: tglProduksi,
        outputJenisId: outputJenisId,
        namaJenis: namaJenis,
      ),
    );
  }
}

class _Body extends StatefulWidget {
  final String noProduksi;
  final DateTime? tglProduksi;
  final int? outputJenisId;
  final String? namaJenis;

  const _Body({
    required this.noProduksi,
    this.tglProduksi,
    this.outputJenisId,
    this.namaJenis,
  });

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  final _pcsCtrl = TextEditingController();
  String? _pcsErr;
  String? _saveError;
  bool _isSaving = false;

  @override
  void dispose() {
    _pcsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pcsRaw = _pcsCtrl.text.trim().replaceAll(',', '.');
    final pcs = double.tryParse(pcsRaw);
    setState(() {
      _pcsErr = (pcs == null || pcs <= 0) ? 'PCS harus > 0' : null;
      _saveError = null;
    });
    if (_pcsErr != null) return;

    setState(() => _isSaving = true);
    try {
      final vm = context.read<FurnitureWipViewModel>();
      await vm.createFromForm(
        idFurnitureWip: widget.outputJenisId,
        dateCreate: widget.tglProduksi ?? DateTime.now(),
        pcs: pcs!,
        berat: null,
        isPartial: false,
        idWarna: null,
        blok: null,
        idLokasi: null,
        mode: FurnitureWipInputMode.pasangKunci,
        pasangKunciCode: widget.noProduksi,
        toDbDateString: toDbDateString,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tglText = widget.tglProduksi == null
        ? '-'
        : DateFormat('dd MMM yyyy', 'id_ID').format(widget.tglProduksi!.toLocal());

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: _kBorder),
            _buildInfoBar(tglText),
            const Divider(height: 1, color: _kBorder),
            _buildBody(),
            if (_saveError != null) _buildErrorBanner(),
            const Divider(height: 1, color: _kBorder),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 13, 12, 13),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _kAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.key_outlined, color: _kAccent, size: 17),
          ),
          const SizedBox(width: 10),
          const Text(
            'Tambah Output Pasang Kunci',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF9CA3AF)),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBar(String tglText) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Wrap(
        spacing: 18,
        runSpacing: 6,
        children: [
          _InfoChip(
            icon: Icons.receipt_long_outlined,
            label: 'No Produksi',
            value: widget.noProduksi,
          ),
          _InfoChip(
            icon: Icons.calendar_today_outlined,
            label: 'Tanggal',
            value: tglText,
          ),
          _InfoChip(
            icon: Icons.category_outlined,
            label: 'Jenis',
            value: widget.namaJenis ?? '-',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: TextField(
        controller: _pcsCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        autofocus: true,
        onChanged: (_) => setState(() => _pcsErr = null),
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: 'PCS',
          prefixIcon: const Icon(Icons.filter_1_outlined, size: 16),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          errorText: _pcsErr,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _kBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _kAccent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 15, color: Colors.red.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _saveError!,
              style: TextStyle(fontSize: 12, color: Colors.red.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Batal', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 15),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Simpan',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }
}
