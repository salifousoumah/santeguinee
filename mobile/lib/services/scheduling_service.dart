import '../models/creneau.dart';
import '../models/paginated_response.dart';
import '../models/rendez_vous.dart';
import 'api_client.dart';

/// Prise de rendez-vous (modules M4/M5). Endpoints confirmés dans
/// `backend/scheduling/urls.py` + `backend/scheduling/views.py`.
class SchedulingService {
  SchedulingService(this._client);

  final ApiClient _client;

  /// GET /api/scheduling/creneaux/?exercice=<uuid>&statut=libre
  /// Aucune authentification requise pour consulter les créneaux
  /// libres (P-07) ; elle devient nécessaire pour les verrouiller et
  /// confirmer un rendez-vous.
  Future<List<Creneau>> listerCreneauxLibres(String exerciceId) async {
    final creneaux = <Creneau>[];
    var json = await _client.get(
      '/api/scheduling/creneaux/',
      auth: false,
      query: {'exercice': exerciceId, 'statut': Creneau.libre},
    ) as Map<String, dynamic>;
    var page = PaginatedResponse.fromJson(json, Creneau.fromJson);
    creneaux.addAll(page.results);
    while (page.hasNext) {
      json = await _client.getAbsolu(page.next!, auth: false)
          as Map<String, dynamic>;
      page = PaginatedResponse.fromJson(json, Creneau.fromJson);
      creneaux.addAll(page.results);
    }
    return creneaux;
  }

  /// POST /api/scheduling/creneaux/<uuid>/verrouiller/
  /// RG-06 : verrouille le créneau pendant 5 minutes. Lève une
  /// [ApiException] (404 créneau introuvable, 409 déjà pris) sinon.
  Future<Creneau> verrouillerCreneau(String creneauId) async {
    final json = await _client.post(
      '/api/scheduling/creneaux/$creneauId/verrouiller/',
    ) as Map<String, dynamic>;
    return Creneau.fromJson(json);
  }

  /// POST /api/scheduling/rendez-vous/confirmer/
  /// {patient_id, creneau_id, exercice_id, motif}
  /// `type_consultation_id` est volontairement omis : aucun endpoint
  /// ne liste les `TypeConsultation` disponibles pour un exercice côté
  /// API (voir mobile/README.md, limites connues) ; le champ est
  /// optionnel côté serveur donc l'omettre est sûr.
  Future<RendezVous> confirmerRendezVous({
    required String patientId,
    required String creneauId,
    required String exerciceId,
    String motif = '',
  }) async {
    final json = await _client.post(
      '/api/scheduling/rendez-vous/confirmer/',
      body: {
        'patient_id': patientId,
        'creneau_id': creneauId,
        'exercice_id': exerciceId,
        'motif': motif,
      },
    ) as Map<String, dynamic>;
    return RendezVous.fromJson(json);
  }

  /// GET /api/scheduling/rendez-vous/mes-rendez-vous/
  Future<List<RendezVous>> listerMesRendezVous() async {
    final rendezVous = <RendezVous>[];
    var json = await _client.get(
      '/api/scheduling/rendez-vous/mes-rendez-vous/',
    ) as Map<String, dynamic>;
    var page = PaginatedResponse.fromJson(json, RendezVous.fromJson);
    rendezVous.addAll(page.results);
    while (page.hasNext) {
      json = await _client.getAbsolu(page.next!) as Map<String, dynamic>;
      page = PaginatedResponse.fromJson(json, RendezVous.fromJson);
      rendezVous.addAll(page.results);
    }
    return rendezVous;
  }

  /// POST /api/scheduling/rendez-vous/<uuid>/annuler/ {motif}
  Future<RendezVous> annulerRendezVous(String rendezVousId, {String motif = ''}) async {
    final json = await _client.post(
      '/api/scheduling/rendez-vous/$rendezVousId/annuler/',
      body: {'motif': motif},
    ) as Map<String, dynamic>;
    return RendezVous.fromJson(json);
  }
}
