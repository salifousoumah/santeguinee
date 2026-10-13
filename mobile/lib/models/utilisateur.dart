/// Compte de connexion (`accounts.Utilisateur`), identifié par
/// numéro de téléphone. Champs confirmés dans
/// `backend/accounts/serializers.py::UtilisateurSerializer`.
class Utilisateur {
  final String id;
  final String telephone;
  final String? email;
  final String langue;
  final String statut;
  final String? derniereConnexion;

  Utilisateur({
    required this.id,
    required this.telephone,
    this.email,
    required this.langue,
    required this.statut,
    this.derniereConnexion,
  });

  factory Utilisateur.fromJson(Map<String, dynamic> json) {
    return Utilisateur(
      id: json['id'] as String,
      telephone: json['telephone'] as String,
      email: json['email'] as String?,
      langue: json['langue'] as String? ?? 'fr',
      statut: json['statut'] as String? ?? 'actif',
      derniereConnexion: json['derniere_connexion'] as String?,
    );
  }
}
