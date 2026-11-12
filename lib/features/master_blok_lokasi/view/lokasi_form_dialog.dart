import 'package:flutter/material.dart';

import '../../../core/network/api_error.dart';
import '../model/master_blok_lokasi_models.dart';
import '../view_model/master_blok_lokasi_view_model.dart';

class LokasiFormDialog extends StatefulWidget {
  const LokasiFormDialog({super.key, required this.viewModel, this.edit});

  final MasterBlokLokasiViewModel viewModel;
  final LokasiRow? edit;

  @override
  State<LokasiFormDialog> createState() => _LokasiFormDialogState();
}

class _LokasiFormDialogState extends State<LokasiFormDialog> {
  late final TextEditingController _description;
  late bool _enable;
  int? _nextId;
  bool _submitting = false;
  String _error = '';

  bool get _isEdit => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    _description = TextEditingController(text: edit?.description ?? '');
    _enable = edit?.enable ?? true;
    if (edit == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          final nextId = await widget.viewModel.nextIdLokasi();
          if (mounted) setState(() => _nextId = nextId);
        } catch (_) {}
      });
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final description = _description.text.trim();
    if (description.isEmpty) {
      setState(() => _error = 'Deskripsi lokasi wajib diisi.');
      return;
    }
    if (description.length > 150) {
      setState(() => _error = 'Deskripsi lokasi maksimal 150 karakter.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = '';
    });
    try {
      await widget.viewModel.saveLokasi(
        edit: widget.edit,
        description: description,
        enable: _enable,
      );
      if (mounted) Navigator.of(context).pop(description);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final edit = widget.edit;
    final blok = widget.viewModel.selectedBlok ?? '';
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isEdit ? Colors.orange.shade50 : Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit : Icons.add_location_outlined,
                      color: _isEdit
                          ? Colors.orange.shade700
                          : Colors.teal.shade700,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit
                              ? 'Ubah Lokasi #${edit!.idLokasi}'
                              : 'Tambah Lokasi',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        Text(
                          _isEdit
                              ? 'Blok $blok'
                              : 'Blok $blok'
                                    '${_nextId != null ? ' · ID berikutnya #$_nextId' : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _description,
                autofocus: true,
                maxLength: 150,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Lokasi',
                  hintText: 'mis. Rak A baris 1',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                value: _enable,
                onChanged: (v) => setState(() => _enable = v),
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Lokasi aktif',
                  style: TextStyle(fontSize: 14),
                ),
                subtitle: Text(
                  _enable
                      ? 'Bisa dipakai di mapping & stock opname'
                      : 'Disembunyikan dari pilihan produksi',
                  style: const TextStyle(fontSize: 12),
                ),
                activeThumbColor: const Color(0xFF15803D),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _error,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _submitting ? null : () => Navigator.pop(context),
                    child: const Text('BATAL'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isEdit
                          ? const Color(0xFFF57C00)
                          : const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'SIMPAN',
                            style: TextStyle(fontWeight: FontWeight.bold),
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
