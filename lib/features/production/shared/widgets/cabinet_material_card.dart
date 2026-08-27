import 'package:flutter/material.dart';
import '../models/cabinet_material_item.dart';

class CabinetMaterialCard extends StatelessWidget {
  final String title;

  /// gabungan list (temp + db) sudah disiapkan dari screen
  final List<CabinetMaterialItem> items;

  /// untuk menandai item mana yang TEMP (screen yg tentukan)
  final Set<int> tempIds;

  final bool locked;
  final bool canDelete;

  /// dipanggil saat klik tambah
  final VoidCallback? onAdd;

  /// dipanggil saat delete item TEMP (langsung)
  final void Function(CabinetMaterialItem item)? onDeleteTemp;

  /// dipanggil saat delete item existing DB (biasanya konfirmasi + call API)
  final void Function(CabinetMaterialItem item)? onDeleteExisting;

  const CabinetMaterialCard({
    super.key,
    this.title = 'Cabinet Material',
    required this.items,
    required this.tempIds,
    this.locked = false,
    this.canDelete = false,
    this.onAdd,
    this.onDeleteTemp,
    this.onDeleteExisting,
  });

  @override
  Widget build(BuildContext context) {
    // total = Jumlah
    final totalJumlah = items.fold<num>(0, (sum, it) => sum + (it.Jumlah ?? 0));
    final unit = _bestUnit(items);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== HEADER =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.shade400,
                  Colors.deepPurple.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== BODY =====
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada material',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) {
                  final item = items[index];
                  final id = item.IdCabinetMaterial ?? 0;
                  final isTemp = id > 0 && tempIds.contains(id);

                  return _MaterialItemCard(
                    item: item,
                    isTemp: isTemp,
                    locked: locked,
                    canDelete: canDelete,
                    onDelete: () {
                      if (isTemp) {
                        onDeleteTemp?.call(item);
                      } else {
                        onDeleteExisting?.call(item);
                      }
                    },
                  );
                },
              ),
            ),

          // ===== FOOTER =====
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_fmtNum(totalJumlah)} ${unit ?? ""}'.trim(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: locked ? null : onAdd,
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Tambah Material'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.deepPurple.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtNum(num v) {
    if (v % 1 == 0) return v.toInt().toString();
    return v.toString();
  }

  static String? _bestUnit(List<CabinetMaterialItem> items) {
    for (final it in items) {
      final u = (it.NamaUOM ?? '').trim();
      if (u.isNotEmpty) return u;
    }
    return null;
  }
}

class _MaterialItemCard extends StatelessWidget {
  final CabinetMaterialItem item;
  final bool isTemp;
  final bool locked;
  final bool canDelete;
  final VoidCallback onDelete;

  const _MaterialItemCard({
    required this.item,
    required this.isTemp,
    required this.locked,
    required this.canDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final showDelete = isTemp || (!locked && canDelete);

    final name = item.Nama ?? '-';
    final qty = item.Jumlah ?? 0;
    final unit = item.NamaUOM ?? 'unit';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTemp ? Colors.amber.shade50 : Colors.white,
        border: Border.all(
          color: isTemp ? Colors.amber.shade200 : Colors.grey.shade200,
          width: isTemp ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isTemp
                  ? Colors.amber.withOpacity(0.2)
                  : Colors.deepPurple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.category_outlined,
              size: 20,
              color: isTemp
                  ? Colors.amber.shade700
                  : Colors.deepPurple.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '$qty $unit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple.shade700,
                        ),
                      ),
                    ),
                    if (isTemp) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber.shade400),
                        ),
                        child: Text(
                          'TEMP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.amber.shade800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (showDelete)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Colors.red.shade600,
              tooltip: isTemp ? 'Hapus TEMP' : 'Hapus Material',
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
