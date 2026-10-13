import 'exercice.dart';
import 'specialite.dart';

/// Professionnel de santé (`directory.Praticien`). Champs confirmés
/// dans `backend/directory/serializers.py::PraticienSerializer`.
///
/// Comme pour `Etablissement`, il n'y a pas de
/// `GET /praticiens/<id>/` de détail côté serveur : seule la liste de
/// recherche (`GET /api/directory/praticiens/`) existe. La fiche
/// praticien (P-06) réutilise donc l'objet transmis depuis la liste de
/// résultats (P-02) ou la fiche établissement (P-05).
class Praticien {
  static const String medecin = 'medecin';
  static const String sageFemme = 'sage_femme';
  static const String dentiste = 'dentiste';
  static const String infirmier = 'infirmier';
  static const String kinesitherapeute = 'kinesitherapeute';

  static const String statutVerifie = 'verifie';

  final String id;
  final String civilite;
  final String nom;
  final String prenoms;
  final String profession;
  final String numeroOrdre;
  final String langues; // valeurs séparées par des virgules
  final String presentation;
  final String statutVerification;
  final List<Specialite> specialites;
  final List<Exercice> exercices;

  Praticien({
    required this.id,
    required this.civilite,
    required this.nom,
    required this.prenoms,
    required this.profession,
    required this.numeroOrdre,
    required this.langues,
    required this.presentation,
    required this.statutVerification,
    required this.specialites,
    required this.exercices,
  });

  String get nomAffiche =>
      civilite.isNotEmpty ? '$civilite $nom $prenoms' : '$nom $prenoms';

  List<String> get listeLangues => langues
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  factory Praticien.fromJson(Map<String, dynamic> json) {
    return Praticien(
      id: json['id'] as String,
      civilite: json['civilite'] as String? ?? '',
      nom: json['nom'] as String,
      prenoms: json['prenoms'] as String,
      profession: json['profession'] as String,
      numeroOrdre: json['numero_ordre'] as String? ?? '',
      langues: json['langues'] as String? ?? '',
      presentation: json['presentation'] as String? ?? '',
      statutVerification: json['statut_verification'] as String? ?? '',
      specialites: (json['specialites'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => Specialite.fromJson(e as Map<String, dynamic>))
          .toList(),
      exercices: (json['exercices'] as List<dynamic>? ?? <dynamic>[])
          .map((e) => Exercice.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static String libelleProfession(String profession) {
    switch (profession) {
      case medecin:
        return 'Médecin';
      case sageFemme:
        return 'Sage-femme';
      case dentiste:
        return 'Dentiste';
      case infirmier:
        return 'Infirmier(ère)';
      case kinesitherapeute:
        return 'Kinésithérapeute';
      default:
        return profession;
    }
  }
}
