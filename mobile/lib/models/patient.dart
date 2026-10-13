/// Profil patient minimal (`accounts.Patient`) : identité + contact,
/// hors dossier médical (hors périmètre de cette passe). Champs
/// confirmés dans `backend/accounts/serializers.py::PatientSerializer`.
///
/// Note : `quartier` est une simple clé étrangère vers `directory.Zone`
/// (un UUID), PAS un objet imbriqué — contrairement à
/// `Etablissement.quartier` qui, lui, est imbriqué. Le serializer
/// patient ne redéfinit pas ce champ, DRF expose donc par défaut un
/// `PrimaryKeyRelatedField`.
class Patient {
  static const String sexeHomme = 'M';
  static const String sexeFemme = 'F';

  final String id;
  final String numeroSante;
  final String nom;
  final String prenoms;
  final String sexe;
  final String? dateNaissance; // format ISO 'YYYY-MM-DD'
  final String? telephone;
  final String? quartier; // UUID de Zone, ou null
  final String? utilisateur; // UUID d'Utilisateur, ou null (assigné serveur)

  Patient({
    required this.id,
    required this.numeroSante,
    required this.nom,
    required this.prenoms,
    required this.sexe,
    this.dateNaissance,
    this.telephone,
    this.quartier,
    this.utilisateur,
  });

  String get nomComplet => '$prenoms $nom';

  factory Patient.fromJson(Map<String, dynamic> json) {
    return Patient(
      id: json['id'] as String,
      numeroSante: json['numero_sante'] as String? ?? '',
      nom: json['nom'] as String,
      prenoms: json['prenoms'] as String,
      sexe: json['sexe'] as String,
      dateNaissance: json['date_naissance'] as String?,
      telephone: json['telephone'] as String?,
      quartier: json['quartier'] as String?,
      utilisateur: json['utilisateur'] as String?,
    );
  }

  /// Corps de requête pour `POST /api/accounts/patients/` — les champs
  /// `id`, `numero_sante` et `utilisateur` sont en lecture seule côté
  /// serveur et ne doivent pas être envoyés.
  static Map<String, dynamic> creationBody({
    required String nom,
    required String prenoms,
    required String sexe,
    String? dateNaissance,
    String? telephone,
    String? quartier,
  }) {
    final body = <String, dynamic>{
      'nom': nom,
      'prenoms': prenoms,
      'sexe': sexe,
    };
    if (dateNaissance != null && dateNaissance.isNotEmpty) {
      body['date_naissance'] = dateNaissance;
    }
    if (telephone != null && telephone.isNotEmpty) {
      body['telephone'] = telephone;
    }
    if (quartier != null && quartier.isNotEmpty) {
      body['quartier'] = quartier;
    }
    return body;
  }
}
