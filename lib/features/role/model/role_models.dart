class RoleGroup {
  const RoleGroup({
    required this.id,
    required this.name,
    required this.totalPermission,
    required this.totalAllow,
  });

  factory RoleGroup.fromJson(Map<String, dynamic> json) {
    int intOrZero(dynamic v) =>
        v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

    return RoleGroup(
      id: intOrZero(json['IdUGroup']),
      name: (json['UGroupName'] ?? '').toString().trim(),
      totalPermission: intOrZero(json['TotalPermission']),
      totalAllow: intOrZero(json['TotalAllow']),
    );
  }

  final int id;
  final String name;
  final int totalPermission;
  final int totalAllow;

  double get allowRatio => totalPermission <= 0
      ? 0
      : (totalAllow / totalPermission).clamp(0.0, 1.0);
}

class PermissionItem {
  const PermissionItem({required this.no, required this.description});

  factory PermissionItem.fromJson(Map<String, dynamic> json) =>
      PermissionItem(
        no: (json['NoPermission'] ?? '').toString().trim(),
        description: (json['Permission'] ?? '').toString().trim(),
      );

  final String no;
  final String description;

  String get module {
    final index = no.indexOf(':');
    return index > 0 ? no.substring(0, index) : no;
  }
}
