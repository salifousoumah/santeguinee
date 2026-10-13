/// Créneau concret de rendez-vous (`scheduling.Creneau`). Champs
/// confirmés dans `backend/scheduling/serializers.py::CreneauSerializer`.
class Creneau {
  static const String libre = 'libre';
  static const String verrouille = 'verrouille';
  static const String reserve = 'reserve';
  static const String bloque = 'bloque';

  final String id;
  final String exercice;
  final DateTime debut;
  final DateTime fin;
  final String statut;
  final DateTime? verrouExpireLe;
  final bool enLigne;

  Creneau({
    required this.id,
    required this.exercice,
    required this.debut,
    required this.fin,
    required this.statut,
    this.verrouExpireLe,
    required this.enLigne,
  });

  factory Creneau.fromJson(Map<String, dynamic> json) {
    return Creneau(
      id: json['id'] as String,
      exercice: json['exercice'] as String,
      debut: DateTime.parse(json['debut'] as String),
      fin: DateTime.parse(json['fin'] as String),
      statut: json['statut'] as String,
      verrouExpireLe: json['verrou_expire_le'] == null
          ? null
          : DateTime.parse(json['verrou_expire_le'] as String),
      enLigne: json['en_ligne'] as bool? ?? true,
    );
  }
}
