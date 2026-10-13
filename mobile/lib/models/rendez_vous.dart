/// Rendez-vous confirmé (`scheduling.RendezVous`). Champs confirmés
/// dans `backend/scheduling/serializers.py::RendezVousSerializer`.
///
/// Limite connue de l'API (voir mobile/README.md, section « limites
/// connues ») : ce serializer ne renvoie que les IDENTIFIANTS
/// `patient`, `creneau`, `exercice`, `type_consultation` — pas les
/// objets imbriqués (donc pas directement l'heure du rendez-vous, ni
/// le nom du praticien). L'app enrichit l'affichage côté client :
/// - via `PatientsService`/`DirectoryService` pour retrouver un nom de
///   patient et de praticien/établissement à partir de ces IDs ;
/// - via un petit cache local (`LocalCacheService`) rempli au moment
///   de la réservation (P-08/P-10), qui retient l'horaire du créneau
///   pour les rendez-vous pris depuis cette app. Un rendez-vous dont
///   l'horaire n'est pas dans ce cache (ex. pris par téléphone, ou
///   après une réinstallation de l'app) s'affiche sans heure précise.
class RendezVous {
  static const String reserve = 'reserve';
  static const String arrive = 'arrive';
  static const String enConsultation = 'en_consultation';
  static const String termine = 'termine';
  static const String absent = 'absent';
  static const String annule = 'annule';

  static const String canalApplication = 'application';
  static const String canalTelephone = 'telephone';
  static const String canalSansRendezVous = 'sans_rendez_vous';

  final String id;
  final String patient;
  final String creneau;
  final String exercice;
  final String? typeConsultation;
  final String motif;
  final String statut;
  final String canal;
  final bool depotRequis;
  final bool depotPerdu;
  final String? motifAnnulation;
  final DateTime creeLe;

  RendezVous({
    required this.id,
    required this.patient,
    required this.creneau,
    required this.exercice,
    this.typeConsultation,
    required this.motif,
    required this.statut,
    required this.canal,
    required this.depotRequis,
    required this.depotPerdu,
    this.motifAnnulation,
    required this.creeLe,
  });

  bool get estAnnule => statut == annule;
  bool get estPasse =>
      statut == termine || statut == absent || statut == annule;

  factory RendezVous.fromJson(Map<String, dynamic> json) {
    return RendezVous(
      id: json['id'] as String,
      patient: json['patient'] as String,
      creneau: json['creneau'] as String,
      exercice: json['exercice'] as String,
      typeConsultation: json['type_consultation'] as String?,
      motif: json['motif'] as String? ?? '',
      statut: json['statut'] as String,
      canal: json['canal'] as String? ?? canalApplication,
      depotRequis: json['depot_requis'] as bool? ?? false,
      depotPerdu: json['depot_perdu'] as bool? ?? false,
      motifAnnulation: json['motif_annulation'] as String?,
      creeLe: DateTime.parse(json['cree_le'] as String),
    );
  }

  static String libelleStatut(String statut) {
    switch (statut) {
      case reserve:
        return 'Réservé';
      case arrive:
        return 'Arrivé';
      case enConsultation:
        return 'En consultation';
      case termine:
        return 'Terminé';
      case absent:
        return 'Absent';
      case annule:
        return 'Annulé';
      default:
        return statut;
    }
  }
}
