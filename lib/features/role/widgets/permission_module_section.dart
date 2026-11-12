import 'package:flutter/material.dart';

import '../model/role_models.dart';

const _teal = Color(0xFF00897B);
const _border = Color(0xFFE5E7EB);

class PermissionModuleSection extends StatelessWidget {
  const PermissionModuleSection({
    super.key,
    required this.module,
    required this.items,
    required this.allow,
    required this.onToggle,
    required this.onToggleAll,
  });

  final String module;
  final List<PermissionItem> items;
  final Map<String, bool> allow;
  final void Function(String no, bool value) onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final selected = items.where((item) => allow[item.no] == true).length;
    final all = items.isNotEmpty && selected == items.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    module,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF172B4D),
                    ),
                  ),
                ),
                Text(
                  '$selected/${items.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF44546F),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => onToggleAll(!all),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 26),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: const StadiumBorder(),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    all ? 'Kosongkan' : 'Pilih semua',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            child: Wrap(
              children: [
                for (final item in items)
                  SizedBox(
                    width: 340,
                    child: InkWell(
                      onTap: () => onToggle(item.no, allow[item.no] != true),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        children: [
                          Checkbox(
                            visualDensity: VisualDensity.compact,
                            activeColor: _teal,
                            value: allow[item.no] == true,
                            onChanged: (value) =>
                                onToggle(item.no, value ?? false),
                          ),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: item.no,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11.5,
                                      color: Color(0xFF172B4D),
                                    ),
                                  ),
                                  if (item.description.isNotEmpty)
                                    TextSpan(
                                      text: '  ${item.description}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF44546F),
                                      ),
                                    ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
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
}
