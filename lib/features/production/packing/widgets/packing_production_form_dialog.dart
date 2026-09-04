import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/features/operator/model/operator_model.dart';
import 'package:pps_tablet/features/production/shared/widgets/regu_operator_picker.dart';
import 'package:pps_tablet/features/production/shared/widgets/time_form_field.dart';
import 'package:pps_tablet/features/regu/model/regu_model.dart';
import 'package:pps_tablet/features/packing_type/model/packing_type_model.dart';
import 'package:pps_tablet/features/packing_type/repository/packing_type_repository.dart';
import 'package:pps_tablet/features/packing_type/view_model/packing_type_view_model.dart';
import 'package:pps_tablet/features/packing_type/widgets/packing_type_dropdown.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../mesin/model/mesin_model.dart';
import '../../../shared/overlap/repository/overlap_repository.dart';
import '../../../shared/overlap/view_model/overlap_view_model.dart';
import '../../../shared/shift/widgets/shift_dropdown.dart';
import '../../shared/widgets/total_hours_pill.dart';
import '../model/packing_production_model.dart';
import '../view_model/packing_production_view_model.dart';

class PackingProductionFormDialog extends StatefulWidget {
  final PackingProduction? header;
  final MstMesin? initialMesin;
  final DateTime? initialDate;
  final int? initialShift;
  final String? initialHourStart;
  final String? initialHourEnd;

  /// false (default) = dari klik mesin → tanggal tampil sebagai teks, shift/jam tetap bisa diedit.
  /// true = mode backdate → tanggal bisa dipilih, ganti shift auto-fetch jam.
  final bool isBackdateInput;

  final Function(PackingProduction)? onSave;

  const PackingProductionFormDialog({
    super.key,
    this.header,
    this.initialMesin,
    this.initialDate,
    this.initialShift,
    this.initialHourStart,
    this.initialHourEnd,
    this.isBackdateInput = false,
    this.onSave,
  });

  @override
  State<PackingProductionFormDialog> createState() =>
      _PackingProductionFormDialogState();
}

class _PackingProductionFormDialogState
    extends State<PackingProductionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController dateCreatedCtrl;
  late final TextEditingController hourStartCtrl;
  late final TextEditingController hourEndCtrl;

  MstRegu? _selectedRegu;
  List<MstOperator> _selectedOperators = [];
  bool _loadingReguOperator = false;
  String? _reguOperatorError;
  int? _selectedShift;
  PackingType? _selectedOutputJenis;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool get isEdit => widget.header != null;

  static const String _kind = 'packing';
  static const int _idBagianPacking = 6;

  @override
  void initState() {
    super.initState();

    final DateTime seededDate = widget.header != null
        ? (parseAnyToDateTime(widget.header!.tglProduksi) ?? DateTime.now())
        : (widget.initialDate ?? DateTime.now());
    _selectedDate = seededDate;
    dateCreatedCtrl = TextEditingController(
      text: DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(seededDate),
    );

    _selectedShift = widget.header?.shift ?? widget.initialShift;
    hourStartCtrl = TextEditingController(
      text: widget.header?.hourStart ?? widget.initialHourStart ?? '',
    );
    hourEndCtrl = TextEditingController(
      text: widget.header?.hourEnd ?? widget.initialHourEnd ?? '',
    );

    final h = widget.header;
    if (h != null) {
      if (h.idRegu != null) {
        _selectedRegu = MstRegu(
          idRegu: h.idRegu!,
          idBagian: _idBagianPacking,
          namaRegu: '',
        );
      }
      if (h.idOperators.isNotEmpty) {
        final names = h.namaOperator.split(',').map((s) => s.trim()).toList();
        _selectedOperators = List.generate(h.idOperators.length, (i) {
          return MstOperator(
            idOperator: h.idOperators[i],
            namaOperator: i < names.length ? names[i] : '',
            enable: true,
          );
        });
      } else if (h.idOperator != 0) {
        _selectedOperators = [
          MstOperator(
            idOperator: h.idOperator,
            namaOperator: h.namaOperator,
            enable: true,
          ),
        ];
      }
    }
  }

  @override
  void dispose() {
    dateCreatedCtrl.dispose();
    hourStartCtrl.dispose();
    hourEndCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      dateCreatedCtrl.text =
          DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(picked);
    });
    if (_selectedShift != null) await _fetchShiftHour(_selectedShift!);
    await _checkOverlap();
  }

  Future<void> _fetchShiftHour(int shift) async {
    final tanggal = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final base = ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');
    final url = Uri.parse(
      '$base/api/mst/shift/hour?tanggal=$tanggal&shift=$shift',
    );
    try {
      final token = await TokenStorage.getToken();
      final res = await http
          .get(url, headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          })
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200 || !mounted) return;
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return;
      String trim5(String? v) =>
          (v != null && v.length >= 5) ? v.substring(0, 5) : (v ?? '');
      final start = trim5(data['hourStart'] as String?);
      final end = trim5(data['hourEnd'] as String?);
      if (!mounted) return;
      setState(() {
        if (start.isNotEmpty) hourStartCtrl.text = start;
        if (end.isNotEmpty) hourEndCtrl.text = end;
      });
      await _checkOverlap();
    } catch (_) {}
  }

  Future<void> _checkOverlap() async {
    final vm = context.read<OverlapViewModel>();
    final start = hourStartCtrl.text.trim();
    final end = hourEndCtrl.text.trim();
    final idMesin = widget.header?.idMesin ?? widget.initialMesin?.idMesin;
    if (start.isEmpty || end.isEmpty || idMesin == null) {
      vm.clear();
      return;
    }
    await vm.check(
      kind: _kind,
      date: _selectedDate,
      idMesin: idMesin,
      hourStart: start,
      hourEnd: end,
      excludeNo: isEdit ? widget.header!.noPacking : null,
    );
  }

  Future<void> _openReguOperatorPicker() async {
    if (!mounted) return;
    setState(() => _loadingReguOperator = true);
    final result = await showReguOperatorPicker(
      context,
      initialRegu: _selectedRegu,
      initialSelected: _selectedOperators,
      idBagian: _idBagianPacking,
    );
    if (mounted) setState(() => _loadingReguOperator = false);
    if (result != null && mounted) {
      setState(() {
        _reguOperatorError = null;
        _selectedRegu = result.regu;
        _selectedOperators
          ..clear()
          ..addAll(result.operators);
      });
    }
  }

  Future<void> _submit() async {
    final ovm = context.read<OverlapViewModel>();
    if (ovm.hasOverlap) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak bisa simpan, ada overlap jam di mesin ini'),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final idOperatorList =
        _selectedOperators.map((o) => o.idOperator).toList();
    if (idOperatorList.isEmpty || _selectedRegu == null) {
      setState(() => _reguOperatorError = 'Regu & operator wajib dipilih');
      return;
    }

    if (_selectedShift == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift wajib dipilih')),
      );
      return;
    }

    final start = hourStartCtrl.text.trim();
    final end = hourEndCtrl.text.trim();
    if (start.isEmpty || end.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam mulai & selesai wajib diisi')),
      );
      return;
    }

    if (!isEdit && _selectedOutputJenis == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jenis output wajib dipilih')),
      );
      return;
    }

    if (_selectedRegu == null) {
      setState(() => _reguOperatorError = 'Regu & operator wajib dipilih');
      return;
    }

    String toSqlTime(String raw) {
      final t = raw.trim();
      return (t.isNotEmpty && t.length == 5) ? '$t:00' : t;
    }

    final dur = durationBetweenHHmmWrap(start, end);
    final jamKerja = dur?.inHours;

    final prodVm = context.read<PackingProductionViewModel>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    PackingProduction? result;

    try {
      final mesinId =
          widget.header?.idMesin ?? widget.initialMesin?.idMesin ?? 0;

      if (isEdit) {
        result = await prodVm.updateProduksi(
          noPacking: widget.header!.noPacking,
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperator: idOperatorList.first,
          shift: _selectedShift!,
          hourStart: toSqlTime(start),
          hourEnd: toSqlTime(end),
          jamKerja: jamKerja,
        );
      } else {
        result = await prodVm.createProduksi(
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperators: idOperatorList,
          outputJenisId: _selectedOutputJenis!.idBj,
          idRegu: _selectedRegu!.idRegu,
          shift: _selectedShift!,
          hourStart: toSqlTime(start),
          hourEnd: toSqlTime(end),
          jamKerja: jamKerja,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }

    if (!mounted) return;

    if (result != null) {
      if (!isEdit && _selectedOutputJenis != null) {
        result = result.copyWith(outputJenisNama: _selectedOutputJenis!.namaBj);
      }
      widget.onSave?.call(result);
      Navigator.of(context).pop(result);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(prodVm.saveError ?? 'Gagal menyimpan data'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => OverlapViewModel(repository: OverlapRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) => PackingTypeViewModel(
            repository: PackingTypeRepository(api: ApiClient()),
          ),
        ),
      ],
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: isLandscape
            ? const EdgeInsets.symmetric(horizontal: 72, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 680 : 620,
            maxHeight:
                (mq.size.height - 24).clamp(260, isLandscape ? 580 : 700),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: _buildForm(),
                  ),
                ),
                const SizedBox(height: 16),
                _buildActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    final vm = context.watch<OverlapViewModel>();
    final dur = durationBetweenHHmmWrap(hourStartCtrl.text, hourEndCtrl.text);
    final startFilled = hourStartCtrl.text.trim().isNotEmpty;
    final endFilled = hourEndCtrl.text.trim().isNotEmpty;
    final hasDurationError = startFilled && endFilled && dur == null;
    final hasOverlap = vm.hasOverlap;
    final overlapMsg =
        vm.overlapMessage ?? 'Jam ini bentrok dengan dokumen lain';

    final mesinName = widget.initialMesin?.namaMesin ??
        widget.header?.namaMesin ??
        (isEdit ? 'Edit Produksi Packing' : 'Tambah Produksi Packing');

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Judul ─────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEdit
                      ? Colors.orange.shade50
                      : Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEdit ? Icons.edit : Icons.add,
                  color: isEdit
                      ? Colors.orange.shade700
                      : Colors.indigo.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: Text(
                  mesinName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Tanggal: plain text jika dari mesin (non-backdate),
              // date picker jika mode backdate
              if (!widget.isBackdateInput)
                Text(
                  DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              if (widget.isBackdateInput) ...[
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: dateCreatedCtrl,
                    readOnly: true,
                    onTap: _pickTanggal,
                    decoration: InputDecoration(
                      labelText: 'Tanggal',
                      hintText: 'Pilih tanggal',
                      prefixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 20,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Wajib pilih tanggal' : null,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // ── Baris 1: Shift + Jam Mulai + Jam Selesai + Total ──────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 190,
                child: ShiftDropdown(
                  preselectId: widget.header?.shift ?? widget.initialShift,
                  onChangedId: (id) {
                    setState(() => _selectedShift = id);
                    if (id != null && widget.isBackdateInput) {
                      _fetchShiftHour(id);
                    }
                  },
                  validator: (v) => v == null ? 'Wajib pilih shift' : null,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TimeFormField(
                  controller: hourStartCtrl,
                  label: 'Jam Mulai',
                  hintText: 'HH:mm',
                  onPick: () async {
                    final picked =
                        await pickTime24h(context, initial: _startTime);
                    if (picked != null) {
                      setState(() {
                        _startTime = picked;
                        hourStartCtrl.text = formatHHmm(picked);
                      });
                      await _checkOverlap();
                    }
                  },
                  validator: (_) {
                    final s = parseHHmm(hourStartCtrl.text);
                    if (s == null) return 'Wajib isi (HH:mm)';
                    final diff = durationBetweenHHmmWrap(
                        hourStartCtrl.text, hourEndCtrl.text);
                    if (diff == null && parseHHmm(hourEndCtrl.text) != null) {
                      return 'Durasi 0';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: TimeFormField(
                  controller: hourEndCtrl,
                  label: 'Jam Selesai',
                  hintText: 'HH:mm',
                  onPick: () async {
                    final picked = await pickTime24h(
                        context, initial: _endTime ?? _startTime);
                    if (picked != null) {
                      setState(() {
                        _endTime = picked;
                        hourEndCtrl.text = formatHHmm(picked);
                      });
                      await _checkOverlap();
                    }
                  },
                  validator: (_) {
                    final e = parseHHmm(hourEndCtrl.text);
                    if (e == null) return 'Wajib isi (HH:mm)';
                    final s = parseHHmm(hourStartCtrl.text);
                    if (s != null) {
                      final diff = durationBetweenHHmmWrap(
                          hourStartCtrl.text, hourEndCtrl.text);
                      if (diff == null) return 'Durasi 0';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TotalHoursPill(
                    duration: dur,
                    isError: hasOverlap || hasDurationError,
                    errorText: hasOverlap
                        ? overlapMsg
                        : 'Durasi tidak boleh 0 menit',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Baris 2: Regu & Operator ──────────────────────────────
          ReguOperatorPickerField(
            selectedRegu: _selectedRegu,
            selectedOperators: _selectedOperators,
            isLoading: _loadingReguOperator,
            onTap: _openReguOperatorPicker,
            errorText: _reguOperatorError,
          ),

          const SizedBox(height: 16),

          // ── Baris 3: Jenis Output ─────────────────────────────────
          PackingTypeDropdown(
            preselectId: widget.header?.outputJenisId,
            label: 'Jenis Output',
            hintText: 'Pilih jenis output packing',
            onChanged: (pt) => setState(() => _selectedOutputJenis = pt),
            validator: isEdit
                ? null
                : (v) => v == null ? 'Wajib pilih jenis output' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final vm = context.watch<OverlapViewModel>();
    final hasOverlap = vm.hasOverlap;
    final prodVm = context.watch<PackingProductionViewModel>();
    final isSaving = prodVm.isSaving;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('BATAL', style: TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: (hasOverlap || isSaving) ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isEdit ? const Color(0xFFF57C00) : const Color(0xFF3730A3),
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          child: Text(
            isSaving ? 'MENYIMPAN...' : 'SIMPAN',
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
