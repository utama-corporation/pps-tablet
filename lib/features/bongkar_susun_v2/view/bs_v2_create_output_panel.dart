part of 'bs_v2_create_screen.dart';

// ─── Outputs Panel ─────────────────────────────────────────────────────────

class _OutputsPanel extends StatelessWidget {
  final BsV2CreateViewModel vm;
  final NumberFormat nf;
  final TextEditingController Function(String outputId, double current)
  beratCtlOf;
  final TextEditingController Function(String key, double current)
  sakBeratCtlOf;

  const _OutputsPanel({
    required this.vm,
    required this.nf,
    required this.beratCtlOf,
    required this.sakBeratCtlOf,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(
        borderColor: const Color(0xFF0A7349).withValues(alpha: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: LayoutBuilder(
              builder: (context, c) {
                // Sembunyikan label tombol saat header sempit (mis. panel
                // output menyusut di layar kecil) supaya tidak overflow.
                final compact = c.maxWidth < 320;
                final canAdd = vm.inputs.isNotEmpty && !vm.allJenisAllocated;
                final addButton = Tooltip(
                  message: vm.inputs.isNotEmpty && vm.allJenisAllocated
                      ? 'Semua jenis sudah terpenuhi'
                      : (compact ? 'Tambah Output' : ''),
                  child: Material(
                    color: canAdd
                        ? const Color(0xFF0A7349)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      onTap: canAdd ? vm.addOutput : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 8 : 14,
                          vertical: 7,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add,
                              size: 15,
                              color: canAdd
                                  ? Colors.white
                                  : Colors.grey.shade400,
                            ),
                            if (!compact) ...[
                              const SizedBox(width: 4),
                              Text(
                                'Tambah Output',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: canAdd
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );

                return Row(
                  children: [
                    Flexible(
                      child: _sectionHeader(
                        Icons.output_rounded,
                        'Output',
                        iconColor: const Color(0xFF0A7349),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (vm.outputs.isNotEmpty && !compact) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A7349).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${vm.outputs.length} label',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A7349),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    addButton,
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1, color: _kBorder),
          Expanded(
            child: Builder(
              builder: (context) {
                final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                if (vm.outputs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_box_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          vm.inputs.isEmpty
                              ? 'Masukkan label input terlebih dahulu'
                              : 'Tekan "Tambah Output" untuk mulai',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Padding(
                  padding: EdgeInsets.only(bottom: bottomInset),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: vm.outputs.length,
                    itemBuilder: (_, i) {
                      final out = vm.outputs[i];
                      return _OutputCard(
                        key: ValueKey(out.id),
                        entry: out,
                        index: i,
                        vm: vm,
                        nf: nf,
                        beratCtlOf: beratCtlOf,
                        sakBeratCtlOf: sakBeratCtlOf,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Output Card ───────────────────────────────────────────────────────────

class _OutputCard extends StatelessWidget {
  final OutputEntry entry;
  final int index;
  final BsV2CreateViewModel vm;
  final NumberFormat nf;
  final TextEditingController Function(String, double) beratCtlOf;
  final TextEditingController Function(String, double) sakBeratCtlOf;

  const _OutputCard({
    super.key,
    required this.entry,
    required this.index,
    required this.vm,
    required this.nf,
    required this.beratCtlOf,
    required this.sakBeratCtlOf,
  });

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: _kPrimary, width: 1.5),
    ),
    filled: true,
    fillColor: _kSurface,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  );

  @override
  Widget build(BuildContext context) {
    final isValid = vm.outputIsValid(entry);
    final remaining = vm.remainingByJenis;
    // Hide jenis that are already balanced, unless this output is currently using it
    final jenisOptions = vm.jenisOptions.where((j) {
      final rem = remaining[j.idJenis] ?? 0.0;
      final balanced = rem.abs() < 0.001;
      return !balanced || entry.idJenis == j.idJenis;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _cardDecoration(
        borderColor: isValid ? _kBorder : Colors.red.shade300,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isValid ? const Color(0xFFF0FDF4) : Colors.red.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(_kRadius),
              ),
              border: Border(
                bottom: BorderSide(
                  color: isValid
                      ? const Color(0xFFD1FAE5)
                      : Colors.red.shade200,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isValid
                        ? const Color(0xFF0A7349)
                        : Colors.red.shade400,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Output #${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (entry.totalBerat > 0)
                  Text(
                    '${nf.format(entry.totalBerat)} kg',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isValid
                          ? const Color(0xFF0A7349)
                          : Colors.red.shade700,
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: () => vm.removeOutput(entry.id),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.red.shade400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Card body
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Jenis dropdown
                InputDecorator(
                  decoration: _fieldDecoration('Jenis').copyWith(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: DropdownButton<int>(
                    value: entry.idJenis,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A1D23),
                    ),
                    items: () {
                      final result = <DropdownMenuItem<int>>[];
                      for (int i = 0; i < jenisOptions.length; i++) {
                        final j = jenisOptions[i];
                        result.add(
                          DropdownMenuItem(
                            value: j.idJenis,
                            child: Text(j.namaJenis),
                          ),
                        );
                        if (i < jenisOptions.length - 1) {
                          result.add(
                            DropdownMenuItem(
                              enabled: false,
                              value: -(i + 1),
                              child: const Divider(height: 1, thickness: 1),
                            ),
                          );
                        }
                      }
                      return result;
                    }(),
                    onChanged: (val) {
                      if (val == null || val < 0) return;
                      final jenis = jenisOptions.firstWhere(
                        (j) => j.idJenis == val,
                      );
                      vm.updateOutputJenis(entry.id, val, jenis.namaJenis);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // Saks (washing / broker)
                if (vm.hasSaks) ...[
                  Row(
                    children: [
                      const Text(
                        'Sak',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D23),
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => vm.addSak(entry.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _kPrimary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.add, size: 13, color: _kPrimary),
                              SizedBox(width: 3),
                              Text(
                                '1 Sak',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () async {
                          await showDialog<void>(
                            context: context,
                            builder: (_) => _BulkSakDialog(
                              outputId: entry.id,
                              currentSakCount: entry.saks.length,
                              vm: vm,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF0A7349,
                            ).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.playlist_add_rounded,
                                size: 13,
                                color: Color(0xFF0A7349),
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Massal',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A7349),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (entry.saks.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            size: 14,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Wajib minimal 1 sak',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ...entry.saks.map((sak) {
                      final key = '${entry.id}_${sak.id}';
                      // Max = remaining for this jenis + this sak's current berat
                      final sakMax =
                          (vm.remainingByJenis[entry.idJenis] ?? 0.0) +
                          sak.berat;
                      final ctl = sakBeratCtlOf(key, sak.berat);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 60,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _kPrimary.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _kPrimary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                'Sak ${sak.noSak}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: ctl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9.]'),
                                  ),
                                ],
                                decoration: _fieldDecoration('Berat (kg)')
                                    .copyWith(
                                      suffixIcon: sakMax > 0
                                          ? _MaxButton(
                                              onTap: () {
                                                final v = sakMax
                                                    .toStringAsFixed(3)
                                                    .replaceAll(
                                                      RegExp(r'\.?0+$'),
                                                      '',
                                                    );
                                                ctl.text = v;
                                                vm.updateSak(
                                                  entry.id,
                                                  sak.id,
                                                  berat: sakMax,
                                                );
                                              },
                                            )
                                          : null,
                                    ),
                                onTap: () {
                                  Future.delayed(
                                    const Duration(milliseconds: 350),
                                    () {
                                      if (context.mounted) {
                                        Scrollable.ensureVisible(
                                          context,
                                          duration: const Duration(
                                            milliseconds: 250,
                                          ),
                                          curve: Curves.easeInOut,
                                          alignment: 1.0,
                                        );
                                      }
                                    },
                                  );
                                },
                                onChanged: (v) {
                                  final d = double.tryParse(v);
                                  if (d != null) {
                                    vm.updateSak(entry.id, sak.id, berat: d);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => vm.removeSak(entry.id, sak.id),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: Colors.red.shade400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],

                // Single quantity field (bonggolan / crusher / gilingan / furnitureWip)
                if (!vm.hasSaks)
                  Builder(
                    builder: (context) {
                      final ctl = beratCtlOf(entry.id, entry.berat);
                      final maxVal =
                          (vm.remainingByJenis[entry.idJenis] ?? 0.0) +
                          entry.berat;
                      return TextField(
                        controller: ctl,
                        keyboardType: vm.isPcsCategory
                            ? TextInputType.number
                            : const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                        inputFormatters: [
                          vm.isPcsCategory
                              ? FilteringTextInputFormatter.digitsOnly
                              : FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                        ],
                        decoration:
                            _fieldDecoration(
                              vm.isPcsCategory ? 'Pcs' : 'Berat (kg)',
                            ).copyWith(
                              suffixIcon: maxVal > 0
                                  ? _MaxButton(
                                      onTap: () {
                                        final v = vm.isPcsCategory
                                            ? maxVal.toInt().toString()
                                            : maxVal
                                                  .toStringAsFixed(3)
                                                  .replaceAll(
                                                    RegExp(r'\.?0+$'),
                                                    '',
                                                  );
                                        ctl.text = v;
                                        vm.updateOutputBerat(
                                          entry.id,
                                          vm.isPcsCategory
                                              ? maxVal.toInt().toDouble()
                                              : maxVal,
                                        );
                                      },
                                    )
                                  : null,
                            ),
                        onTap: () {
                          Future.delayed(const Duration(milliseconds: 350), () {
                            if (context.mounted) {
                              Scrollable.ensureVisible(
                                context,
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeInOut,
                                alignment: 1.0,
                              );
                            }
                          });
                        },
                        onChanged: (v) {
                          final d = double.tryParse(v);
                          if (d != null) vm.updateOutputBerat(entry.id, d);
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Max Button ────────────────────────────────────────────────────────────

class _MaxButton extends StatelessWidget {
  final VoidCallback onTap;
  const _MaxButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _kPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Max',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: _kPrimary,
            height: 3,
          ),
        ),
      ),
    );
  }
}

// ─── Bulk Sak Dialog ───────────────────────────────────────────────────────

class _BulkSakDialog extends StatefulWidget {
  final String outputId;
  final int currentSakCount;
  final BsV2CreateViewModel vm;

  const _BulkSakDialog({
    required this.outputId,
    required this.currentSakCount,
    required this.vm,
  });

  @override
  State<_BulkSakDialog> createState() => _BulkSakDialogState();
}

class _BulkSakDialogState extends State<_BulkSakDialog> {
  final TextEditingController _jumlahCtl = TextEditingController();
  final TextEditingController _beratCtl = TextEditingController();
  String? _jumlahError;
  String? _beratError;

  @override
  void dispose() {
    _jumlahCtl.dispose();
    _beratCtl.dispose();
    super.dispose();
  }

  void _confirm() {
    final jumlah = int.tryParse(_jumlahCtl.text.trim());
    final berat = double.tryParse(_beratCtl.text.trim());
    setState(() {
      _jumlahError = jumlah == null || jumlah <= 0
          ? 'Masukkan jumlah sak yang valid'
          : null;
      _beratError = berat == null || berat <= 0
          ? 'Masukkan berat yang valid'
          : null;
    });
    if (_jumlahError != null || _beratError != null) return;
    widget.vm.addSakBulk(widget.outputId, jumlah!, berat!);
    Navigator.of(context).pop();
  }

  InputDecoration _dec(String label, String hint, {String? error}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        errorStyle: const TextStyle(fontSize: 11),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
        filled: true,
        fillColor: _kSurface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final jumlah = int.tryParse(_jumlahCtl.text.trim()) ?? 0;
    final berat = double.tryParse(_beratCtl.text.trim()) ?? 0.0;
    final preview = jumlah > 0 && berat > 0;
    final nf = NumberFormat('#,##0.##', 'id_ID');
    final nextNo = widget.currentSakCount + 1;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A7349).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.playlist_add_rounded,
                      color: Color(0xFF0A7349),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tambah Sak Massal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1D23),
                        ),
                      ),
                      Text(
                        'Buat banyak sak sekaligus',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Fields
              TextField(
                controller: _jumlahCtl,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: _dec(
                  'Jumlah Sak',
                  'contoh: 20',
                  error: _jumlahError,
                ),
                onChanged: (_) => setState(() => _jumlahError = null),
                onSubmitted: (_) => FocusScope.of(context).nextFocus(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _beratCtl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: _dec(
                  'Berat per Sak (kg)',
                  'contoh: 10',
                  error: _beratError,
                ),
                onChanged: (_) => setState(() => _beratError = null),
                onSubmitted: (_) => _confirm(),
              ),
              // Preview
              if (preview) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD1FAE5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Color(0xFF0A7349),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A1D23),
                            ),
                            children: [
                              TextSpan(
                                text: '$jumlah sak',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A7349),
                                ),
                              ),
                              const TextSpan(text: ' akan dibuat (No. '),
                              TextSpan(
                                text: '$nextNo–${nextNo + jumlah - 1}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: '), masing-masing '),
                              TextSpan(
                                text: '${nf.format(berat)} kg',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0A7349),
                                ),
                              ),
                              TextSpan(
                                text:
                                    '  •  Total ${nf.format(jumlah * berat)} kg',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Batal',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Material(
                      color: const Color(0xFF0A7349),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: _confirm,
                        borderRadius: BorderRadius.circular(10),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Buat Sak',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
