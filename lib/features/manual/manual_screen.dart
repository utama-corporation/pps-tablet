import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/pps_menu_catalog.dart';
import '../../core/view/app_shell.dart';
import '../../core/view_model/permission_view_model.dart';
import '../../features/production/shared/widgets/production_panel_decoration.dart';
import 'manual_content.dart';

/// Manual PPS: panduan langkah demi langkah per area, dengan pencarian ke
/// seluruh isi dan tombol untuk membuka modul yang dibahas.
class ManualScreen extends StatefulWidget {
  final List<ManualArea> areas;

  /// Route katalog yang dibuka tombol "Buka ..."; default = ganti layar di shell.
  final ValueChanged<String>? onOpenRoute;

  /// Cek izin route; default = katalog menu + izin user.
  final bool Function(String route)? canOpenRoute;

  const ManualScreen({
    super.key,
    this.areas = ppsManualAreas,
    this.onOpenRoute,
    this.canOpenRoute,
  });

  @override
  State<ManualScreen> createState() => _ManualScreenState();
}

class _ManualScreenState extends State<ManualScreen> {
  final _search = TextEditingController();
  late String _area = widget.areas.first.key;
  final _open = <String>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    // Bagian pertama tiap area terbuka agar halaman langsung berisi.
    for (final a in widget.areas) {
      if (a.sections.isNotEmpty) _open.add(a.sections.first.id);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static void _openInShell(String route) {
    final title = PpsMenuCatalog.forRoute(route)?.title ?? route;
    AppShell.breadcrumb.value = [BreadcrumbSegment(title)];
    AppShell.currentRoute.value = route;
    AppShell.shellNavigatorKey.currentState?.pushNamedAndRemoveUntil(
      route,
      (_) => false,
    );
  }

  bool _canOpen(String route) {
    final check = widget.canOpenRoute;
    if (check != null) return check(route);
    try {
      final perms = context.read<PermissionViewModel>();
      return PpsMenuCatalog.canOpenRoute(route, perms.can);
    } on ProviderNotFoundException {
      return false;
    }
  }

  void _toggle(String id) => setState(() {
    if (!_open.remove(id)) _open.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final query = _query.trim().toLowerCase();
    final area = widget.areas.firstWhere((a) => a.key == _area);
    // Saat mencari, hasil diambil dari semua area dan ditampilkan terbuka.
    final results = query.isEmpty
        ? null
        : [
            for (final a in widget.areas)
              for (final s in a.sections)
                if (s.searchText.contains(query)) (a, s),
          ];
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(compact ? 16 : 24),
          children: [
            const Text(
              'Manual PPS',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: kProductionPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Panduan langkah demi langkah memakai PPS Tablet, dari label dan produksi sampai gudang, laporan, dan KPI.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('manual-search'),
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Cari langkah, mis. cetak label',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: kProductionBorder),
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (results == null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in widget.areas)
                    ChoiceChip(
                      key: Key('manual-area-${a.key}'),
                      label: Text(a.label),
                      selected: a.key == _area,
                      onSelected: (_) => setState(() => _area = a.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                area.tagline,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kProductionPrimary,
                ),
              ),
              const SizedBox(height: 12),
              for (final s in area.sections) ...[
                _sectionCard(s, open: _open.contains(s.id)),
                const SizedBox(height: 12),
              ],
            ] else if (results.isEmpty)
              Padding(
                padding: const EdgeInsets.all(28),
                child: Text(
                  'Tidak ada panduan untuk "${_query.trim()}".',
                  key: const Key('manual-empty'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              )
            else ...[
              Text(
                '${results.length} panduan ditemukan',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              for (final (a, s) in results) ...[
                _sectionCard(s, open: true, areaLabel: a.label),
                const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(
    ManualSection s, {
    required bool open,
    String? areaLabel,
  }) {
    final route = s.openRoute;
    final canOpen = route != null && _canOpen(route);
    return Container(
      key: Key('manual-section-${s.id}'),
      decoration: productionPanelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: Key('manual-toggle-${s.id}'),
            onTap: areaLabel == null ? () => _toggle(s.id) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(s.icon, size: 20, color: kProductionPrimary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (areaLabel != null)
                          Text(
                            areaLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kProductionPrimary,
                            ),
                          ),
                        Text(
                          s.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1D23),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.description,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (areaLabel == null)
                    const Icon(
                      Icons.expand_more_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < s.steps.length; i++) ...[
                    _step(i + 1, s.steps[i]),
                    const SizedBox(height: 12),
                  ],
                  for (final note in s.notes) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                            color: Color(0xFFB45309),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  const TextSpan(
                                    text: 'Perhatian: ',
                                    style: TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                  TextSpan(text: note),
                                ],
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: Color(0xFF7C2D12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (canOpen)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        key: Key('manual-open-${s.id}'),
                        onPressed: () => (widget.onOpenRoute ?? _openInShell)(
                          route,
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: Text(s.openLabel ?? 'Buka modul'),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _step(int no, ManualStep step) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: kProductionPrimary,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$no',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              step.text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF475569),
              ),
            ),
            if (step.path != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  step.path!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kProductionPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
