// lib/features/production/shared/widgets/qc_downtime_dialog.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/qc_downtime_item.dart';

typedef QcDowntimeFetcher = Future<QcDowntimeDetail> Function();
typedef QcDowntimeCreator = Future<QcDowntimeItem> Function(
  String hourStart,
  String keterangan,
);
typedef QcDowntimeUpdater = Future<QcDowntimeItem> Function(
  int id,
  String keterangan,
);
typedef QcDowntimeDeleter = Future<void> Function(int id);

const _accent = Color(0xFF0277BD);
const _green = Color(0xFF15803D);
const _downtimeColor = Color(0xFFB45309);
const _defaultAccent = _accent;

// Jeda setelah jam akhir bucket sebelum QC bisa diinput (mis. range
// 07:00-08:00 sudah bisa diinput mulai jam 08:00, begitu jamnya berakhir).
// Window bucket berikutnya selalu dimulai tepat saat window bucket ini
// tertutup — sama persis dengan pola QC inject.
const _kQcInputOpenDelay = Duration.zero;

enum _QcBucketStatus { locked, available, expired, submitted }

/// Dialog input QC tiap jam untuk produksi tanpa metrik numerik (washing &
/// broker): hanya mencatat keterangan downtime per bucket jam produksi.
/// Pola window meniru inject QC: bucket hanya bisa diinput dalam jendela
/// 1 jam setelah jam-nya berakhir; jika terlewat muncul pesan
/// "Jam ini sudah lewat dan tidak diinput"; countdown sisa waktu ditampilkan.
class QcDowntimeDialog extends StatefulWidget {
  const QcDowntimeDialog({
    super.key,
    required this.noProduksi,
    required this.fetch,
    required this.create,
    required this.update,
    required this.delete,
    this.namaMesin,
    this.shift,
    this.hourStart,
    this.hourEnd,
    this.tglProduksi,
    this.outputJenisList = const [],
    this.accent = _defaultAccent,
  });

  final String noProduksi;
  final QcDowntimeFetcher fetch;
  final QcDowntimeCreator create;
  final QcDowntimeUpdater update;
  final QcDowntimeDeleter delete;
  final String? namaMesin;
  final int? shift;
  final String? hourStart;
  final String? hourEnd;
  final DateTime? tglProduksi;
  final List<String> outputJenisList;
  final Color accent;

  @override
  State<QcDowntimeDialog> createState() => _QcDowntimeDialogState();
}

class _QcDowntimeDialogState extends State<QcDowntimeDialog> {
  List<String> _bucketLabels = [];
  // Waktu window QC bucket ini terbuka (akhir jam bucket + delay).
  final Map<String, DateTime> _bucketOpensAt = {};
  // Waktu window bucket ini tertutup — langsung dari server (QcDowntimeBucket).
  final Map<String, DateTime> _bucketClosesAt = {};
  final Map<String, QcDowntimeItem?> _submitted = {};
  bool _isLoading = true;

  Timer? _statusTimer;
  // Tanggal produksi terkini, fallback ke nilai awal dari pemanggil.
  DateTime? _tglProduksi;

  @override
  void initState() {
    super.initState();
    _tglProduksi = widget.tglProduksi;
    _load();
    // Tick tiap detik supaya countdown buka/tutup window responsif (mm:ss).
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // ── Fallback: hitung bucket lokal bila backend belum mengirim buckets ─

  static int? _parseMinutes(String? v) {
    final raw = (v ?? '').trim();
    if (raw.isEmpty) return null;
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  static String _fmt(DateTime v) =>
      '${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}';

  // Pilih hari (hari ini/kemarin) yang membuat window shift benar mencakup
  // waktu sekarang; untuk produksi lampau pakai tglProduksi asli.
  static DateTime _resolveAnchor(
    String hourStart,
    String hourEnd,
    DateTime? knownDate,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startMin = _parseMinutes(hourStart);
    final endMin = _parseMinutes(hourEnd);
    if (startMin == null || endMin == null) {
      return knownDate != null
          ? DateTime(knownDate.year, knownDate.month, knownDate.day)
          : today;
    }
    var duration = endMin - startMin;
    if (duration <= 0) duration += 24 * 60;
    for (final anchor in [today, today.subtract(const Duration(days: 1))]) {
      final startDt = anchor.add(Duration(minutes: startMin));
      final windowEnd = startDt.add(Duration(minutes: duration + 60));
      if (!now.isBefore(startDt) && now.isBefore(windowEnd)) {
        return anchor;
      }
    }
    if (knownDate != null) {
      return DateTime(knownDate.year, knownDate.month, knownDate.day);
    }
    return today;
  }

  static List<String> _computeBuckets(
    String hourStart,
    String hourEnd,
    DateTime anchor,
  ) {
    final startMin = _parseMinutes(hourStart);
    final endMin = _parseMinutes(hourEnd);
    if (startMin == null || endMin == null) return [];
    var duration = endMin - startMin;
    if (duration <= 0) duration += 24 * 60;
    if (duration <= 0) return [];
    final startDt = anchor.add(Duration(minutes: startMin));
    final labels = <String>[];
    final startRem = startMin % 60;
    final firstStep = startRem == 0 ? 60 : (60 - startRem);
    var offset = 0;
    while (offset < duration) {
      final step = (offset == 0 && startRem != 0) ? firstStep : 60;
      final nextOffset = (offset + step) > duration ? duration : offset + step;
      final s = startDt.add(Duration(minutes: offset));
      final e = startDt.add(Duration(minutes: nextOffset));
      labels.add('${_fmt(s)} - ${_fmt(e)}');
      offset = nextOffset;
    }
    return labels;
  }

  void _populateBucketTimes(String hourStart, DateTime anchor) {
    final startMin = _parseMinutes(hourStart);
    if (startMin == null) return;
    final startDt = anchor.add(Duration(minutes: startMin));
    for (final label in _bucketLabels) {
      final parts = label.split(' - ');
      if (parts.length < 2) continue;
      final s = _parseMinutes(parts[0].trim());
      final e = _parseMinutes(parts[1].trim());
      if (s == null || e == null) continue;

      var sOffset = s - startMin;
      if (sOffset < 0) sOffset += 24 * 60;
      var eOffset = e - startMin;
      if (eOffset <= sOffset) eOffset += 24 * 60;

      final endDt = startDt.add(Duration(minutes: eOffset));
      _bucketOpensAt[label] = endDt.add(_kQcInputOpenDelay);
    }
  }

  DateTime? _closesAtFor(String label) {
    final fromServer = _bucketClosesAt[label];
    if (fromServer != null) return fromServer;
    final idx = _bucketLabels.indexOf(label);
    if (idx == -1) return null;
    if (idx + 1 < _bucketLabels.length) {
      return _bucketOpensAt[_bucketLabels[idx + 1]];
    }
    return _bucketOpensAt[label]?.add(const Duration(hours: 1));
  }

  bool _isWithinInputWindow(String label) {
    final opensAt = _bucketOpensAt[label];
    if (opensAt == null) return false;
    final now = DateTime.now();
    if (now.isBefore(opensAt)) return false;
    final closesAt = _closesAtFor(label);
    if (closesAt != null && !now.isBefore(closesAt)) return false;
    return true;
  }

  _QcBucketStatus _statusFor(String label) {
    if (_submitted[label] != null) return _QcBucketStatus.submitted;
    final opensAt = _bucketOpensAt[label];
    if (opensAt == null) return _QcBucketStatus.locked;
    if (_isWithinInputWindow(label)) return _QcBucketStatus.available;
    final now = DateTime.now();
    if (now.isBefore(opensAt)) return _QcBucketStatus.locked;
    return _QcBucketStatus.expired;
  }

  // Edit hanya boleh selama window input bucket masih terbuka.
  bool _canEditBucket(String label) => _isWithinInputWindow(label);

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final detail = await widget.fetch();
      if (!mounted) return;
      _tglProduksi = detail.header.tglProduksi != null
          ? DateTime.tryParse(detail.header.tglProduksi!)
          : widget.tglProduksi;

      final shiftHrStart = widget.hourStart ??
          detail.header.hourStart;
      final shiftHrEnd = widget.hourEnd ?? detail.header.hourEnd;

      if (detail.buckets.isNotEmpty) {
        _bucketLabels = detail.buckets.map((b) => b.label).toList();
        for (final b in detail.buckets) {
          _bucketOpensAt[b.label] = b.opensAt;
          _bucketClosesAt[b.label] = b.closesAt;
        }
      } else if (shiftHrStart != null && shiftHrEnd != null) {
        final anchor = _resolveAnchor(shiftHrStart, shiftHrEnd, _tglProduksi);
        _bucketLabels = _computeBuckets(shiftHrStart, shiftHrEnd, anchor);
        _populateBucketTimes(shiftHrStart, anchor);
      }

      final map = <String, QcDowntimeItem?>{};
      for (final label in _bucketLabels) {
        final bucketHour = label.split(' - ').first.trim();
        map[label] = _itemForHour(detail.items, bucketHour);
      }
      setState(() => _submitted.addAll(map));
    } catch (_) {
      // Fallback bila endpoint gagal total: hitung dari jam yang dikirim
      // pemanggil (anchor = tglProduksi asli), sehingga status terjatuh ke
      // "Terlewat" untuk data lampau, bukan "Terkunci".
      if (widget.hourStart != null && widget.hourEnd != null) {
        final anchor = _resolveAnchor(
          widget.hourStart!,
          widget.hourEnd!,
          widget.tglProduksi,
        );
        _bucketLabels = _computeBuckets(
          widget.hourStart!,
          widget.hourEnd!,
          anchor,
        );
        _populateBucketTimes(widget.hourStart!, anchor);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  QcDowntimeItem? _itemForHour(List<QcDowntimeItem> items, String hourStart) {
    for (final item in items) {
      if (item.hourStart == hourStart) return item;
    }
    return null;
  }

  void _onSubmitted(String label, QcDowntimeItem item) {
    setState(() => _submitted[label] = item);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildMetaStrip(),
            const Divider(height: 1, color: Color(0xFFE2E6EA)),
            Flexible(
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _bucketLabels.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'Tidak ada range jam produksi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _bucketLabels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final label = _bucketLabels[i];
                        final hourStart = label.split(' - ').first.trim();
                        return _QcBucketRow(
                          label: label,
                          hourStart: hourStart,
                          status: _statusFor(label),
                          canEdit: _canEditBucket(label),
                          submittedItem: _submitted[label],
                          windowOpensAt: _bucketOpensAt[label],
                          windowClosesAt: _closesAtFor(label),
                          accent: accent,
                          onCreate: (keterangan) =>
                              widget.create(hourStart, keterangan),
                          onUpdate: (id, keterangan) =>
                              widget.update(id, keterangan),
                          onDelete: (id) => widget.delete(id),
                          onSubmitted: (item) => _onSubmitted(label, item),
                          onDeleted: () {
                            setState(() => _submitted.remove(label));
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final machineName = (widget.namaMesin ?? '').trim();
    final tgl = _tglProduksi;
    final tglStr = tgl != null
        ? DateFormat('dd MMM yyyy', 'id_ID').format(tgl)
        : '-';

    return Container(
      decoration: BoxDecoration(
        color: widget.accent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.fact_check_outlined,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'INPUT QC',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      machineName.isNotEmpty ? machineName : 'Quality Control',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white.withValues(alpha: 0.18),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.close, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _headerChip(Icons.calendar_today_outlined, tglStr),
              _headerChip(Icons.groups_outlined, 'Shift ${widget.shift ?? '-'}'),
              _headerChip(
                Icons.access_time_rounded,
                '${widget.hourStart ?? '-'}–${widget.hourEnd ?? '-'}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerChip(IconData icon, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaStrip() {
    final outputJenis = widget.outputJenisList
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .join(', ');

    return Container(
      width: double.infinity,
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, size: 14, color: _accent),
          const SizedBox(width: 8),
          const Text(
            'OUTPUT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              outputJenis.isNotEmpty ? outputJenis : '-',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bucket row ──────────────────────────────────────────────────────────────

class _QcBucketRow extends StatefulWidget {
  const _QcBucketRow({
    required this.label,
    required this.hourStart,
    required this.status,
    required this.canEdit,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
    required this.onSubmitted,
    required this.onDeleted,
    required this.accent,
    this.submittedItem,
    this.windowOpensAt,
    this.windowClosesAt,
  });

  final String label;
  final String hourStart;
  final _QcBucketStatus status;
  final bool canEdit;
  final QcDowntimeItem? submittedItem;
  final DateTime? windowOpensAt;
  final DateTime? windowClosesAt;
  final Color accent;
  final Future<QcDowntimeItem> Function(String keterangan) onCreate;
  final Future<QcDowntimeItem> Function(int id, String keterangan) onUpdate;
  final Future<void> Function(int id) onDelete;
  final ValueChanged<QcDowntimeItem> onSubmitted;
  final VoidCallback onDeleted;

  @override
  State<_QcBucketRow> createState() => _QcBucketRowState();
}

class _QcBucketRowState extends State<_QcBucketRow> {
  final _keteranganCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _isDeleting = false;
  bool _isEditing = false;
  String? _error;

  @override
  void dispose() {
    _keteranganCtrl.dispose();
    super.dispose();
  }

  void _startEditing(QcDowntimeItem item) {
    _keteranganCtrl.text = item.keterangan ?? '';
    setState(() {
      _isEditing = true;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final keterangan = _keteranganCtrl.text.trim();
    if (keterangan.isEmpty) {
      setState(() => _error = 'Keterangan wajib diisi');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await widget.onCreate(keterangan);
      if (!mounted) return;
      widget.onSubmitted(result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitEdit(int id) async {
    final keterangan = _keteranganCtrl.text.trim();
    if (keterangan.isEmpty) {
      setState(() => _error = 'Keterangan wajib diisi');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final result = await widget.onUpdate(id, keterangan);
      if (!mounted) return;
      setState(() => _isEditing = false);
      widget.onSubmitted(result);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _delete(QcDowntimeItem item) async {
    if (_isDeleting) return;
    setState(() => _isDeleting = true);
    try {
      await widget.onDelete(item.id);
      if (!mounted) return;
      widget.onDeleted();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitted = widget.submittedItem;
    final status = widget.status;
    final isSubmitted = status == _QcBucketStatus.submitted &&
        (submitted?.id ?? 0) > 0;
    final isSubmittedValid = isSubmitted;
    final isExpired = status == _QcBucketStatus.expired;
    final isLocked = status == _QcBucketStatus.locked;

    final Color bgColor;
    final Color borderColor;
    final Color labelColor;
    if (isSubmittedValid) {
      bgColor = const Color(0xFFFFFBEB);
      borderColor = _downtimeColor.withValues(alpha: 0.30);
      labelColor = _downtimeColor;
    } else if (isExpired) {
      bgColor = const Color(0xFFFEF2F2);
      borderColor = const Color(0xFFFCA5A5);
      labelColor = const Color(0xFFDC2626);
    } else if (isLocked) {
      bgColor = const Color(0xFFF9FAFB);
      borderColor = const Color(0xFFE5E7EB);
      labelColor = const Color(0xFF9CA3AF);
    } else {
      bgColor = const Color(0xFFF8FAFF);
      borderColor = widget.accent.withValues(alpha: 0.20);
      labelColor = widget.accent;
    }

    Widget? statusBadge;
    if (isSubmittedValid) {
      statusBadge = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline, size: 11, color: _green),
          const SizedBox(width: 3),
          Text(
            'Tersimpan',
            style: TextStyle(
              fontSize: 9,
              color: _green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else if (isExpired) {
      statusBadge = _iconText(
        Icons.cancel_outlined,
        'Terlewat',
        labelColor,
      );
    } else if (isLocked) {
      statusBadge = _iconText(
        Icons.lock_outline,
        'Terkunci',
        labelColor,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (statusBadge != null) ...[statusBadge, const SizedBox(width: 6)],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: labelColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: labelColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: (isLocked || isExpired) && !isSubmittedValid
                ? _buildStatusInfo(isExpired)
                : _buildFields(isSubmittedValid && !_isEditing ? submitted : null),
          ),
          const SizedBox(width: 8),
          _buildActions(isSubmittedValid, submitted),
        ],
      ),
    );
  }

  Widget _iconText(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 9,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(bool isSubmittedValid, QcDowntimeItem? submitted) {
    if (isSubmittedValid && !_isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.canEdit)
            _iconAction(
              icon: Icons.edit_outlined,
              color: const Color(0xFFF59E0B),
              tooltip: 'Edit',
              onTap: _isDeleting
                  ? null
                  : () => _startEditing(submitted!),
            ),
          _iconAction(
            icon: Icons.delete_outline,
            color: const Color(0xFFDC2626),
            tooltip: 'Hapus',
            isLoading: _isDeleting,
            onTap: _isDeleting ? null : () => _delete(submitted!),
          ),
        ],
      );
    }
    if (isSubmittedValid && _isEditing) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionBtn(
            icon: Icons.close,
            label: 'Batal',
            color: const Color(0xFF6B7280),
            onTap: _isSubmitting
                ? null
                : () => setState(() {
                    _isEditing = false;
                    _error = null;
                  }),
          ),
          const SizedBox(width: 5),
          _actionBtn(
            icon: Icons.save_outlined,
            label: 'Simpan',
            color: _green,
            isLoading: _isSubmitting,
            onTap: _isSubmitting ? null : () => _submitEdit(submitted!.id),
          ),
        ],
      );
    }
    if (widget.status != _QcBucketStatus.locked &&
        widget.status != _QcBucketStatus.expired) {
      return _actionBtn(
        icon: Icons.save_outlined,
        label: 'Simpan',
        color: _downtimeColor,
        isLoading: _isSubmitting,
        onTap: _isSubmitting ? null : _submit,
      );
    }
    return const SizedBox(width: 40);
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(7),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                )
              : Tooltip(
                  message: tooltip,
                  child: Center(child: Icon(icon, size: 16, color: color)),
                ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: isLoading
              ? const Center(
                  child: SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : Tooltip(
                  message: label,
                  child: Center(child: Icon(icon, size: 20, color: Colors.white)),
                ),
        ),
      ),
    );
  }

  Widget _buildStatusInfo(bool isExpired) {
    if (isExpired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 13,
              color: Color(0xFFDC2626),
            ),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Jam ini sudah lewat dan tidak diinput',
                style: TextStyle(fontSize: 11, color: Color(0xFFDC2626)),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 13, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Belum waktunya input untuk jam ini',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
          if (widget.windowOpensAt != null) ...[
            const SizedBox(height: 6),
            _QcWindowCountdown(
              targetTime: widget.windowOpensAt!,
              label: 'Terbuka dalam',
              icon: Icons.hourglass_bottom_rounded,
              color: const Color(0xFF64748B),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFields(QcDowntimeItem? submitted) {
    final isReadOnly = submitted != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isReadOnly)
          _buildSubmittedNote(submitted)
        else
          _buildInputField(),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _error!,
            style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626)),
          ),
        ],
        if (widget.status == _QcBucketStatus.available &&
            widget.windowClosesAt != null) ...[
          const SizedBox(height: 4),
          _QcWindowCountdown(
            targetTime: widget.windowClosesAt!,
            label: 'Tertutup dalam',
            icon: Icons.timer_outlined,
            color: const Color(0xFFB45309),
          ),
        ],
      ],
    );
  }

  Widget _buildInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Keterangan downtime (wajib)',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 2),
        TextField(
          controller: _keteranganCtrl,
          maxLength: 500,
          maxLines: 2,
          minLines: 1,
          autofocus: true,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            hintText: 'Alasan downtime, mis. listrik padam...',
            hintStyle: const TextStyle(fontSize: 10, color: Color(0xFF9CA3AF)),
            isDense: true,
            counterStyle: const TextStyle(fontSize: 9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 7,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: _downtimeColor.withValues(alpha: 0.35),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: _downtimeColor.withValues(alpha: 0.35),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _downtimeColor, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmittedNote(QcDowntimeItem submitted) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _downtimeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _downtimeColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(
                Icons.playlist_remove_rounded,
                size: 13,
                color: _downtimeColor,
              ),
              SizedBox(width: 5),
              Text(
                'Downtime',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: _downtimeColor,
                ),
              ),
            ],
          ),
          if ((submitted.keterangan ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              submitted.keterangan!.trim(),
              style: const TextStyle(fontSize: 10, color: Color(0xFF374151)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Window countdown ────────────────────────────────────────────────────────

/// Hitung mundur generik menuju [targetTime] (buka/tutup window QC).
/// Rebuild tiap detik dibawa oleh `_statusTimer` di parent dialog — widget
/// ini hanya membaca `DateTime.now()` di tiap build agar HH:MM:SS responsif.
class _QcWindowCountdown extends StatelessWidget {
  const _QcWindowCountdown({
    required this.targetTime,
    required this.label,
    required this.icon,
    required this.color,
  });

  final DateTime targetTime;
  final String label;
  final IconData icon;
  final Color color;

  String _formatRemaining(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final hours = clamped.inHours;
    final minutes = clamped.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = clamped.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = targetTime.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            '$label ${_formatRemaining(remaining)}',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}