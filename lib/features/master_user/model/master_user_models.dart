class MasterUser {
  const MasterUser({
    required this.id,
    required this.username,
    required this.fName,
    required this.lName,
    required this.nik,
    required this.employeeId,
    required this.companyId,
    required this.status,
    required this.isEnable,
    required this.groupNames,
  });

  factory MasterUser.fromJson(Map<String, dynamic> json) {
    int? intOrNull(dynamic v) {
      final n = v is num ? v.toInt() : int.tryParse('${v ?? ''}');
      return (n != null && n > 0) ? n : null;
    }

    String text(String key) => json[key]?.toString().trim() ?? '';

    final isEnableRaw = json['IsEnable'];
    final isEnable = isEnableRaw == true ||
        isEnableRaw == 1 ||
        '$isEnableRaw'.toLowerCase() == 'true';

    return MasterUser(
      id: intOrNull(json['IdUsername']) ?? 0,
      username: text('Username'),
      fName: text('FName'),
      lName: text('LName'),
      nik: text('Nik'),
      employeeId: intOrNull(json['EmployeeID']),
      companyId: text('CompanyID'),
      status: text('Status'),
      isEnable: isEnable,
      groupNames: text('GroupName')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
    );
  }

  final int id;
  final String username;
  final String fName;
  final String lName;
  final String nik;
  final int? employeeId;
  final String companyId;
  final String status;
  final bool isEnable;
  final List<String> groupNames;

  String get fullName => '$fName $lName'.trim();
  bool get active => isEnable;

  MasterUser copyWith({List<String>? groupNames}) => MasterUser(
    id: id,
    username: username,
    fName: fName,
    lName: lName,
    nik: nik,
    employeeId: employeeId,
    companyId: companyId,
    status: status,
    isEnable: isEnable,
    groupNames: groupNames ?? this.groupNames,
  );
}

class UserGroup {
  const UserGroup({required this.id, required this.name});

  factory UserGroup.fromJson(Map<String, dynamic> json) {
    final id = json['IdUGroup'] is num
        ? (json['IdUGroup'] as num).toInt()
        : int.tryParse('${json['IdUGroup'] ?? 0}') ?? 0;
    return UserGroup(id: id, name: (json['UGroupName'] ?? '').toString());
  }

  final int id;
  final String name;
}

class EmployeeMatch {
  const EmployeeMatch({
    required this.fullName,
    required this.code,
    required this.companyId,
    required this.employeeId,
  });

  factory EmployeeMatch.fromJson(Map<String, dynamic> json) => EmployeeMatch(
    fullName: (json['FullName'] ?? '').toString().trim(),
    code: (json['EmployeeCode'] ?? '').toString().trim(),
    companyId: (json['CompanyID'] ?? '').toString().trim(),
    employeeId: json['EmployeeID'] is num
        ? (json['EmployeeID'] as num).toInt()
        : int.tryParse('${json['EmployeeID'] ?? 0}') ?? 0,
  );

  final String fullName;
  final String code;
  final String companyId;
  final int employeeId;
}

const userCompanies = <(String, String)>[
  ('as_gsu', 'AS_GSU (PT. GSU)'),
  ('as_ru', 'AS_RU (PT. RU)'),
  ('as_uc_2017', 'AS_UC_2017 (PT. UC)'),
];
