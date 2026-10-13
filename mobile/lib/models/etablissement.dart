import 'zone.dart';

/// Établissement de santé (`directory.Etablissement`). Champs
/// confirmés dans
/// `backend/directory/serializers.py::EtablissementSerializer`.
///
/// Note (voir mobile/README.md) : la recherche
/// (`GET /api/directory/etablissements/`) est le SEUL endpoint exposé
/// côté serveur pour les établissements — il n'y a pas de
/// `GET /etablissements/<id>/` de détail. La fiche établissement
/// (P-05) réutilise donc l'objet obtenu depuis la liste de résultats
/// (P-02), transmis en argument de navigation plutôt que re-fetché.
class Etablissement {
  // Types (choix non exhaustif mais réel, voir Etablissement.TYPE_CHOICES)
  static const String chu = 'CHU';
  static const String hopitalRegional = 'hopital_regional';
  static const String hopitalPrefectoral = 'hopital_prefectoral';
  static const String centreSante = 'centre_sante';
  static const String posteSante = 'poste_sante';
  static const String clinique = 'clinique';
  static const String cabinet = 'cabinet';
  static const String laboratoire = 'laboratoire';
  static const String pharmacie = 'pharmacie';

  // Secteurs
  static const String secteurPublic = 'public';
  static const String secteurPrive = 'prive';
  static const String secteurConfessionnel = 'confessionnel';
  static const String secteurOng = 'ong';

  // Statuts de vérification
  static const String statutVerifie = 'verifie';
  static const String statutEnAttente = 'en_attente';
  static const String statutRejete = 'rejete';

  final String id;
  final String nom;
  final String type;
  final String secteur;
  final double? latitude;
  final double? longitude;
  final String repere;
  final Zone? quartier;
  final String telephones; // valeurs séparées par des virgules
  final bool urgences24h;
  final String moyensPaiement; // valeurs séparées par des virgules
  final String statutVerification;
  final double? distanceKm; // null si lat/lon absents de la requête
  final bool ouvertMaintenant;

  Etablissement({
    required this.id,
    required this.nom,
    required this.type,
    required this.secteur,
    this.latitude,
    this.longitude,
    required this.repere,
    this.quartier,
    required this.telephones,
    required this.urgences24h,
    required this.moyensPaiement,
    required this.statutVerification,
    this.distanceKm,
    required this.ouvertMaintenant,
  });

  List<String> get listeTelephones => telephones
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  List<String> get listeMoyensPaiement => moyensPaiement
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  factory Etablissement.fromJson(Map<String, dynamic> json) {
    return Etablissement(
      id: json['id'] as String,
      nom: json['nom'] as String,
      type: json['type'] as String,
      secteur: json['secteur'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      repere: json['repere'] as String? ?? '',
      quartier: json['quartier'] == null
          ? null
          : Zone.fromJson(json['quartier'] as Map<String, dynamic>),
      telephones: json['telephones'] as String? ?? '',
      urgences24h: json['urgences_24h'] as bool? ?? false,
      moyensPaiement: json['moyens_paiement'] as String? ?? '',
      statutVerification: json['statut_verification'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      ouvertMaintenant: json['ouvert_maintenant'] as bool? ?? false,
    );
  }

  static String libelleType(String type) {
    switch (type) {
      case chu:
        return 'CHU';
      case hopitalRegional:
        return 'Hôpital régional';
      case hopitalPrefectoral:
        return 'Hôpital préfectoral';
      case centreSante:
        return 'Centre de santé';
      case posteSante:
        return 'Poste de santé';
      case clinique:
        return 'Clinique';
      case cabinet:
        return 'Cabinet';
      case laboratoire:
        return 'Laboratoire';
      case pharmacie:
        return 'Pharmacie';
      default:
        return type;
    }
  }

  static String libelleSecteur(String secteur) {
    switch (secteur) {
      case secteurPublic:
        return 'Public';
      case secteurPrive:
        return 'Privé';
      case secteurConfessionnel:
        return 'Confessionnel';
      case secteurOng:
        return 'ONG';
      default:
        return secteur;
    }
  }

  static String libelleMoyenPaiement(String code) {
    switch (code) {
      case 'especes':
        return 'Espèces';
      case 'mobile_money':
        return 'Mobile money';
      case 'carte':
        return 'Carte bancaire';
      case 'assurance':
        return 'Assurance';
      default:
        return code;
    }
  }
}
