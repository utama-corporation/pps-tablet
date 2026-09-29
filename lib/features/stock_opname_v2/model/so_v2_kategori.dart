import 'package:flutter/material.dart';

enum SoV2Status {
  notStarted,
  inProgress,
  completed;

  static SoV2Status fromApi(String value) {
    switch (value) {
      case 'in_progress':
        return SoV2Status.inProgress;
      case 'completed':
        return SoV2Status.completed;
      case 'not_started':
      default:
        return SoV2Status.notStarted;
    }
  }

  String get label {
    switch (this) {
      case SoV2Status.notStarted:
        return 'Belum Mulai';
      case SoV2Status.inProgress:
        return 'Sedang Berjalan';
      case SoV2Status.completed:
        return 'Selesai';
    }
  }

  /// Nilai yang dikirim balik ke server sebagai query filter `status`
  /// (kebalikan dari [fromApi]).
  static String toApiValue(SoV2Status status) {
    switch (status) {
      case SoV2Status.notStarted:
        return 'not_started';
      case SoV2Status.inProgress:
        return 'in_progress';
      case SoV2Status.completed:
        return 'completed';
    }
  }

  Color get color {
    switch (this) {
      case SoV2Status.notStarted:
        return const Color(0xFF6B7280);
      case SoV2Status.inProgress:
        return const Color(0xFF1E6FD9);
      case SoV2Status.completed:
        return const Color(0xFF0A7349);
    }
  }
}

/// User yang sedang aktif scan di satu lokasi kerja.
class SoV2WorkingLocationUser {
  final int idUsername;
  final String username;
  final String fullName;

  SoV2WorkingLocationUser({
    required this.idUsername,
    required this.username,
    required this.fullName,
  });

  String get displayName => fullName.isNotEmpty ? fullName : username;

  factory SoV2WorkingLocationUser.fromJson(Map<String, dynamic> json) {
    return SoV2WorkingLocationUser(
      idUsername: (json['idUsername'] as num?)?.toInt() ?? 0,
      username: json['username']?.toString() ?? '',
      fullName: json['fullName']?.toString() ?? '',
    );
  }
}

/// Lokasi yang sedang ditugaskan/dikerjakan dalam satu kategori.
class SoV2KategoriWorkingLocation {
  final String lokasi;
  final String description;
  final List<SoV2WorkingLocationUser> users;

  SoV2KategoriWorkingLocation({
    required this.lokasi,
    required this.description,
    required this.users,
  });

  factory SoV2KategoriWorkingLocation.fromJson(Map<String, dynamic> json) {
    return SoV2KategoriWorkingLocation(
      lokasi: json['lokasi']?.toString() ?? '',
      description: json['description']?.toString().trim() ?? '',
      users: (json['users'] as List? ?? [])
          .map(
            (e) => SoV2WorkingLocationUser.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class SoV2Kategori {
  final int categoryId;
  final String categoryCode;
  final String categoryName;
  final String? stockOpnameNo;
  final SoV2Status status;
  final int labelCount;
  final int scannedCount;
  final DateTime? startDate;
  final DateTime? completedAt;
  final int workingLocationCount;
  final List<SoV2KategoriWorkingLocation> workingLocations;

  SoV2Kategori({
    required this.categoryId,
    required this.categoryCode,
    required this.categoryName,
    required this.stockOpnameNo,
    required this.status,
    required this.labelCount,
    required this.scannedCount,
    this.startDate,
    this.completedAt,
    this.workingLocationCount = 0,
    this.workingLocations = const [],
  });

  double get progress => labelCount > 0 ? scannedCount / labelCount : 0;

  SoV2Kategori copyWith({int? scannedCount}) {
    return SoV2Kategori(
      categoryId: categoryId,
      categoryCode: categoryCode,
      categoryName: categoryName,
      stockOpnameNo: stockOpnameNo,
      status: status,
      labelCount: labelCount,
      scannedCount: scannedCount ?? this.scannedCount,
      startDate: startDate,
      completedAt: completedAt,
      workingLocationCount: workingLocationCount,
      workingLocations: workingLocations,
    );
  }

  factory SoV2Kategori.fromJson(Map<String, dynamic> json) {
    return SoV2Kategori(
      categoryId: json['categoryId'] as int,
      categoryCode: json['categoryCode']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? '',
      stockOpnameNo: json['stockOpnameNo']?.toString(),
      status: SoV2Status.fromApi(json['status']?.toString() ?? 'not_started'),
      labelCount: (json['labelCount'] as num?)?.toInt() ?? 0,
      scannedCount: (json['scannedCount'] as num?)?.toInt() ?? 0,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completedAt']?.toString() ?? ''),
      workingLocationCount:
          (json['workingLocationCount'] as num?)?.toInt() ?? 0,
      workingLocations: (json['workingLocations'] as List? ?? [])
          .map(
            (e) => SoV2KategoriWorkingLocation.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}
