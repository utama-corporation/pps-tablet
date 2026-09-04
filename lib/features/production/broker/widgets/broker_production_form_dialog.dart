// lib/features/production/broker/widgets/broker_production_form_dialog.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pps_tablet/features/operator/model/operator_model.dart';
import 'package:pps_tablet/features/production/shared/widgets/regu_operator_picker.dart';
import 'package:pps_tablet/features/production/shared/widgets/total_hours_pill.dart';
import '../../../../common/widgets/error_status_dialog.dart';

import '../../../../common/widgets/app_number_field.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../../mesin/model/mesin_model.dart';
import '../../../regu/model/regu_model.dart';
import '../../../shared/overlap/repository/overlap_repository.dart';
import '../../../shared/overlap/view_model/overlap_view_model.dart';
import '../../../shared/shift/widgets/shift_dropdown.dart';
import '../../shared/widgets/time_form_field.dart';
import '../model/broker_production_model.dart';
import '../view_model/broker_production_view_model.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../broker_type/model/broker_type_model.dart';
import '../../../broker_type/widgets/broker_type_dropdown.dart';
import '../repository/broker_production_repository.dart';

class BrokerProductionFormDialog extends StatefulWidget {
  final BrokerProduction? header;
  final Function(BrokerProduction)? onSave;
  final MstMesin? initialMesin;
  final DateTime? initialDate;
  final String? initialHourStart;
  final String? initialHourEnd;
  final int? initialShift;
  final int? initialOperatorId;
  final String? initialOperatorName;
  final int? initialReguId;
  final int? initialHadir;
  final int? initialJmlhAnggota;
  final bool isBackdateInput;
  final List<BrokerProduksiItem> existingProduksiList;

  const BrokerProductionFormDialog({
    super.key,
    this.header,
    this.onSave,
    this.initialMesin,
    this.initialDate,
    this.initialHourStart,
    this.initialHourEnd,
    this.initialShift,
    this.initialOperatorId,
    this.initialOperatorName,
    this.initialReguId,
    this.initialHadir,
    this.initialJmlhAnggota,
    this.isBackdateInput = false,
    this.existingProduksiList = const [],
  });

  @override
  State<BrokerProductionFormDialog> createState() =>
      _BrokerProductionFormDialogState();
}

class _BrokerProductionFormDialogState
    extends State<BrokerProductionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController noProduction;
  late final TextEditingController dateCreatedCtrl;
  late final TextEditingController mesinCtrl;
  late final TextEditingController jlhAnggotaCtrl;
  late final TextEditingController hadirCtrl;
  late final TextEditingController hourMeterCtrl;

  // State
  MstMesin? _selectedMesin;
  MstRegu? _selectedRegu;
  List<MstOperator> _selectedOperators = [];
  bool _loadingReguOperator = false;
  String? _reguOperatorError;
  int? _selectedShift;
  int? _selectedReguId;
  BrokerType? _selectedBrokerType;

  DateTime _selectedDate = DateTime.now();

  // --- time controllers ---
  late final TextEditingController hourStartCtrl;
  late final TextEditingController hourEndCtrl;

  // --- time state ---
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool get isEdit => widget.header != null;

  // kind untuk endpoint overlap (dialog ini broker)
  static const String _kind = 'broker';

  String? _directError;

  @override
  void initState() {
    super.initState();
    noProduction = TextEditingController(text: widget.header?.noProduksi ?? '');

    final DateTime seededDate = widget.header != null
        ? (parseAnyToDateTime(widget.header!.tglProduksi) ?? DateTime.now())
        : (widget.initialDate ?? DateTime.now());

    _selectedDate = seededDate;
    dateCreatedCtrl = TextEditingController(
      text: DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(seededDate),
    );

    _selectedMesin = widget.initialMesin;
    mesinCtrl = TextEditingController(
      text: widget.header?.namaMesin ?? widget.initialMesin?.namaMesin ?? '',
    );
    jlhAnggotaCtrl = TextEditingController(
      text:
          widget.header?.jmlhAnggota?.toString() ??
          widget.initialJmlhAnggota?.toString() ??
          '',
    );
    hadirCtrl = TextEditingController(
      text:
          widget.header?.hadir?.toString() ??
          widget.initialHadir?.toString() ??
          '',
    );
    hourMeterCtrl = TextEditingController(
      text: widget.header?.hourMeter?.toString() ?? '',
    );

    hourStartCtrl = TextEditingController(
      text: widget.header?.hourStart ?? widget.initialHourStart,
    );
    hourEndCtrl = TextEditingController(
      text: widget.header?.hourEnd ?? widget.initialHourEnd,
    );
    _selectedShift = widget.header?.shift ?? widget.initialShift;
    _selectedReguId = widget.header?.idRegu ?? widget.initialReguId;

    // ── Pre-fill regu & operator dari header (mode edit) ──────────────────
    final h = widget.header;
    if (h != null) {
      // Reconstruct MstRegu dari idRegu + namaRegu yang ada di response
      if (h.idRegu != null && (h.namaRegu ?? '').isNotEmpty) {
        _selectedRegu = MstRegu(
          idRegu: h.idRegu!,
          idBagian: 0,
          namaRegu: h.namaRegu!,
        );
      }

      // Reconstruct List<MstOperator> dari idOperators + namaOperators
      // namaOperators adalah string "NAMA1, NAMA2, ..."
      if (h.idOperators.isNotEmpty) {
        final names = h.namaOperators.split(',').map((s) => s.trim()).toList();
        _selectedOperators = List.generate(h.idOperators.length, (i) {
          return MstOperator(
            idOperator: h.idOperators[i],
            namaOperator: i < names.length ? names[i] : '',
            enable: true,
          );
        });
      }
    }
  }

  @override
  void dispose() {
    noProduction.dispose();
    dateCreatedCtrl.dispose();
    mesinCtrl.dispose();
    jlhAnggotaCtrl.dispose();
    hadirCtrl.dispose();
    hourMeterCtrl.dispose();
    hourStartCtrl.dispose();
    hourEndCtrl.dispose();
    super.dispose();
  }

  // --- helper untuk build jam 'HH:mm-HH:mm'
  String? _buildJamRange() {
    final start = hourStartCtrl.text.trim();
    final end = hourEndCtrl.text.trim();
    if (start.isEmpty || end.isEmpty) return null;
    return '$start-$end';
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

  Future<void> _submit() async {
    debugPrint('📝 [BROKER_FORM] _submit() started');

    // cek overlap dulu
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

    // pastikan ada mesin & operator & shift
    final mesinId = _selectedMesin?.idMesin ?? widget.header?.idMesin;
    if (mesinId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mesin wajib dipilih')));
      return;
    }

    final idOperatorList = _selectedOperators.map((o) => o.idOperator).toList();
    if (idOperatorList.isEmpty || _selectedRegu == null) {
      setState(() => _reguOperatorError = 'Regu & operator wajib dipilih');
      return;
    }

    if (_selectedShift == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shift wajib dipilih')));
      return;
    }

    final reguId = _selectedReguId ?? widget.header?.idRegu;

    final jamRange = _buildJamRange();
    if (jamRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam mulai & selesai wajib diisi')),
      );
      return;
    }

    // helper HH:mm -> HH:mm:00
    String _toSqlTime(String raw) {
      final t = raw.trim();
      if (t.isEmpty) return t;
      return t.length == 5 ? '$t:00' : t;
    }

    final hourStartSql = _toSqlTime(hourStartCtrl.text);
    final hourEndSql = _toSqlTime(hourEndCtrl.text);

    // parse angka
    final jlhAnggota = int.tryParse(jlhAnggotaCtrl.text.trim());
    final hadir = int.tryParse(hadirCtrl.text.trim());
    final hourMeter = double.tryParse(hourMeterCtrl.text.trim());

    // ✅ Read VM from PARENT Screen context
    final prodVm = context.read<BrokerProductionViewModel>();
    debugPrint(
      '📝 [BROKER_FORM] Got VM from context: VM hash=${prodVm.hashCode}',
    );
    debugPrint(
      '📝 [BROKER_FORM] Got controller from VM: controller hash=${prodVm.pagingController.hashCode}',
    );

    // show loading
    debugPrint('📝 [BROKER_FORM] Showing loading dialog...');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    BrokerProduction? result;

    try {
      if (isEdit) {
        debugPrint('📝 [BROKER_FORM] Calling updateProduksi...');
        result = await prodVm.updateProduksi(
          noProduksi: widget.header!.noProduksi,
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperator: idOperatorList.first,
          jam: jamRange,
          shift: _selectedShift!,
          hourStart: hourStartSql,
          hourEnd: hourEndSql,
          jmlhAnggota: jlhAnggota,
          hadir: hadir,
          hourMeter: hourMeter,
          idRegu: reguId,
        );
        debugPrint(
          '📝 [BROKER_FORM] updateProduksi returned: ${result?.noProduksi}',
        );
      } else if (_selectedBrokerType != null) {
        debugPrint('📝 [BROKER_FORM] Calling createProduksiWithJenis...');
        final computedDur = durationBetweenHHmmWrap(
          hourStartCtrl.text,
          hourEndCtrl.text,
        );
        final jamHours = computedDur != null
            ? computedDur.inMinutes / 60.0
            : 0.0;
        final repo = BrokerProductionRepository();
        result = await repo.createProduksiWithJenis(
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperators: idOperatorList,
          outputJenisId: _selectedBrokerType!.idBroker,
          outputJenisNama: _selectedBrokerType!.nama,
          jam: jamHours,
          shift: _selectedShift!,
          hourStart: hourStartSql,
          hourEnd: hourEndSql,
          hadir: hadir,
          idRegu: reguId,
        );
        debugPrint(
          '📝 [BROKER_FORM] createProduksiWithJenis returned: ${result?.noProduksi}',
        );
      } else {
        debugPrint('📝 [BROKER_FORM] Calling createProduksi...');
        result = await prodVm.createProduksi(
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperator: idOperatorList.first,
          jam: jamRange,
          shift: _selectedShift!,
          hourStart: hourStartSql,
          hourEnd: hourEndSql,
          jmlhAnggota: jlhAnggota,
          hadir: hadir,
          hourMeter: hourMeter,
          idRegu: reguId,
        );
        debugPrint(
          '📝 [BROKER_FORM] createProduksi returned: ${result?.noProduksi}',
        );
      }
    } catch (e) {
      debugPrint('❌ [BROKER_FORM] Exception during save: $e');
      _directError = e.toString();
    } finally {
      debugPrint('📝 [BROKER_FORM] Popping loading dialog...');
      if (mounted) {
        Navigator.of(context).pop();
        debugPrint('📝 [BROKER_FORM] Loading dialog popped');
      }
    }

    if (!mounted) {
      debugPrint('📝 [BROKER_FORM] Widget not mounted after save, returning');
      return;
    }

    debugPrint('📝 [BROKER_FORM] Checking result: ${result?.noProduksi}');

    if (result != null) {
      debugPrint('📝 [BROKER_FORM] Success detected: ${result.noProduksi}');

      widget.onSave?.call(result);

      Navigator.of(context).pop(result);
    } else {
      final rawErr = _directError ?? prodVm.saveError ?? 'Gagal menyimpan data';
      final errMsg = rawErr.startsWith('Exception: ')
          ? rawErr.substring('Exception: '.length)
          : rawErr;
      _directError = null;

      debugPrint('❌ [BROKER_FORM] Result is null, showing error: $errMsg');

      showDialog(
        context: context,
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menyimpan', message: errMsg),
      );
    }

    debugPrint('📝 [BROKER_FORM] _submit() completed');
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

      // hourStart / hourEnd come as "HH:mm:ss" — trim to "HH:mm"
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

  /// Panggil cek-overlap via ViewModel hanya jika input sudah lengkap:
  /// - Jam Mulai & Jam Selesai terisi
  /// - IdMesin tersedia
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
      idBagian: 2,
    );
    if (mounted) setState(() => _loadingReguOperator = false);
    if (result != null && mounted) {
      setState(() {
        _reguOperatorError = null;
        _selectedRegu = result.regu;
        _selectedReguId = result.regu.idRegu;
        _selectedOperators
          ..clear()
          ..addAll(result.operators);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('📝 [BROKER_FORM] build() called');

    // ✅ Verify we're using the correct VM
    final vm = context.read<BrokerProductionViewModel>();
    debugPrint('📝 [BROKER_FORM] VM from context: hash=${vm.hashCode}');
    debugPrint(
      '📝 [BROKER_FORM] Controller from VM: hash=${vm.pagingController.hashCode}',
    );

    final mq = MediaQuery.of(context);
    final keyboardInset = mq.viewInsets.bottom;
    final isLandscape = mq.orientation == Orientation.landscape;
    final maxDialogHeight = mq.size.height - 24;
    final dialogMaxWidth = isLandscape ? 680.0 : 620.0;
    final dialogInsets = isLandscape
        ? const EdgeInsets.symmetric(horizontal: 72, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16);

    return ChangeNotifierProvider(
      create: (_) => OverlapViewModel(repository: OverlapRepository()),
      child: Dialog(
        backgroundColor: Colors.white,
        insetPadding: dialogInsets,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogMaxWidth,
            maxHeight: maxDialogHeight.clamp(260, isLandscape ? 560 : 680),
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
                    padding: EdgeInsets.only(bottom: keyboardInset),
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
        'Produksi';

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris 1: Nama mesin (judul) + Tanggal (khusus backdate)
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
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Wajib pilih tanggal' : null,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 20),

          // Baris 2: Shift + Jam Mulai + Jam Selesai + Total Jam
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AbsorbPointer(
                absorbing: !widget.isBackdateInput,
                child: Opacity(
                  opacity: widget.isBackdateInput ? 1.0 : 0.45,
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
                  absorbing: !widget.isBackdateInput,
                  child: Opacity(
                    opacity: widget.isBackdateInput ? 1.0 : 0.45,
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
                  absorbing: !widget.isBackdateInput,
                  child: Opacity(
                    opacity: widget.isBackdateInput ? 1.0 : 0.45,
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

          // Baris 3: Regu & Operator (1 field) + Hadir
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

          const SizedBox(height: 16),

          // Baris 4: Jenis Broker (full width)
          BrokerTypeDropdown(
            preselectId: widget.header?.outputJenisId,
            onChanged: (bt) => setState(() => _selectedBrokerType = bt),
            validator: (v) => v == null ? 'Wajib pilih jenis broker' : null,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final vm = context.watch<OverlapViewModel>();
    final hasOverlap = vm.hasOverlap;

    // ✅ Watch VM from PARENT Screen context for isSaving state
    final prodVm = context.watch<BrokerProductionViewModel>();
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
