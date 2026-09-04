import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../core/network/endpoints.dart';
import '../../../../core/services/token_storage.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/time_formatter.dart';

import '../../../cetakan/model/mst_cetakan_model.dart';
import '../../../furniture_material/model/furniture_material_lookup_model.dart';
import '../../../mesin/model/mesin_model.dart';
import '../../../operator/model/operator_model.dart';
import '../../../regu/model/regu_model.dart';
import '../../../shared/overlap/repository/overlap_repository.dart';
import '../../../shared/overlap/view_model/overlap_view_model.dart';
import '../../../shared/shift/widgets/shift_dropdown.dart';
import '../../../warna/model/warna_model.dart';
import '../../shared/widgets/regu_operator_picker.dart';
import '../../shared/widgets/time_form_field.dart';
import '../../shared/widgets/total_hours_pill.dart';
import 'cetakan_warna_material_picker.dart';

import '../model/inject_production_model.dart';
import '../view_model/inject_production_view_model.dart';

class InjectProductionFormDialog extends StatefulWidget {
  final InjectProduction? header;
  final Function(InjectProduction)? onSave;

  /// Params untuk create dari mesin screen (pre-fill)
  final MstMesin? initialMesin;
  final DateTime? initialDate;
  final int? initialShift;
  final String? initialHourStart;
  final String? initialHourEnd;
  final bool isBackdateInput;

  const InjectProductionFormDialog({
    super.key,
    this.header,
    this.onSave,
    this.initialMesin,
    this.initialDate,
    this.initialShift,
    this.initialHourStart,
    this.initialHourEnd,
    this.isBackdateInput = false,
  });

  @override
  State<InjectProductionFormDialog> createState() =>
      _InjectProductionFormDialogState();
}

class _InjectProductionFormDialogState
    extends State<InjectProductionFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController dateCreatedCtrl;
  late final TextEditingController hourStartCtrl;
  late final TextEditingController hourEndCtrl;
  MstMesin? _selectedMesin;
  MstRegu? _selectedRegu;
  List<MstOperator> _selectedOperators = [];
  bool _loadingReguOperator = false;
  String? _reguOperatorError;
  bool _loadingCetakanWarna = false;
  int? _selectedShift;

  MstCetakan? _selectedCetakan;
  MstWarna? _selectedWarna;
  FurnitureMaterialLookupResult? _selectedFurnitureMaterial;

  static const int _idBagianInject = 4;
  static const String _kind = 'inject';
  static const int _noneFurnitureId = 0;
  static const FurnitureMaterialLookupResult _noneFurnitureMaterial =
      FurnitureMaterialLookupResult(
        idFurnitureMaterial: _noneFurnitureId,
        nama: 'Tidak ada Furniture Material',
        itemCode: null,
        enable: false,
      );

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool get isEdit => widget.header != null;

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

    _selectedMesin = widget.initialMesin;
    _selectedShift = widget.header?.shift ?? widget.initialShift;

    final initStart = widget.header?.hourStart ?? widget.initialHourStart;
    final initEnd = widget.header?.hourEnd ?? widget.initialHourEnd;
    hourStartCtrl = TextEditingController(text: initStart ?? '');
    hourEndCtrl = TextEditingController(text: initEnd ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkOverlap();
    });

    _selectedFurnitureMaterial = _noneFurnitureMaterial;

    final h = widget.header;
    if (h != null) {
      // Pre-fill operator
      if (h.idOperator != 0) {
        _selectedOperators = [
          MstOperator(
            idOperator: h.idOperator,
            namaOperator: h.namaOperator,
            enable: true,
          ),
        ];
      }
      // Pre-fill cetakan (stub — picker akan replace dengan objek lengkap saat user membuka)
      if (h.idCetakan != null && h.idCetakan != 0) {
        _selectedCetakan = MstCetakan(
          idCetakan: h.idCetakan!,
          idBj: 0,
          enable: true,
          namaCetakan: h.namaCetakan ?? '',
          lebar: 0,
          panjang: 0,
          tebal: 0,
          beratCetakan: 0,
          beratCavity: 0,
          jumlahCavity: 0,
          hotRunner: false,
          hydrolicCore: false,
          electricalSwitch: false,
          inputAngin: false,
          inputAir: false,
          cycleTime: 0,
          pcsPerJam: 0,
        );
      }
      // Pre-fill warna
      if (h.idWarna != null && h.idWarna != 0) {
        _selectedWarna = MstWarna(
          idWarna: h.idWarna!,
          warna: h.namaWarna ?? '',
          enable: true,
        );
      }
      // Pre-fill furniture material
      if (h.idFurnitureMaterial != null && h.idFurnitureMaterial != 0) {
        _selectedFurnitureMaterial = FurnitureMaterialLookupResult(
          idFurnitureMaterial: h.idFurnitureMaterial!,
          nama: h.namaFurnitureMaterial ?? '',
          itemCode: null,
          enable: true,
        );
      }
      // Pre-fill regu
      if (h.idRegu != null && h.idRegu != 0) {
        _selectedRegu = MstRegu(
          idRegu: h.idRegu!,
          idBagian: 0,
          namaRegu: h.namaRegu ?? '',
        );
      }
    }
  }

  bool _didInitialOverlapCheck = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitialOverlapCheck) {
      _didInitialOverlapCheck = true;
      // Check overlap pada nilai pre-filled saat dialog pertama kali terbuka
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkOverlap();
      });
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
      dateCreatedCtrl.text = DateFormat(
        'EEEE, dd MMM yyyy',
        'id_ID',
      ).format(picked);
    });
    if (_selectedShift != null) await _fetchShiftHour(_selectedShift!);
    await _checkOverlap();
  }

  Future<void> _fetchShiftHour(int shift) async {
    final tanggal = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final base = ApiConstants.baseUrl.replaceFirst(RegExp(r'/*$'), '');
    final url = Uri.parse(
      '$base/api/mst/inject/shift/hour?tanggal=$tanggal&shift=$shift',
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
    final idMesin = _selectedMesin?.idMesin ?? widget.header?.idMesin;
    debugPrint(
      '🔍 [OVERLAP] _checkOverlap called → start="$start", end="$end", idMesin=$idMesin',
    );
    if (start.isEmpty || end.isEmpty || idMesin == null) {
      debugPrint(
        '🔍 [OVERLAP] early-return: start.isEmpty=${start.isEmpty}, end.isEmpty=${end.isEmpty}, idMesin==null=${idMesin == null}',
      );
      vm.clear();
      return;
    }
    final excludeNo = isEdit ? widget.header!.noProduksi : null;
    debugPrint(
      '🔍 [OVERLAP] hitting API → kind=$_kind, date=${_selectedDate.toIso8601String()}, idMesin=$idMesin, start=$start, end=$end, exclude=$excludeNo',
    );
    await vm.check(
      kind: _kind,
      date: _selectedDate,
      idMesin: idMesin,
      hourStart: start,
      hourEnd: end,
      excludeNo: excludeNo,
    );
  }

  Future<void> _openReguOperatorPicker() async {
    if (!mounted) return;
    setState(() => _loadingReguOperator = true);
    final result = await showReguOperatorPicker(
      context,
      initialRegu: _selectedRegu,
      initialSelected: _selectedOperators,
      idBagian: _idBagianInject,
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

  Future<void> _openCetakanWarnaPicker() async {
    if (!mounted) return;
    setState(() => _loadingCetakanWarna = true);
    final result = await showCetakanWarnaMaterialPicker(
      context,
      initialCetakan: _selectedCetakan,
      initialWarna: _selectedWarna,
      initialMaterial:
          _selectedFurnitureMaterial?.idFurnitureMaterial == _noneFurnitureId
          ? null
          : _selectedFurnitureMaterial,
    );
    if (mounted) setState(() => _loadingCetakanWarna = false);
    if (result != null && mounted) {
      setState(() {
        _selectedCetakan = result.cetakan;
        _selectedWarna = result.warna;
        _selectedFurnitureMaterial = result.material ?? _noneFurnitureMaterial;
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

    final start = hourStartCtrl.text.trim();
    final end = hourEndCtrl.text.trim();
    if (start.isEmpty || end.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam mulai & selesai wajib diisi')),
      );
      return;
    }

    if (_selectedCetakan == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cetakan wajib dipilih')));
      return;
    }
    if (_selectedWarna == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Warna wajib dipilih')));
      return;
    }

    String toSqlTime(String raw) {
      final t = raw.trim();
      return (t.isNotEmpty && t.length == 5) ? '$t:00' : t;
    }

    final hourStartSql = toSqlTime(start);
    final hourEndSql = toSqlTime(end);

    final dur = durationBetweenHHmmWrap(start, end);
    final jamKerja = dur?.inHours;

    final pickedFm = _selectedFurnitureMaterial;
    final int? idFurnitureMaterial =
        (pickedFm == null || pickedFm.idFurnitureMaterial == _noneFurnitureId)
        ? null
        : pickedFm.idFurnitureMaterial;

    final prodVm = context.read<InjectProductionViewModel>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    InjectProduction? result;

    try {
      if (isEdit) {
        result = await prodVm.updateProduksi(
          noProduksi: widget.header!.noProduksi,
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperators: idOperatorList,
          idRegu: _selectedRegu?.idRegu,
          shift: _selectedShift!,
          jam: jamKerja,
          idCetakan: _selectedCetakan!.idCetakan,
          idWarna: _selectedWarna!.idWarna,
          idFurnitureMaterial: idFurnitureMaterial,
          hourStart: hourStartSql,
          hourEnd: hourEndSql,
        );
      } else {
        result = await prodVm.createProduksi(
          tglProduksi: _selectedDate,
          idMesin: mesinId,
          idOperators: idOperatorList,
          idRegu: _selectedRegu?.idRegu,
          shift: _selectedShift!,
          jam: jamKerja,
          idCetakan: _selectedCetakan!.idCetakan,
          idWarna: _selectedWarna!.idWarna,
          idFurnitureMaterial: idFurnitureMaterial,
          hourStart: hourStartSql,
          hourEnd: hourEndSql,
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }

    if (!mounted) return;

    if (result != null) {
      result = result.copyWith(
        namaJenis: result.namaJenis ?? _selectedCetakan?.namaCetakan,
        namaCetakan: result.namaCetakan ?? _selectedCetakan?.namaCetakan,
        namaWarna: result.namaWarna ?? _selectedWarna?.warna,
        namaFurnitureMaterial:
            result.namaFurnitureMaterial ??
            (_selectedFurnitureMaterial?.idFurnitureMaterial == _noneFurnitureId
                ? null
                : _selectedFurnitureMaterial?.nama),
      );
      widget.onSave?.call(result);
      Navigator.of(context).pop(result);
    } else {
      final errMsg = prodVm.saveError ?? 'Gagal menyimpan data produksi';
      await showDialog<void>(
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

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => OverlapViewModel(repository: OverlapRepository()),
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
            maxWidth: isLandscape ? 700 : 640,
            maxHeight: (mq.size.height - 24).clamp(
              300,
              isLandscape ? 620 : 740,
            ),
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
    final ovm = context.watch<OverlapViewModel>();
    final dur = durationBetweenHHmmWrap(hourStartCtrl.text, hourEndCtrl.text);
    final startFilled = hourStartCtrl.text.trim().isNotEmpty;
    final endFilled = hourEndCtrl.text.trim().isNotEmpty;
    final hasDurationError = startFilled && endFilled && dur == null;
    final hasOverlap = ovm.hasOverlap;
    final overlapMsg =
        ovm.overlapMessage ?? 'Jam ini bentrok dengan dokumen lain';

    final mesinName =
        _selectedMesin?.namaMesin ??
        widget.header?.namaMesin ??
        widget.initialMesin?.namaMesin ??
        (isEdit ? 'Edit Produksi Inject' : 'Tambah Produksi Inject');

    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Judul ────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEdit ? Colors.orange.shade50 : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isEdit ? Icons.edit : Icons.add,
                  color: isEdit ? Colors.orange.shade700 : Colors.teal.shade700,
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

          // ── Baris 1: Shift + Jam Mulai + Jam Selesai + Total ─────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 190,
                child: ShiftDropdown(
                  preselectId: widget.header?.shift ?? widget.initialShift,
                  enabled: widget.isBackdateInput || isEdit,
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
                  enabled: widget.isBackdateInput || isEdit,
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
                      await _checkOverlap();
                    }
                  },
                  validator: (_) {
                    final s = parseHHmm(hourStartCtrl.text);
                    if (s == null) return 'Wajib isi (HH:mm)';
                    final diff = durationBetweenHHmmWrap(
                      hourStartCtrl.text,
                      hourEndCtrl.text,
                    );
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
                  enabled: widget.isBackdateInput || isEdit,
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
                      await _checkOverlap();
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

          // ── Baris 2: Regu & Operator ─────────────────────────────
          ReguOperatorPickerField(
            selectedRegu: _selectedRegu,
            selectedOperators: _selectedOperators,
            isLoading: _loadingReguOperator,
            onTap: _openReguOperatorPicker,
            errorText: _reguOperatorError,
          ),

          const SizedBox(height: 16),

          // ── Baris 3: Cetakan + Warna + Furniture Material ────────
          CetakanWarnaMaterialPickerField(
            selectedCetakan: _selectedCetakan,
            selectedWarna: _selectedWarna,
            selectedMaterial:
                _selectedFurnitureMaterial?.idFurnitureMaterial ==
                    _noneFurnitureId
                ? null
                : _selectedFurnitureMaterial,
            isLoading: _loadingCetakanWarna,
            onTap: _openCetakanWarnaPicker,
          ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final ovm = context.watch<OverlapViewModel>();
    final hasOverlap = ovm.hasOverlap;
    final prodVm = context.watch<InjectProductionViewModel>();
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
