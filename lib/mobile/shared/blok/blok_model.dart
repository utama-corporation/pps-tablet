class Blok {
  final String blok;
  final int idWarehouse;

  Blok({required this.blok, required this.idWarehouse});

  factory Blok.fromJson(Map<String, dynamic> json) {
    return Blok(
      blok: json['Blok'] ?? '',
      idWarehouse: json['IdWarehouse'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "Blok": blok,
      "IdWarehouse": idWarehouse,
    };
  }
}
