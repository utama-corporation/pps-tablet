import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/features/operator/model/operator_model.dart';
import 'package:pps_tablet/features/production/shared/widgets/total_hours_pill.dart';

import '../../../../common/widgets/app_number_field.dart';
import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../mesin/model/mesin_model.dart';
import '../../../regu/model/regu_model.dart';
import '../../shared/widgets/regu_operator_picker.dart';
import '../../../shared/overlap/repository/overlap_repository.dart';
import '../../../shared/overlap/view_model/overlap_view_model.dart';
import '../../../shared/shift/widgets/shift_dropdown.dart';
import '../../../gilingan_type/model/gilingan_type_model.dart';
import '../../../gilingan_type/repository/gilingan_type_repository.dart';
import '../../../gilingan_type/view_model/gilingan_type_view_model.dart';
import '../../../gilingan_type/widgets/gilingan_type_dropdown.dart';
import '../../shared/widgets/time_form_field.dart';
import '../model/gilingan_production_model.dart';
import '../view_model/gilingan_production_view_model.dart';

class GilinganProductionFormDialog extends StatefulWidget {
  final GilinganProduction? header;
  final Function(GilinganProduction)? onSave;
  final MstMesin? initialMesin;
  final DateTime? initialDate;
  final int? initialShift;
  final String? initialHourStart;
  final String? initialHourEnd;
  final bool lockShiftFields;
  final bool isBackdateInput;

  const GilinganProductionFormDialog({
    super.key,
    this.header,
    this.onSave,
    this.initialMesin,
    this.initialDate,
    this.initialShift,
    this.initialHourStart,
    this.initialHourEnd,
    this.lockShiftFields = false,
    this.isBackdateInput = false,
  });

  @override
  State<GilinganProductionFormDialog> createState() =>
      _GilinganProductionFormDialogState();
}

class _GilinganProductionFormDialogState
    extends State<GilinganProductionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController dateCreatedCtrl;
  late final TextEditingController hadirCtrl;
  late final TextEditingController hourStartCtrl;
  late final TextEditingController hourEndCtrl;

  MstMesin? _selectedMesin;
  MstRegu? _selectedRegu;
  final List<MstOperator> _selectedOperators = [];
  bool _loadingReguOperator = false;
  String? _reguOperatorError;
  int? _selectedShift;
  GilinganType? _selectedGilinganType;

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool get isEdit => widget.header != null;

  static const String _kind = 'gilingan';

  @override
  void initState() {
    super.initState();

    final seededDate = widget.header != null
        ? (parseAnyToDateTime(widget.header!.tglProduksi) ?? DateTime.now())
        : (widget.initialDate ?? DateTime.now());
    _selectedDate = seededDate;

    dateCreatedCtrl = TextEditingController(
      text: DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(seededDate),
    );
    hadirCtrl = TextEditingController(
      text: widget.header?.hadir?.toString() ?? '',
    );
    hourStartCtrl = TextEditingController(
      text: widget.header?.hourStart ?? widget.initialHourStart ?? '',
    );
    hourEndCtrl = TextEditingController(
      text: widget.header?.hourEnd ?? widget.initialHourEnd ?? '',
    );

    _selectedMesin = widget.initialMesin;
    _selectedShift = widget.header?.shift ?? widget.initialShift;
  }

  @override
  void dispose() {
    dateCreatedCtrl.dispose();
    hadirCtrl.dispose();
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
      dateCreatedCtrl.text = DateFormat(
        'EEEE, dd MMM yyyy',
        'id_ID',
      ).format(picked);
    });
    if (_selectedShift != null) {
      await _fetchShiftHour(_selectedShift!);
    } else {
      await _checkOverlapIfReadyVM();
    }
  }

  Future<void> _fetchShiftHour(int shift) async {
    final tanggal = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final base = ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');
    final url = Uri.parse(
      '$base/api/mst/gilingan/shift/hour?tanggal=$tanggal&shift=$shift',
    );
    try {
      final token = await TokenStorage.getToken();
      final res = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;
      final body =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return;
      String trimTime(String? v) {
        if (v == null || v.isEmpty) return '';
        return v.length >= 5 ? v.substring(0, 5) : v;
      }

      final start = trimTime(data['hourStart'] as String?);
      final end = trimTime(data['hourEnd'] as String?);
      if (!mounted) return;
      setState(() {
        if (start.isNotEmpty) hourStartCtrl.text = start;
        if (end.isNotEmpty) hourEndCtrl.text = end;
      });
      await _checkOverlapIfReadyVM();
    } catch (_) {}
  }

  Future<void> _checkOverlapIfReadyVM() async {
    final vm = context.read<OverlapViewModel>();
    final start = hourStartCtrl.text.trim();
    final end = hourEndCtrl.text.trim();
    final idMesin = _selectedMesin?.idMesin ?? widget.header?.idMesin;
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
      excludeNo: isEdit ? widget.header!.noProduksi : null,
    );
  }

  Future<void> _openReguOperatorPicker() async {
    if (!mounted) return;
    setState(() => _loadingReguOperator = true);
    final result = await showReguOperatorPicker(
      context,
      initialRegu: _selectedRegu,
      initialSelected: _selectedOperators,
      idBagian: 11,
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

    final mesinId = _selectedMesin?.idMesin ?? widget.header?.idMesin;
    if (mesinId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mesin wajib dipilih')));
      return;
    }

    if (_selectedShift == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shift wajib dipilih')));
      return;
    }

    if (hourStartCtrl.text.trim().isEmpty || hourEndCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam mulai & selesai wajib diisi')),
      );
      return;
    }

    String toSqlTime(String raw) {
      final t = raw.trim();
      return t.length == 5 ? '$t:00' : t;
    }

    final hourStartSql = toSqlTime(hourStartCtrl.text);
    final hourEndSql = toSqlTime(hourEndCtrl.text);
    final hadir = int.tryParse(hadirCtrl.text.trim());

    final prodVm = context.read<GilinganProductionViewModel>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    GilinganProduction? result;
    String? directError;

    try {
      if (isEdit) {
        // edit: pakai operator pertama dari picker (jika dipilih) atau fallback header
        final operatorId = _selectedOperators.isNotEmpty
            ? _selectedOperators.first.idOperator
            : widget.header!.idOperator;
        result = await prodVm.updateProduksi(
          noProduksi: widget.header!.noProduksi,
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperator: operatorId,
          shift: _selectedShift!,
          hourStart: hourStartSql,
          hourEnd: hourEndSql,
          hadir: hadir,
        );
      } else {
        if (_selectedOperators.isEmpty || _selectedRegu == null) {
          if (mounted) Navigator.of(context).pop();
          setState(() => _reguOperatorError = 'Regu & operator wajib dipilih');
          return;
        }

        final computedDur = durationBetweenHHmmWrap(
          hourStartCtrl.text,
          hourEndCtrl.text,
        );
        final jam = computedDur != null ? computedDur.inMinutes / 60.0 : 0.0;

        result = await prodVm.createProduksi(
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperators: _selectedOperators.map((o) => o.idOperator).toList(),
          shift: _selectedShift!,
          jam: jam,
          outputJenisId: _selectedGilinganType?.idGilingan,
          idRegu: _selectedRegu?.idRegu,
          hourStart: hourStartSql,
          hourEnd: hourEndSql,
          hadir: hadir,
        );
      }
    } catch (e) {
      directError = e.toString();
    } finally {
      if (mounted) Navigator.of(context).pop();
    }

    if (!mounted) return;

    if (result != null) {
      // Patch field yang tidak/salah dikembalikan API create
      if (!isEdit) {
        String? trimHHmm(String s) {
          final v = s.trim();
          return v.isEmpty ? null : (v.length >= 5 ? v.substring(0, 5) : v);
        }

        result = result.copyWith(
          tglProduksi: result.tglProduksi ?? _selectedDate,
          hourStart: trimHHmm(hourStartCtrl.text) ?? result.hourStart,
          hourEnd: trimHHmm(hourEndCtrl.text) ?? result.hourEnd,
          outputJenisId: result.outputJenisId ?? _selectedGilinganType?.idGilingan,
          outputJenisNama: _selectedGilinganType?.namaGilingan,
          namaMesin: _selectedMesin?.namaMesin,
          namaRegu: _selectedRegu?.namaRegu,
        );
      }
      widget.onSave?.call(result);
      Navigator.of(context).pop(result);
    } else {
      final rawErr = directError ?? prodVm.saveError ?? 'Gagal menyimpan data';
      final errMsg = rawErr.startsWith('Exception: ')
          ? rawErr.substring('Exception: '.length)
          : rawErr;
      showDialog(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menyimpan', message: errMsg),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;
    final maxDialogHeight = mq.size.height - 24;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => OverlapViewModel(repository: OverlapRepository()),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              GilinganTypeViewModel(repository: GilinganTypeRepository()),
        ),
      ],
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: isLandscape
            ? const EdgeInsets.symmetric(horizontal: 72, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isLandscape ? 680.0 : 620.0,
            maxHeight: maxDialogHeight.clamp(260, isLandscape ? 600 : 740),
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

    final mesinName =
        _selectedMesin?.namaMesin ??
        widget.header?.namaMesin ??
        widget.initialMesin?.namaMesin ??
        'Gilingan Produksi';

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Baris 1: Nama mesin + tanggal (backdate) ─────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  mesinName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                  overflow: TextOverflow.ellipsis,
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
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // ── Baris 2: Shift + Jam Mulai + Jam Selesai + Total ─────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AbsorbPointer(
                absorbing: widget.lockShiftFields,
                child: Opacity(
                  opacity: widget.lockShiftFields ? 0.45 : 1.0,
                  child: SizedBox(
                    width: 200,
                    child: ShiftDropdown(
                      preselectId: widget.header?.shift ?? widget.initialShift,
                      onChangedId: (id) {
                        setState(() => _selectedShift = id);
                        if (id != null) _fetchShiftHour(id);
                      },
                      validator: (v) => v == null ? 'Wajib pilih shift' : null,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AbsorbPointer(
                  absorbing: widget.lockShiftFields,
                  child: Opacity(
                    opacity: widget.lockShiftFields ? 0.45 : 1.0,
                    child: TimeFormField(
                      controller: hourStartCtrl,
                      label: 'Jam Mulai',
                      hintText: 'HH:mm',
                      onPick: () async {
                        final picked = await pickTime24h(
                          context,
                          initial: _startTime,
                        );
                        if (picked != null) {
                          setState(() {
                            _startTime = picked;
                            hourStartCtrl.text = formatHHmm(picked);
                          });
                          await _checkOverlapIfReadyVM();
                        }
                      },
                      validator: (_) {
                        final s = parseHHmm(hourStartCtrl.text);
                        if (s == null) return 'Wajib isi (HH:mm)';
                        final diff = durationBetweenHHmmWrap(
                          hourStartCtrl.text,
                          hourEndCtrl.text,
                        );
                        if (diff == null &&
                            parseHHmm(hourEndCtrl.text) != null) {
                          return 'Durasi 0';
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AbsorbPointer(
                  absorbing: widget.lockShiftFields,
                  child: Opacity(
                    opacity: widget.lockShiftFields ? 0.45 : 1.0,
                    child: TimeFormField(
                      controller: hourEndCtrl,
                      label: 'Jam Selesai',
                      hintText: 'HH:mm',
                      onPick: () async {
                        final picked = await pickTime24h(
                          context,
                          initial: _endTime ?? _startTime,
                        );
                        if (picked != null) {
                          setState(() {
                            _endTime = picked;
                            hourEndCtrl.text = formatHHmm(picked);
                          });
                          await _checkOverlapIfReadyVM();
                        }
                      },
                      validator: (_) {
                        final e = parseHHmm(hourEndCtrl.text);
                        if (e == null) return 'Wajib isi (HH:mm)';
                        final s = parseHHmm(hourStartCtrl.text);
                        if (s != null) {
                          final diff = durationBetweenHHmmWrap(
                            hourStartCtrl.text,
                            hourEndCtrl.text,
                          );
                          if (diff == null) return 'Durasi 0';
                        }
                        return null;
                      },
                    ),
                  ),
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

          // ── Baris 3: Regu & Operator + Hadir ─────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: ReguOperatorPickerField(
                  selectedRegu: _selectedRegu,
                  selectedOperators: _selectedOperators,
                  isLoading: _loadingReguOperator,
                  onTap: _openReguOperatorPicker,
                  errorText: _reguOperatorError,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: AppNumberField(
                  controller: hadirCtrl,
                  label: 'Hadir',
                  icon: Icons.people,
                  allowDecimal: false,
                  allowNegative: false,
                  hintText: '0',
                  isDense: true,
                  iconSize: 20,
                  fontSize: 14,
                  labelFontSize: 14,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                ),
              ),
            ],
          ),

          // ── Baris 4: Jenis Gilingan (hanya create) ───────────────
          if (!isEdit) ...[
            const SizedBox(height: 16),
            GilinganTypeDropdown(
              preselectId: null,
              onChanged: (gt) => setState(() => _selectedGilinganType = gt),
              validator: (v) => v == null ? 'Wajib pilih jenis gilingan' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions() {
    final vm = context.watch<OverlapViewModel>();
    final hasOverlap = vm.hasOverlap;
    final prodVm = context.watch<GilinganProductionViewModel>();
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
            backgroundColor: isEdit
                ? const Color(0xFFF57C00)
                : const Color(0xFF00897B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          child: Text(
            isSaving ? 'MENYIMPAN...' : 'SIMPAN',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
