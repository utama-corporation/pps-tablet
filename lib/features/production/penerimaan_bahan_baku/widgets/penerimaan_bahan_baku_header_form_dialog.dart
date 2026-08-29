// lib/features/production/penerimaan_bahan_baku/widgets/penerimaan_bahan_baku_header_form_dialog.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../common/widgets/error_status_dialog.dart';
import '../../../../core/network/api_client.dart';
import '../model/tim_penerimaan_bahan_baku_model.dart';
import '../repository/penerimaan_bahan_baku_repository.dart';

/// Dialog header — format sama seperti `WashingProductionFormDialog` (judul +
/// form ringkas + baris aksi BATAL/SIMPAN). Hanya menampung Tanggal — Shift/
/// Jam/Operator sudah dihapus dari header, mengikuti format Bahan Pendukung/
/// Barang Dagang. Tim sudah diketahui dari kartu yang di-tap sehingga tidak
/// perlu dipilih lagi di sini. Supplier & No Plat BUKAN atribut tim, jadi
/// diinput per section (Bahan Baku Pakai / Bahan Baku Proses) di
/// `PenerimaanBahanBakuInputScreen`.
///
/// Tombol SIMPAN langsung hit `PenerimaanBahanBakuRepository.createHeader`
/// (fase 1) sehingga NoPenerimaan sudah dibuat di database begitu dialog ini
/// ditutup dengan sukses; pallet/sak baru ditambahkan belakangan di screen
/// input penuh (fase 2), mengikuti pola washing production: dialog kecil
/// untuk header → screen input untuk data detail.
class PenerimaanBahanBakuCreateDialog extends StatefulWidget {
  final TimPenerimaanInfo tim;

  const PenerimaanBahanBakuCreateDialog({super.key, required this.tim});

  @override
  State<PenerimaanBahanBakuCreateDialog> createState() =>
      _PenerimaanBahanBakuCreateDialogState();
}

class _PenerimaanBahanBakuCreateDialogState
    extends State<PenerimaanBahanBakuCreateDialog> {
  late final PenerimaanBahanBakuRepository _repo;

  late final TextEditingController _tanggalCtrl;
  DateTime _tanggal = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _repo = PenerimaanBahanBakuRepository(api: context.read<ApiClient>());
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
      _tanggalCtrl.text = DateFormat(
        'EEEE, dd MMM yyyy',
        'id_ID',
      ).format(picked);
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
        builder: (_) =>
            ErrorStatusDialog(title: 'Gagal Menyimpan', message: e.toString()),
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
          maxHeight: (mq.size.height - 24).clamp(220, 340),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
    );
  }

  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Judul ────────────────────────────────────────────────────────
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
                '${widget.tim.namaTim} — Penerimaan Bahan Baku',
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
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
    );
  }
}
