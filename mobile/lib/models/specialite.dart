/// Spécialité médicale (`directory.Specialite`).
/// Champs confirmés dans
/// `backend/directory/serializers.py::SpecialiteSerializer`.
class Specialite {
  final String id;
  final String code;
  final String libelle;
  final String libelleGrandPublic;
  final String icone;

  Specialite({
    required this.id,
    required this.code,
    required this.libelle,
    required this.libelleGrandPublic,
    required this.icone,
  });

  /// Libellé le plus adapté à un affichage grand public (patient),
  /// avec repli sur le libellé médical s'il est vide.
  String get libelleAffiche =>
      libelleGrandPublic.isNotEmpty ? libelleGrandPublic : libelle;

  factory Specialite.fromJson(Map<String, dynamic> json) {
    return Specialite(
      id: json['id'] as String,
      code: json['code'] as String,
      libelle: json['libelle'] as String,
      libelleGrandPublic: json['libelle_grand_public'] as String? ?? '',
      icone: json['icone'] as String? ?? '',
    );
  }
}
