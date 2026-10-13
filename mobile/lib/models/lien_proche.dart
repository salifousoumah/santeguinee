/// Lien de gestion d'un patient "proche" par un titulaire
/// (`accounts.LienProche`, RG-24 : max 10 proches par titulaire).
/// Champs confirmés dans
/// `backend/accounts/serializers.py::LienProcheSerializer`.
class LienProche {
  static const String enfant = 'enfant';
  static const String parent = 'parent';
  static const String conjoint = 'conjoint';
  static const String autre = 'autre';

  final String id;
  final String titulaire; // UUID du Patient titulaire
  final String patient; // UUID du Patient "proche"
  final String lien;
  final String droits;

  LienProche({
    required this.id,
    required this.titulaire,
    required this.patient,
    required this.lien,
    required this.droits,
  });

  factory LienProche.fromJson(Map<String, dynamic> json) {
    return LienProche(
      id: json['id'] as String,
      titulaire: json['titulaire'] as String,
      patient: json['patient'] as String,
      lien: json['lien'] as String,
      droits: json['droits'] as String? ?? 'gestion_complete',
    );
  }

  static Map<String, dynamic> creationBody({
    required String titulaire,
    required String patient,
    required String lien,
    String droits = 'gestion_complete',
  }) {
    return {
      'titulaire': titulaire,
      'patient': patient,
      'lien': lien,
      'droits': droits,
    };
  }

  /// Libellé français pour une valeur de `lien`.
  static String libelleLien(String lien) {
    switch (lien) {
      case enfant:
        return 'Enfant';
      case parent:
        return 'Parent';
      case conjoint:
        return 'Conjoint(e)';
      case autre:
      default:
        return 'Autre';
    }
  }
}
