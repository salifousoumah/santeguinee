/// Raccourcis de spécialités pour l'écran d'accueil (P-01).
///
/// Pourquoi une liste codée en dur : il n'existe aucun endpoint
/// `GET /api/directory/specialites/` côté backend (confirmé dans
/// `backend/directory/urls.py`) — `Specialite` n'apparaît qu'imbriquée
/// dans les résultats de recherche de praticiens. Ces codes
/// correspondent EXACTEMENT aux spécialités créées par
/// `backend/directory/management/commands/seed_demo.py`, pour que les
/// raccourcis fonctionnent avec les données de démonstration. Si une
/// vraie liste dynamique de spécialités est nécessaire plus tard,
/// exposer un endpoint dédié côté API plutôt que d'élargir cette
/// liste côdée en dur.
class SpecialiteRapide {
  final String code;
  final String libelle;
  final String icone;

  const SpecialiteRapide({
    required this.code,
    required this.libelle,
    required this.icone,
  });
}

const List<SpecialiteRapide> specialitesRapides = [
  SpecialiteRapide(code: 'MED_GEN', libelle: 'Médecine générale', icone: '🩺'),
  SpecialiteRapide(code: 'PEDIATRIE', libelle: 'Pédiatrie', icone: '🧒'),
  SpecialiteRapide(code: 'GYNECO', libelle: 'Gynécologie', icone: '👩‍⚕️'),
  SpecialiteRapide(code: 'CARDIO', libelle: 'Cardiologie', icone: '❤️'),
  SpecialiteRapide(code: 'DENTAIRE', libelle: 'Dentaire', icone: '🦷'),
  SpecialiteRapide(code: 'DERMATO', libelle: 'Dermatologie', icone: '🧴'),
  SpecialiteRapide(code: 'OPHTALMO', libelle: 'Ophtalmologie', icone: '👁️'),
  SpecialiteRapide(code: 'LABO', libelle: 'Laboratoire', icone: '🧪'),
];
