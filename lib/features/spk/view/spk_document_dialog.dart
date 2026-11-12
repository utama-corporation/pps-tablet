import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common/widgets/atlas_data_table.dart';
import '../../../core/network/api_error.dart';
import '../../../core/view_model/permission_view_model.dart';
import '../model/spk_models.dart';
import '../repository/spk_repository.dart';
import '../widgets/spk_widgets.dart';

/// Detail of one SPK document (`GET /api/spk-barang-jadi/:noSPK`).
///
/// Pass [initial] (e.g. the document returned right after "Buat SPK") to skip
/// the first request.
class SpkDocumentDialog extends StatefulWidget {
  const SpkDocumentDialog({
    super.key,
    required this.code,
    required this.repository,
    this.initial,
  });

  final String code;
  final SpkRepository repository;
  final SpkDocument? initial;

  @override
  State<SpkDocumentDialog> createState() => _SpkDocumentDialogState();
}

class _SpkDocumentDialogState extends State<SpkDocumentDialog> {
  static const _ink = Color(0xFF172B4D);
  static const _muted = Color(0xFF6B778C);
  static const _border = Color(0xFFE5E7EB);

  late Future<SpkDocument> future;

  @override
  void initState() {
    super.initState();
    future = widget.initial != null ? Future.value(widget.initial!) : fetch();
  }

  Future<SpkDocument> fetch() async {
    if (!context.read<PermissionViewModel>().can(spkReadPermission)) {
      throw Exception('Tidak punya akses.');
    }
    return widget.repository.detail(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    final allowed = context.watch<PermissionViewModel>().can(spkReadPermission);
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: math.min(1240, size.width - 48),
        height: math.min(720, size.height - 48),
        child: FutureBuilder<SpkDocument>(
          future: allowed ? future : null,
          builder: (context, snapshot) {
            final d = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SpkDialogHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'Detail SPK ${widget.code}',
                  subtitle: 'Dokumen SPK Produksi Barang Jadi',
                  trailing: d == null ? null : SpkStatusLozenge(d.status),
                ),
                const Divider(height: 1),
                Expanded(child: _buildBody(allowed, snapshot)),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Tutup'),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(bool allowed, AsyncSnapshot<SpkDocument> snapshot) {
    if (!allowed) {
      return const Center(child: Text('Anda tidak memiliki akses ke SPK.'));
    }
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError) {
      return SpkFailure(
        apiErrorMessage(snapshot.error!),
        retry: () => setState(() => future = fetch()),
      );
    }
    final d = snapshot.data!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummary(d),
          if (d.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            SpkNotice(
              icon: Icons.notes_rounded,
              color: const Color(0xFF44546F),
              background: const Color(0xFFF7F8F9),
              message: 'Keterangan: ${d.notes}',
            ),
          ],
          const SizedBox(height: 14),
          SpkSectionTitle(
            icon: Icons.list_alt_rounded,
            title: 'Detail barang (${d.items.length})',
          ),
          const SizedBox(height: 8),
          Expanded(
            child: d.items.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada barang pada SPK ini.',
                      style: TextStyle(fontSize: 13, color: _muted),
                    ),
                  )
                : _buildLinesTable(d.items),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(SpkDocument d) {
    final total = d.totalQty;
    final progress = total > 0
        ? (d.totalCompleted / total).clamp(0.0, 1.0)
        : 0.0;
    final tiles = <Widget>[
      SpkMetaItem(label: 'Tanggal', value: spkDate(d.date), large: true),
      SpkMetaItem(
        label: 'Status',
        value: d.status,
        trailing: SpkStatusLozenge(d.status),
      ),
      SpkMetaItem(
        label: 'Jumlah barang',
        value: '${d.items.length}',
        large: true,
      ),
      SpkMetaItem(label: 'Total qty SPK', value: spkQty(total), large: true),
      SpkMetaItem(
        label: 'Total selesai',
        value:
            '${spkQty(d.totalCompleted)} (${(progress * 100).toStringAsFixed(0)}%)',
        large: true,
        valueColor: _progressColor(progress),
      ),
      if (d.createdDate.isNotEmpty)
        SpkMetaItem(label: 'Dibuat', value: spkDateTime(d.createdDate)),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Wrap(
        spacing: 36,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: tiles,
      ),
    );
  }

  static Color _progressColor(double progress) => progress >= 1.0
      ? const Color(0xFF15803D)
      : progress > 0
      ? const Color(0xFFB45309)
      : const Color(0xFF44546F);

  static const _minTableWidth = 1180.0;

  Widget _buildLinesTable(List<SpkLine> lines) {
    final indexed = [for (final (i, line) in lines.indexed) (i + 1, line)];
    final table = AtlasDataTable<(int, SpkLine)>(
      items: indexed,
      columns: _columns(),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= _minTableWidth) return table;
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: _minTableWidth,
              height: constraints.maxHeight,
              child: table,
            ),
          ),
        );
      },
    );
  }

  Widget _num(String text, {Color? color, bool strong = false}) => Text(
    text,
    textAlign: TextAlign.right,
    style: TextStyle(
      fontSize: 14,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      color: color ?? _ink,
    ),
  );

  List<AtlasTableColumn<(int, SpkLine)>> _columns() => [
    AtlasTableColumn(
      title: '#',
      width: 44,
      cellBuilder: (_, r, s) =>
          Text('${r.$1}', style: const TextStyle(color: _muted)),
    ),
    AtlasTableColumn(
      title: 'ITEM CODE',
      width: 128,
      cellBuilder: (_, r, s) => Text(
        r.$2.code.isEmpty ? '—' : r.$2.code,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _ink,
        ),
      ),
    ),
    AtlasTableColumn(
      title: 'BARANG',
      cellBuilder: (_, r, s) {
        final l = r.$2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.name.isEmpty ? '—' : l.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Min ${spkQty(l.min)} · Max ${spkQty(l.max)} · MPQ ${spkQty(l.mpq)}',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
            if (l.notes.isNotEmpty)
              Text(
                l.notes,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: _muted,
                ),
              ),
          ],
        );
      },
    ),
    AtlasTableColumn(
      title: 'UOM',
      width: 64,
      cellBuilder: (_, r, s) => spkCell(r.$2.uom),
    ),
    AtlasTableColumn(
      title: 'STOK SAAT SPK',
      width: 128,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, r, s) => _num(
        spkQty(r.$2.stock),
        color: r.$2.stock <= 0 ? const Color(0xFFB91C1C) : null,
      ),
    ),
    AtlasTableColumn(
      title: 'REKOMENDASI',
      width: 112,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, r, s) =>
          _num(spkQty(r.$2.recommendation), color: const Color(0xFF1D4ED8)),
    ),
    AtlasTableColumn(
      title: 'QTY SPK',
      width: 96,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, r, s) => _num(spkQty(r.$2.qty), strong: true),
    ),
    AtlasTableColumn(
      title: 'QTY PRODUKSI',
      width: 110,
      headerAlign: TextAlign.right,
      cellAlignment: Alignment.centerRight,
      cellBuilder: (_, r, s) => _num(spkQty(r.$2.produced)),
    ),
    AtlasTableColumn(
      title: 'SELESAI',
      width: 140,
      cellBuilder: (_, r, s) {
        final l = r.$2;
        final p = l.qty > 0 ? (l.completed / l.qty).clamp(0.0, 1.0) : 0.0;
        final color = _progressColor(p);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${spkQty(l.completed)} (${(p * 100).toStringAsFixed(0)}%)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: p,
                minHeight: 5,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        );
      },
    ),
    AtlasTableColumn(
      title: 'STATUS',
      width: 110,
      showDivider: false,
      cellBuilder: (_, r, s) => SpkStatusLozenge(r.$2.status),
    ),
  ];
}
