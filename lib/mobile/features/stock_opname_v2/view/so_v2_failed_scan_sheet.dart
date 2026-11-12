import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../model/so_v2_failed_scan.dart';
import '../view_model/so_v2_failed_scan_view_model.dart';
import 'so_v2_category_style.dart';

/// Sheet daftar label yang gagal dikirim ke server pada satu lokasi.
///
/// Entri retryable (jaringan / 5xx / 503) bisa dikirim ulang dari sini.
/// Entri permanen (duplikat, kategori salah, auth) ditampilkan sebagai
/// referensi saja karena tidak ada endpoint untuk memaksa server menerima.
class SoV2FailedScanSheet extends StatefulWidget {
  const SoV2FailedScanSheet({
    super.key,
    required this.stockOpnameNo,
    required this.blok,
    required this.locationId,
  });

  final String stockOpnameNo;
  final String blok;
  final int locationId;

  @override
  State<SoV2FailedScanSheet> createState() => _SoV2FailedScanSheetState();
}

class _SoV2FailedScanSheetState extends State<SoV2FailedScanSheet> {
  final DateFormat _timeFormat = DateFormat('dd/MM HH:mm');
  String? _progressLabel;

  Future<void> _retryAll() async {
    final store = context.read<SoV2FailedScanViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final report = await store.retryLocation(
      stockOpnameNo: widget.stockOpnameNo,
      blok: widget.blok,
      locationId: widget.locationId,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() => _progressLabel = 'Mengirim $done/$total...');
      },
    );
    if (!mounted) return;
    setState(() => _progressLabel = null);
    messenger.showSnackBar(
      SnackBar(
        content: Text(report.summary),
        backgroundColor: report.hasChanges ? Colors.green.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _remove(SoV2FailedScan entry) async {
    await context.read<SoV2FailedScanViewModel>().remove(entry);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<SoV2FailedScanViewModel>();
    final entries = store.entriesFor(
      stockOpnameNo: widget.stockOpnameNo,
      blok: widget.blok,
      locationId: widget.locationId,
    );
    final retryable = entries.where((entry) => entry.isRetryable).toList();
    final permanent = entries.where((entry) => !entry.isRetryable).toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: soV2ThemeBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Daftar Gagal (${entries.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (entries.isNotEmpty)
                    TextButton(
                      onPressed: () => _removeAll(context, store, entries),
                      child: const Text('Hapus semua'),
                    ),
                ],
              ),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Text(
                  'Semua label pada lokasi ini berhasil dikirim ke server.',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  _progressLabel ??
                      '${retryable.length} bisa dikirim ulang · '
                          '${permanent.length} permanen (perlu ditinjau)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
              if (retryable.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: store.isRetrying ? null : _retryAll,
                      style: FilledButton.styleFrom(
                        backgroundColor: soV2ThemeBlue,
                        foregroundColor: Colors.white,
                      ),
                      icon: store.isRetrying
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        store.isRetrying
                            ? 'Mengirim...'
                            : 'Kirim Ulang (${retryable.length})',
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  children: [
                    for (final entry in retryable)
                      _FailedTile(
                        entry: entry,
                        timeFormat: _timeFormat,
                        onRemove: () => _remove(entry),
                      ),
                    if (retryable.isNotEmpty && permanent.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(4, 14, 4, 6),
                        child: Text(
                          'Permanen — tidak bisa dikirim ulang',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    for (final entry in permanent)
                      _FailedTile(
                        entry: entry,
                        timeFormat: _timeFormat,
                        onRemove: () => _remove(entry),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _removeAll(
    BuildContext context,
    SoV2FailedScanViewModel store,
    List<SoV2FailedScan> entries,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus daftar gagal?'),
        content: Text(
          '${entries.length} label akan dihapus dari daftar. Label yang sudah '
          'terkirim ke server tidak terpengaruh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await store.clearLocation(
      stockOpnameNo: widget.stockOpnameNo,
      blok: widget.blok,
      locationId: widget.locationId,
    );
  }
}

class _FailedTile extends StatelessWidget {
  const _FailedTile({
    required this.entry,
    required this.timeFormat,
    required this.onRemove,
  });

  final SoV2FailedScan entry;
  final DateFormat timeFormat;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = entry.isRetryable ? Colors.orange.shade700 : Colors.red.shade700;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.labelNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.message,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.reason.name}'
                  '${entry.retryCount > 0 ? ' · gagal ${entry.retryCount}x' : ''}'
                  ' · ${timeFormat.format(entry.lastAttemptAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Hapus dari daftar',
            onPressed: onRemove,
            icon: Icon(Icons.close, size: 18, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
