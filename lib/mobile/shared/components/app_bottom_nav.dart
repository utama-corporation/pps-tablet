import 'package:flutter/material.dart';

class AppBottomNavColors {
  static const Color primary = Color(0xFF1E3A8A);
  static const Color ink = Color(0xFF1E293B);
  static const Color slate = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
}

class _NavDestination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

const List<_NavDestination> _destinations = [
  _NavDestination(
    icon: Icons.space_dashboard_outlined,
    selectedIcon: Icons.space_dashboard_rounded,
    label: 'Beranda',
  ),
  _NavDestination(
    icon: Icons.history_outlined,
    selectedIcon: Icons.history_rounded,
    label: 'Aktivitas',
  ),
  _NavDestination(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: 'Profil',
  ),
];

/// Bottom navigation for the top-level tabs of the app shell.
/// Feature screens pushed on top of the shell (Stock Opname, Mapping V2,
/// Penjualan BJ, etc.) are not tabs themselves and do not show this bar.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppBottomNavColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: List.generate(_destinations.length, (index) {
              final d = _destinations[index];
              return Expanded(
                child: _NavItem(
                  icon: d.icon,
                  selectedIcon: d.selectedIcon,
                  label: d.label,
                  selected: index == currentIndex,
                  onTap: () => onTap(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppBottomNavColors.primary : AppBottomNavColors.slate;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 23),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
