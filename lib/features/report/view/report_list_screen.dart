// lib/features/report/view/report_list_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../favorit/widgets/favorite_button.dart';
import '../model/report_item.dart';
import '../view_model/report_list_view_model.dart';
import 'report_open_helper.dart';

const _sectionColors = <Color>[
  Color(0xFF0C66E4),
  Color(0xFF15803D),
  Color(0xFFB45309),
  Color(0xFF7C3AED),
];

class ReportListScreen extends StatelessWidget {
  const ReportListScreen({super.key, this.categoryKey});

  /// Slug kategori (mis. 'washing') — dari route `/laporan/<slug>`.
  /// null atau 'semua' â†’ tampilkan semua kategori.
  final String? categoryKey;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportListViewModel(apiClient: context.read<ApiClient>()),
      child: _ReportListView(categoryKey: categoryKey),
    );
  }
}

class _ReportListView extends StatefulWidget {
  const _ReportListView({this.categoryKey});

  final String? categoryKey;

  @override
  State<_ReportListView> createState() => _ReportListViewState();
}

class _ReportListViewState extends State<_ReportListView> {
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _searchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportListViewModel>();
    final kategori = vm.filteredKategori(widget.categoryKey);

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          _buildSearchBar(vm),
          Expanded(
            child: kategori.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada laporan',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    key: const ValueKey('laporan-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      for (final (index, section) in kategori.indexed) ...[
                        if (index > 0) const SizedBox(height: 16),
                        _SectionGrid(
                          kategori: section,
                          color: _sectionColors[index % _sectionColors.length],
                          onTap: _openItem,
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ReportListViewModel vm) {
    final sections = reportSectionsFor(widget.categoryKey);
    final single = sections.length == 1 ? sections.single : null;
    final title = single?.nama ?? 'Semua Laporan';
    final icon = single?.icon ?? Icons.apps_rounded;
    final accent = single == null
        ? const Color(0xFF0C66E4)
        : _sectionColors[reportKategoriCatalog.indexOf(single) %
            _sectionColors.length];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172B4D),
              ),
            ),
          ),
          Text(
            '${vm.filteredCount(widget.categoryKey)} laporan',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B778C),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 240,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _searchFocused
                      ? const Color(0xFF1565C0).withValues(alpha: .5)
                      : Colors.grey.shade300,
                  width: _searchFocused ? 1.6 : 1,
                ),
                boxShadow: _searchFocused
                    ? [
                        BoxShadow(
                          color: const Color(0xFF1565C0).withValues(alpha: .12),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  Icon(Icons.search, color: Colors.grey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('laporan-search'),
                      focusNode: _searchFocus,
                      controller: _search,
                      onChanged: (v) {
                        setState(() {});
                        vm.search = v;
                      },
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Cari laporan…',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        isCollapsed: true,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (_search.text.trim().isNotEmpty)
                    IconButton(
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                        vm.search = '';
                        _searchFocus.requestFocus();
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openItem(ReportItem item) {
    unawaited(openReportItem(context, item));
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({
    required this.kategori,
    required this.color,
    required this.onTap,
  });

  final ReportKategori kategori;
  final Color color;
  final ValueChanged<ReportItem> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 700
                ? 2
                : 1;
        return GridView.count(
          crossAxisCount: columns,
          mainAxisExtent: 76,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final item in kategori.items)
              _ReportCard(
                key: ValueKey('laporan-item-${item.path ?? item.route ?? item.title}'),
                item: item,
                color: color,
                onTap: () => onTap(item),
              ),
          ],
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    super.key,
    required this.item,
    required this.color,
    required this.onTap,
  });

  final ReportItem item;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
         child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
           decoration: BoxDecoration(
             borderRadius: BorderRadius.circular(12),
             border: Border.all(
               color: item.comingSoon
                   ? const Color(0xFFFFE0B2)
                   : const Color(0xFFE5E7EB),
             ),
             color: item.comingSoon ? const Color(0xFFFFF9F0) : null,
           ),
           child: Row(
             children: [
               Container(
                 width: 44,
                 height: 44,
                 decoration: BoxDecoration(
                   color: item.comingSoon
                       ? Colors.amber.withValues(alpha: 0.14)
                       : color.withValues(alpha: 0.12),
                   borderRadius: BorderRadius.circular(10),
                 ),
                 child: Icon(
                   item.icon,
                   color: item.comingSoon ? const Color(0xFFB45309) : color,
                   size: 22,
                 ),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Text(
                   item.title,
                   maxLines: 2,
                   overflow: TextOverflow.ellipsis,
                   style: TextStyle(
                     fontSize: 13,
                     fontWeight: FontWeight.w600,
                     color: item.comingSoon
                         ? const Color(0xFFB45309)
                         : const Color(0xFF172B4D),
                   ),
                 ),
               ),
               FavoriteButton(
                 tipe: 'laporan',
                 kode: item.path ?? item.route ?? item.title,
                 iconSize: 18,
               ),
               if (item.comingSoon)
                 Container(
                   padding: const EdgeInsets.symmetric(
                     horizontal: 8,
                     vertical: 3,
                   ),
                   decoration: BoxDecoration(
                     color: Colors.amber.withValues(alpha: 0.18),
                     borderRadius: BorderRadius.circular(20),
                   ),
                   child: const Text(
                     'Segera',
                     style: TextStyle(
                       fontSize: 10.5,
                       fontWeight: FontWeight.w700,
                       color: Color(0xFFB26A00),
                     ),
                   ),
                 )
               else
                 const Icon(
                   Icons.chevron_right_rounded,
                   size: 18,
                   color: Color(0xFFC1C7D0),
                 ),
             ],
           ),
         ),
      ),
    );
  }
}
