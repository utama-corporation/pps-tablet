import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../repository/mixer_production_input_repository.dart';

const _kOutput = Color(0xFF00796B); // teal — output
const _kBorder = Color(0xFFE2E6EA);

class MixerProductionOutputFormDialog extends StatefulWidget {
  final String noProduksi;
  final DateTime? tglProduksi;
  final int idJenis;
  final String namaJenis;
  final String? namaMesin;
  final MixerProductionInputRepository repository;

  const MixerProductionOutputFormDialog({
    super.key,
    required this.noProduksi,
    required this.idJenis,
    required this.namaJenis,
    required this.repository,
    this.tglProduksi,
    this.namaMesin,
  });

  @override
  State<MixerProductionOutputFormDialog> createState() =>
      _MixerProductionOutputFormDialogState();
}

class _MixerProductionOutputFormDialogState
    extends State<MixerProductionOutputFormDialog> {
  final _beratCtrl = TextEditingController();
  final _jumlahCtrl = TextEditingController();
  String? _beratErr;
  String? _jumlahErr;
  static const int _maxSak = 999;

  final List<_SakEntry> _details = [];
  bool _isSaving = false;
  String? _saveError;

  int get _totalSak => _details.length;
  double get _totalBerat => _details.fold(0.0, (s, e) => s + (e.berat ?? 0.0));
  int get _remaining => (_maxSak - _totalSak).clamp(0, _maxSak);

  int _nextSakNo() {
    if (_details.isEmpty) return 1;
    return _details.map((e) => e.noSak).reduce((a, b) => a > b ? a : b) + 1;
  }

  @override
  void dispose() {
    _beratCtrl.dispose();
    _jumlahCtrl.dispose();
    super.dispose();
  }

  void _commitAdd() {
    final berat = double.tryParse(_beratCtrl.text.trim());
    final jumlah = int.tryParse(_jumlahCtrl.text.trim());

    setState(() {
      _beratErr = (berat == null || berat <= 0) ? 'Harus > 0' : null;
      _jumlahErr = jumlah == null || jumlah <= 0
          ? 'Minimal 1'
          : jumlah > _remaining
              ? 'Maks $_remaining'
              : null;
    });

    if (_beratErr != null || _jumlahErr != null) return;

    setState(() {
      final start = _nextSakNo();
      for (var i = 0; i < jumlah!; i++) {
        _details.add(_SakEntry(noSak: start + i, berat: berat));
      }
      _jumlahCtrl.clear();
      _beratErr = null;
      _jumlahErr = null;
      _saveError = null;
    });
  }

  void _deleteDetail(int index) => setState(() => _details.removeAt(index));

  Future<void> _save() async {
    if (_details.isEmpty) {
      setState(() => _saveError = 'Tambah minimal 1 sak terlebih dahulu.');
      return;
    }

    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      final noMixer = await widget.repository.createMixerLabel(
        noProduksi: widget.noProduksi,
        idMixer: widget.idJenis,
        dateCreate: widget.tglProduksi ?? DateTime.now(),
        details: _details
            .map((e) => {'NoSak': e.noSak, 'Berat': e.berat})
            .toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(noMixer);
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
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: _kBorder),
            _buildInfoBar(tglText),
            const Divider(height: 1, color: _kBorder),
            _buildInputRow(),
            const Divider(height: 1, color: _kBorder),
            Expanded(child: _buildSakList()),
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
              color: _kOutput.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.blender_outlined, color: _kOutput, size: 17),
          ),
          const SizedBox(width: 10),
          const Text(
            'Tambah Label Mixer',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
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
          _InfoChip(icon: Icons.receipt_long_outlined, label: 'No Produksi', value: widget.noProduksi),
          if (widget.namaMesin != null && widget.namaMesin!.isNotEmpty)
            _InfoChip(icon: Icons.precision_manufacturing_outlined, label: 'Mesin', value: widget.namaMesin!),
          _InfoChip(icon: Icons.calendar_today_outlined, label: 'Tanggal', value: tglText),
          _InfoChip(icon: Icons.category_outlined, label: 'Jenis', value: widget.namaJenis),
        ],
      ),
    );
  }

  Widget _buildInputRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _InlineField(
                  controller: _beratCtrl,
                  label: 'Berat per sak (kg)',
                  icon: Icons.scale_outlined,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  errorText: _beratErr,
                  onChanged: (_) => setState(() => _beratErr = null),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12, left: 10, right: 10),
                child: Text('×', style: TextStyle(fontSize: 18, color: Colors.grey.shade400)),
              ),
              Expanded(
                child: _InlineField(
                  controller: _jumlahCtrl,
                  label: 'Jumlah sak',
                  icon: Icons.inventory_2_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  errorText: _jumlahErr,
                  onChanged: (_) => setState(() => _jumlahErr = null),
                  onSubmitted: (_) => _commitAdd(),
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _commitAdd,
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Tambah', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kOutput,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_remaining < _maxSak && _remaining > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Sisa kuota: $_remaining sak',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ),
        ],
      ),
    );
  }

  Widget _buildSakList() {
    if (_details.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade300),
            const SizedBox(height: 6),
            Text('Belum ada sak', style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (_, c) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: c.maxWidth < 300 ? 3 : (c.maxWidth < 400 ? 4 : 5),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 1.3,
        ),
        itemCount: _details.length,
        itemBuilder: (_, i) => _SakCard(entry: _details[i], onDelete: () => _deleteDetail(i)),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 6, 18, 0),
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
          Expanded(child: Text(_saveError!, style: TextStyle(fontSize: 12, color: Colors.red.shade700))),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kOutput.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _kOutput.withValues(alpha: 0.2)),
            ),
            child: Text(
              '$_totalSak sak  ·  ${_totalBerat.toStringAsFixed(2)} kg',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kOutput),
            ),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Batal', style: TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 13, height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 15),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Simpan',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOutput,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _SakCard extends StatelessWidget {
  final _SakEntry entry;
  final VoidCallback onDelete;
  const _SakCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kOutput.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _kOutput.withValues(alpha: 0.25)),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Sak ${entry.noSak}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _kOutput)),
                const SizedBox(height: 3),
                Text('${entry.berat?.toStringAsFixed(2) ?? '-'} kg',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              ],
            ),
          ),
          Positioned(
            top: 3, right: 3,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 16, height: 16,
                decoration: BoxDecoration(color: Colors.red.shade400, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SakEntry {
  final int noSak;
  final double? berat;
  const _SakEntry({required this.noSak, this.berat});
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text('$label: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F2937))),
      ],
    );
  }
}

class _InlineField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType keyboardType;
  final List<TextInputFormatter> inputFormatters;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _InlineField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.keyboardType,
    required this.inputFormatters,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 15),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        errorText: errorText,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(9)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: const BorderSide(color: _kOutput, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide(color: Colors.red.shade400)),
      ),
    );
  }
}
