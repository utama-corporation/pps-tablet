// lib/features/bahan_pendukung/penerimaan/widgets/penerimaan_bahan_pendukung_header_form_dialog.dart
//
// Dialog header penerimaan bahan pendukung — hanya memilih tanggal.
// Shift dan jam tidak lagi menjadi bagian dari header. Tim sudah
// diketahui dari kartu yang di-tap. Tombol SIMPAN langsung hit
// createHeader (fase 1) sehingga NoPenerimaan sudah dibuat di
// database begitu dialog ini ditutup dengan sukses.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../model/tim_penerimaan_model.dart';
import '../repository/penerimaan_bahan_pendukung_repository.dart';

class PenerimaanBahanPendukungCreateDialog extends StatefulWidget {
  final TimPenerimaanInfo tim;

  const PenerimaanBahanPendukungCreateDialog({super.key, required this.tim});

  @override
  State<PenerimaanBahanPendukungCreateDialog> createState() =>
      _PenerimaanBahanPendukungCreateDialogState();
}

class _PenerimaanBahanPendukungCreateDialogState
    extends State<PenerimaanBahanPendukungCreateDialog> {
  late final PenerimaanBahanPendukungRepository _repo;

  late final TextEditingController _tanggalCtrl;
  DateTime _tanggal = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repo = PenerimaanBahanPendukungRepository(api: context.read<ApiClient>());
    _tanggalCtrl = TextEditingController(
      text: DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(_tanggal),
    );
  }

  @override
  void dispose() {
    _tanggalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('id', 'ID'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _tanggal = picked;
      _tanggalCtrl.text = DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(picked);
    });
  }

  Future<void> _submit() async {
    setState(() => _isSaving = true);
    try {
      final result = await _repo.createHeader(
        tglPenerimaan: _tanggal,
        idTim: widget.tim.idTim,
      );
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      await showDialog<void>(
        context: context,
        builder: (_) => ErrorStatusDialog(title: 'Gagal Menyimpan', message: e.toString()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.orientation == Orientation.landscape;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: isLandscape
          ? const EdgeInsets.symmetric(horizontal: 72, vertical: 12)
          : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isLandscape ? 520 : 440,
          maxHeight: (mq.size.height - 24).clamp(260, 400),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add, color: Colors.teal.shade700, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${widget.tim.namaTim} — Penerimaan Bahan Pendukung',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2937),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              TextFormField(
                controller: _tanggalCtrl,
                readOnly: true,
                onTap: _pickTanggal,
                decoration: InputDecoration(
                  labelText: 'Tanggal',
                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('BATAL', style: TextStyle(fontSize: 15)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    child: Text(
                      _isSaving ? 'MENYIMPAN...' : 'SIMPAN',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
