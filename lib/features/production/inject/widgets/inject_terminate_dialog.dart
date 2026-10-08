import 'package:flutter/material.dart';

import '../model/inject_batch_model.dart';
import '../model/inject_production_model.dart' show InjectOutputJenis;
import '../repository/inject_production_repository.dart';
import 'counter_picker_dialog.dart';
import 'sisa_jenis_editor.dart';

class InjectTerminateDialog extends StatefulWidget {
  const InjectTerminateDialog({
    super.key,
    required this.noProduksi,
    required this.hourStart,
    required this.hourEnd,
    this.carryOverIn = 0,
    this.carryOverInByJenis = const {},
    this.outputJenisList = const [],
  });

  final String noProduksi;
  final String hourStart;
  final String hourEnd;
  final int carryOverIn;
  final Map<int, int> carryOverInByJenis;
  final List<InjectOutputJenis> outputJenisList;

  @override
  State<InjectTerminateDialog> createState() => _InjectTerminateDialogState();
}

class _InjectTerminateDialogState extends State<InjectTerminateDialog> {
  // Per-jenis pcs controllers (keyed by idJenis)
  final Map<int, TextEditingController> _jenisCtrl = {};
  final _beratCtrl = TextEditingController();
  final _cycleCtrl = TextEditingController();

  /// Sisa akhir shift — bisa banyak jenis bonggolan & reject.
  final SisaJenisDraft _sisa = SisaJenisDraft();

  int? _counterValue;

  InjectPcsPerLabelResult? _pplData;
  late String _selectedHourEnd;
  bool _isSaving = false;
  String? _error;
  bool _beratError = false;
  bool _cycleError = false;
  bool _counterError = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedHourEnd =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    _syncJenisControllers();
    _fetchPplData();
  }

  void _syncJenisControllers() {
    for (final jenis in widget.outputJenisList) {
      if (!_jenisCtrl.containsKey(jenis.idJenis)) {
        final ctrl = TextEditingController();
        ctrl.addListener(() { if (mounted) setState(() {}); });
        _jenisCtrl[jenis.idJenis] = ctrl;
      }
    }
  }

  Future<void> _fetchPplData() async {
    try {
      final data = await InjectProductionRepository()
          .fetchPcsPerLabel(widget.noProduksi);
      if (!mounted) return;
      setState(() {
        _pplData = data;
      });
    } catch (_) {}
  }

  int _carryInForJenis(int idJenis) {
    if (widget.carryOverInByJenis.containsKey(idJenis)) {
      return widget.carryOverInByJenis[idJenis]!;
    }
    if (widget.outputJenisList.length == 1) return widget.carryOverIn;
    return 0;
  }

  @override
  void dispose() {
    for (final ctrl in _jenisCtrl.values) { ctrl.dispose(); }
    _beratCtrl.dispose();
    _cycleCtrl.dispose();
    _sisa.dispose();
    super.dispose();
  }

  void _showValidationSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.orange.shade700,
      duration: const Duration(seconds: 2),
    ));
  }

  /// Normalisasi jam ke "HH:mm:ss" — satu-satunya format yang pasti diterima
  /// backend (`CAST(@HourStart AS time(7))` plus regex split-time).
  /// Mengembalikan null kalau input tidak bisa diparse sebagai jam 24 jam.
  static String? _normalizeHour(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return null;
    final m = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(s);
    if (m == null) return null;
    final hh = int.tryParse(m.group(1)!);
    final mm = int.tryParse(m.group(2)!);
    final ss = int.tryParse(m.group(3) ?? '0') ?? 0;
    if (hh == null || hh < 0 || hh > 23) return null;
    if (mm == null || mm < 0 || mm > 59) return null;
    if (ss < 0 || ss > 59) return null;
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${p2(hh)}:${p2(mm)}:${p2(ss)}';
  }

  Future<void> _submit() async {
    final berat = double.tryParse(_beratCtrl.text.replaceAll(',', '.'));
    final cycleTime = double.tryParse(_cycleCtrl.text.replaceAll(',', '.'));
    final counter = _counterValue;

    // Validation
    final hasBeratErr = berat == null;
    final hasCycleErr = cycleTime == null;
    final hasCounterErr = counter == null;
    if (hasBeratErr || hasCycleErr || hasCounterErr) {
      setState(() {
        _beratError = hasBeratErr;
        _cycleError = hasCycleErr;
        _counterError = hasCounterErr;
      });
      if (hasBeratErr) {
        _showValidationSnack('Berat harus diisi');
      } else if (hasCycleErr) {
        _showValidationSnack('Cycle Time harus diisi');
      } else {
        _showValidationSnack('Counter harus dipilih');
      }
      return;
    }
    setState(() { _beratError = false; _cycleError = false; _counterError = false; });

    // Counter odometer check
    final minCounter = _pplData?.counterCurrent;
    if (minCounter != null && counter < minCounter) {
      setState(() => _counterError = true);
      _showValidationSnack('Counter tidak boleh kurang dari $minCounter (odometer saat ini)');
      return;
    }

    // Standar warning
    final standarBerat = _pplData?.standarBerat;
    final standarCycle = _pplData?.standarCycleTime;
    final beratWarning = standarBerat != null && berat != standarBerat;
    final cycleWarning = standarCycle != null && cycleTime != standarCycle;
    if (beratWarning || cycleWarning) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => _StandarWarningDialog(
          beratWarning: beratWarning ? (input: berat, standar: standarBerat) : null,
          cycleWarning: cycleWarning ? (input: cycleTime, standar: standarCycle) : null,
        ),
      );
      if (!mounted || proceed != true) return;
    }

    setState(() { _isSaving = true; _error = null; });
    try {
      // Backend hanya menerima "HH:mm" atau "HH:mm:ss" (lihat validasi
      // timeRegex di inject-production-controller.js untuk split-time).
      // Terminate sebelumnya hanya normalizeTime() tanpa cek format, jadi
      // nilai Odd seperti "9:5" lolos ke SQL dan gagal di CAST sebagai 500.
      final hourStartFull = _normalizeHour(widget.hourStart);
      if (hourStartFull == null) {
        setState(() {
          _isSaving = false;
          _error =
              'Format jam mulai tidak valid (${widget.hourStart}). '
              'Gunakan HH:mm atau HH:mm:ss.';
        });
        return;
      }
      final hourEndFull = _normalizeHour(_selectedHourEnd);
      if (hourEndFull == null) {
        setState(() {
          _isSaving = false;
          _error =
              'Format jam berhenti tidak valid ($_selectedHourEnd). '
              'Gunakan HH:mm atau HH:mm:ss.';
        });
        return;
      }

      // Build items (one per jenis; terminate = last bucket so carryOverOut = 0)
      final outputs = widget.outputJenisList;
      final List<Map<String, dynamic>> items;
      if (outputs.isEmpty) {
        final ppl = (_pplData?.items.isNotEmpty == true
              ? _pplData!.items.first.pcsPerLabel
              : 100)
          .clamp(1, 999999);
        items = [{
          'carryOverIn': widget.carryOverIn,
          'pcsInput': 0,
          'carryOverOut': widget.carryOverIn % ppl,
        }];
      } else {
        items = outputs.map((jenis) {
          final carryIn = _carryInForJenis(jenis.idJenis);
          final pcsInput = int.tryParse(_jenisCtrl[jenis.idJenis]?.text.trim() ?? '') ?? 0;
          final ppl = (_pplData?.pplForJenis(jenis.idJenis) ?? 100).clamp(1, 999999);
          final carryOut = (carryIn + pcsInput) % ppl;
          return <String, dynamic>{
            'idJenis': jenis.idJenis,
            'carryOverIn': carryIn,
            'pcsInput': pcsInput,
            'carryOverOut': carryOut,
          };
        }).toList();
      }

      await InjectProductionRepository().terminate(
        noProduksi: widget.noProduksi,
        hourStart: hourStartFull,
        hourEnd: hourEndFull,
        berat: berat,
        cycleTime: cycleTime,
        counter: counter,
        items: items,
        bonggolanItems: _sisa.bonggolanPayload,
        rejectItems: _sisa.rejectPayload,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFDC2626);
    final outputs = widget.outputJenisList;
    final multiJenis = outputs.length > 1;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Container(
        width: 520,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFB91C1C), Color(0xFFEF4444)]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.stop_circle_outlined, size: 18, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Terminate Produksi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('${widget.hourStart} → $_selectedHourEnd', style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: _isSaving ? null : () => Navigator.of(context).pop(null),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Warning banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(children: [
                        Icon(Icons.warning_amber_rounded, size: 15, color: Color(0xFFDC2626)),
                        SizedBox(width: 8),
                        Expanded(child: Text(
                          'Produksi akan dihentikan permanen. Pastikan data jam terakhir sudah benar.',
                          style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // ── Jam Mulai (readonly) + Jam Selesai (picker) ──────────
                    Row(
                      children: [
                        Expanded(child: _HourReadonlyField(value: widget.hourStart)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF9CA3AF)),
                        ),
                        Expanded(
                          child: _HourEndPickerField(
                            value: _selectedHourEnd,
                            onTap: () async {
                              final parts = _selectedHourEnd.split(':');
                              final initial = TimeOfDay(
                                hour: int.tryParse(parts[0]) ?? 0,
                                minute: int.tryParse(parts[1]) ?? 0,
                              );
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: initial,
                                builder: (ctx, child) => MediaQuery(
                                  data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
                                  child: child!,
                                ),
                              );
                              if (picked != null && mounted) {
                                setState(() {
                                  _selectedHourEnd =
                                      '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Per-jenis input rows ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF5F5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withValues(alpha: 0.25)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.precision_manufacturing_outlined, size: 13, color: accent),
                            const SizedBox(width: 5),
                            Text('Input Batch Jam Terakhir', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accent)),
                          ]),
                          const SizedBox(height: 10),

                          if (outputs.isEmpty)
                            // No jenis: show flat carry-over only
                            _buildFlatCarryRow()
                          else
                            for (int i = 0; i < outputs.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _buildJenisRow(outputs[i], showLabel: multiJenis),
                            ],

                          // ── Sisa akhir shift ─────────────────────────────
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFFFE4E4)),
                          const SizedBox(height: 10),

                          // Boleh lebih dari satu jenis bonggolan & reject
                          SisaJenisEditor(draft: _sisa, accent: accent),

                          // ── Berat / Cycle / Counter ──────────────────────
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: Color(0xFFFFE4E4)),
                          const SizedBox(height: 10),
                          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Expanded(child: _InputField(
                              label: 'Berat (gr)',
                              ctrl: _beratCtrl,
                              hint: '0.0', decimal: true,
                              isError: _beratError,
                              onChanged: () { if (_beratError) setState(() => _beratError = false); },
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: _InputField(
                              label: 'Cycle Time (sec)',
                              ctrl: _cycleCtrl,
                              hint: '0.0', decimal: true,
                              isError: _cycleError,
                              onChanged: () { if (_cycleError) setState(() => _cycleError = false); },
                            )),
                            const SizedBox(width: 6),
                            Expanded(child: _CounterField(
                              value: _counterValue,
                              minCounter: _pplData?.counterCurrent,
                              isError: _counterError,
                              onTap: () async {
                                final min = _pplData?.counterCurrent;
                                final picked = await showDialog<int>(
                                  context: context,
                                  builder: (_) => CounterPickerDialog(
                                    initialValue: _counterValue ?? (min ?? 0),
                                    minValue: min,
                                    accentColor: accent,
                                  ),
                                );
                                if (picked != null && mounted) {
                                  setState(() { _counterValue = picked; _counterError = false; });
                                }
                              },
                            )),
                          ]),
                        ],
                      ),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, size: 14, color: Color(0xFFDC2626)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(null),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.stop_circle_outlined, size: 16),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Terminate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFE5E7EB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlatCarryRow() {
    return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Expanded(child: _ReadonlyChip(
        label: 'Carry Over Sebelumnya',
        value: '${widget.carryOverIn} pcs',
        icon: Icons.arrow_forward,
        accent: const Color(0xFFDC2626),
      )),
      const SizedBox(width: 8),
      const Expanded(child: SizedBox.shrink()),
      const SizedBox(width: 8),
      Expanded(child: _ReadonlyChip(
        label: 'Carry Over Sesudah',
        value: '0 pcs',
        icon: Icons.arrow_forward,
        accent: const Color(0xFF64748B),
      )),
    ]);
  }

  Widget _buildJenisRow(InjectOutputJenis jenis, {bool showLabel = false}) {
    final ctrl = _jenisCtrl[jenis.idJenis] ?? TextEditingController();
    final carryIn = _carryInForJenis(jenis.idJenis);
    final ppl = (_pplData?.pplForJenis(jenis.idJenis) ?? 100).clamp(1, 999999);
    final pcsTyped = int.tryParse(ctrl.text.trim()) ?? 0;
    final carryOut = (carryIn + pcsTyped) % ppl;
    const accent = Color(0xFFDC2626);
    const mutedColor = Color(0xFF9CA3AF);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(jenis.namaJenis, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: accent)),
          ),
        ],
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _ReadonlyChip(
            label: 'Carry Over Sebelumnya',
            value: '$carryIn / $ppl pcs',
            icon: Icons.arrow_forward,
            accent: accent,
          )),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Jumlah Item Bagus (pcs)', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                const SizedBox(height: 3),
                SizedBox(
                  height: 36,
                  child: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: 'Masukkan pcs...',
                      hintStyle: const TextStyle(fontSize: 11, color: mutedColor, fontWeight: FontWeight.w400),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: accent.withValues(alpha: 0.35))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: accent.withValues(alpha: 0.35))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: accent, width: 1.5)),
                      filled: true, fillColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: _ReadonlyChip(
            label: 'Carry Over Sesudah',
            value: '$carryOut pcs',
            icon: Icons.arrow_forward,
            accent: const Color(0xFF64748B),
          )),
        ]),
      ],
    );
  }
}

// ── Standar Warning Dialog ────────────────────────────────────────────────────

typedef _StandarEntry = ({double? input, double? standar});

class _StandarWarningDialog extends StatelessWidget {
  const _StandarWarningDialog({this.beratWarning, this.cycleWarning});
  final _StandarEntry? beratWarning;
  final _StandarEntry? cycleWarning;

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFEA580C);
    const orangeLight = Color(0xFFFFF7ED);
    const orangeBorder = Color(0xFFFED7AA);

    Widget diffRow({
      required IconData icon,
      required String fieldLabel,
      required double? input,
      required double? standar,
      required String unit,
    }) {
      final diff = (input ?? 0) - (standar ?? 0);
      final isOver = diff > 0;
      final diffColor = isOver ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
      final diffLabel = isOver ? '+${diff.toStringAsFixed(1)}' : diff.toStringAsFixed(1);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: orangeBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: orange.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
                child: Icon(icon, size: 12, color: orange),
              ),
              const SizedBox(width: 7),
              Text(fieldLabel, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: diffColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(isOver ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 10, color: diffColor),
                  const SizedBox(width: 2),
                  Text('$diffLabel $unit', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: diffColor)),
                ]),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _CompareChip(
                label: 'Input',
                value: '${input?.toStringAsFixed(1) ?? '-'} $unit',
                color: diffColor, isHighlight: true,
              )),
              const SizedBox(width: 8),
              const Icon(Icons.compare_arrows_rounded, size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Expanded(child: _CompareChip(
                label: 'Standar',
                value: '${standar?.toStringAsFixed(1) ?? '-'} $unit',
                color: const Color(0xFF15803D), isHighlight: false,
              )),
            ]),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: orangeLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: orangeBorder)),
                  child: const Icon(Icons.warning_amber_rounded, size: 20, color: orange),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Nilai Tidak Sesuai Standar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  SizedBox(height: 1),
                  Text('Periksa kembali sebelum menyimpan', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                ])),
              ]),
              const SizedBox(height: 16),
              if (beratWarning != null) ...[
                diffRow(icon: Icons.scale_outlined, fieldLabel: 'Berat', input: beratWarning!.input, standar: beratWarning!.standar, unit: 'gr'),
                if (cycleWarning != null) const SizedBox(height: 8),
              ],
              if (cycleWarning != null)
                diffRow(icon: Icons.timer_outlined, fieldLabel: 'Cycle Time', input: cycleWarning!.input, standar: cycleWarning!.standar, unit: 'sec'),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF374151), side: const BorderSide(color: Color(0xFFD1D5DB)), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Batal', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: orange, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  icon: const Icon(Icons.save_outlined, size: 15),
                  label: const Text('Tetap Simpan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompareChip extends StatelessWidget {
  const _CompareChip({required this.label, required this.value, required this.color, required this.isHighlight});
  final String label;
  final String value;
  final Color color;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isHighlight ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.75))),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
      ]),
    );
  }
}

// ── Shared local widgets ──────────────────────────────────────────────────────

class _HourReadonlyField extends StatelessWidget {
  const _HourReadonlyField({required this.value});
  final String value;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF6B7280);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Jam Mulai',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 3),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Icon(Icons.schedule_outlined, size: 14, color: accent),
            const SizedBox(width: 8),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
          ]),
        ),
      ],
    );
  }
}

class _HourEndPickerField extends StatelessWidget {
  const _HourEndPickerField({required this.value, required this.onTap});
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFDC2626);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Jam Selesai',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
        ),
        const SizedBox(height: 3),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: accent.withValues(alpha: 0.40), width: 1.5),
            ),
            child: Row(children: [
              Icon(Icons.schedule_outlined, size: 14, color: accent),
              const SizedBox(width: 8),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              ),
              const Spacer(),
              Icon(Icons.edit_outlined, size: 13, color: accent.withValues(alpha: 0.6)),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ReadonlyChip extends StatelessWidget {
  const _ReadonlyChip({required this.label, required this.value, required this.icon, required this.accent});
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const SizedBox(height: 3),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: accent.withValues(alpha: 0.20)),
          ),
          alignment: Alignment.centerLeft,
          child: Row(children: [
            Icon(icon, size: 11, color: accent),
            const SizedBox(width: 5),
            Expanded(child: Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent))),
          ]),
        ),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.label,
    required this.ctrl,
    this.hint = '0.0',
    this.decimal = true,
    this.isError = false,
    this.onChanged,
  });
  final String label;
  final TextEditingController ctrl;
  final String hint;
  final bool decimal;
  final bool isError;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFDC2626);
    const errorColor = Color(0xFFDC2626);
    final borderColor =
        isError ? errorColor : accent.withValues(alpha: 0.30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: isError ? errorColor : const Color(0xFF374151),
        )),
        const SizedBox(height: 3),
        SizedBox(
          height: 32,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            onChanged: onChanged != null ? (_) => onChanged!() : null,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor, width: isError ? 1.5 : 1.0)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isError ? errorColor : accent, width: 1.5)),
              filled: true,
              fillColor: isError ? const Color(0xFFFEF2F2) : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _CounterField extends StatelessWidget {
  const _CounterField({required this.value, required this.onTap, this.minCounter, this.isError = false});
  final int? value;
  final int? minCounter;
  final bool isError;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFDC2626);
    const errorColor = Color(0xFFDC2626);
    final hasValue = value != null;
    final borderColor = isError ? errorColor : hasValue ? accent : accent.withValues(alpha: 0.30);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          minCounter != null ? 'Counter · min $minCounter' : 'Counter',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isError ? errorColor : const Color(0xFF374151)),
        ),
        const SizedBox(height: 3),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 32,
            decoration: BoxDecoration(
              color: isError ? const Color(0xFFFEF2F2) : Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: (isError || hasValue) ? 1.5 : 1.0),
            ),
            alignment: Alignment.center,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (hasValue)
                Text('$value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent))
              else
                Text(isError ? 'Wajib dipilih' : 'Pilih', style: TextStyle(fontSize: 11, color: isError ? errorColor : Colors.grey.shade400)),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 14, color: isError ? errorColor : hasValue ? accent : Colors.grey.shade400),
            ]),
          ),
        ),
      ],
    );
  }
}
