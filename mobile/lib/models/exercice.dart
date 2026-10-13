/// Lien d'exercice d'un praticien dans un établissement
/// (`directory.Exercice`). Champs confirmés dans
/// `backend/directory/serializers.py::ExerciceSerializer`.
///
/// Note : ce modèle n'apparaît dans l'API qu'imbriqué dans
/// `Praticien.exercices` — il n'y a pas d'endpoint `/exercices/`
/// autonome.
class Exercice {
  final String id;
  final String praticien;
  final String etablissement;
  final String etablissementNom;
  final String? service;
  final int? tarifIndicatifGnf;
  final bool actif;

  Exercice({
    required this.id,
    required this.praticien,
    required this.etablissement,
    required this.etablissementNom,
    this.service,
    this.tarifIndicatifGnf,
    required this.actif,
  });

  factory Exercice.fromJson(Map<String, dynamic> json) {
    return Exercice(
      id: json['id'] as String,
      praticien: json['praticien'] as String,
      etablissement: json['etablissement'] as String,
      etablissementNom: json['etablissement_nom'] as String? ?? '',
      service: json['service'] as String?,
      tarifIndicatifGnf: json['tarif_indicatif_gnf'] as int?,
      actif: json['actif'] as bool? ?? true,
    );
  }
}
