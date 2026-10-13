import '../models/lien_proche.dart';
import '../models/paginated_response.dart';
import '../models/patient.dart';
import 'api_client.dart';

/// Gestion des profils patients et des liens "proches" (RG-24).
/// Endpoints confirmés dans `backend/accounts/urls.py` +
/// `backend/accounts/views.py` (authentification requise).
class PatientsService {
  PatientsService(this._client);

  final ApiClient _client;

  /// GET /api/accounts/patients/ — le propre profil de l'utilisateur
  /// connecté et ceux de ses "proches" (même réponse paginée).
  Future<List<Patient>> listerPatients() async {
    final patients = <Patient>[];
    var json =
        await _client.get('/api/accounts/patients/') as Map<String, dynamic>;
    var page = PaginatedResponse.fromJson(json, Patient.fromJson);
    patients.addAll(page.results);
    while (page.hasNext) {
      json = await _client.getAbsolu(page.next!) as Map<String, dynamic>;
      page = PaginatedResponse.fromJson(json, Patient.fromJson);
      patients.addAll(page.results);
    }
    return patients;
  }

  /// POST /api/accounts/patients/
  /// `numero_sante` et `utilisateur` sont assignés par le serveur.
  Future<Patient> creerPatient({
    required String nom,
    required String prenoms,
    required String sexe,
    String? dateNaissance,
    String? telephone,
    String? quartier,
  }) async {
    final json = await _client.post(
      '/api/accounts/patients/',
      body: Patient.creationBody(
        nom: nom,
        prenoms: prenoms,
        sexe: sexe,
        dateNaissance: dateNaissance,
        telephone: telephone,
        quartier: quartier,
      ),
    ) as Map<String, dynamic>;
    return Patient.fromJson(json);
  }

  /// GET /api/accounts/liens-proches/
  Future<List<LienProche>> listerLiensProches() async {
    final liens = <LienProche>[];
    var json =
        await _client.get('/api/accounts/liens-proches/') as Map<String, dynamic>;
    var page = PaginatedResponse.fromJson(json, LienProche.fromJson);
    liens.addAll(page.results);
    while (page.hasNext) {
      json = await _client.getAbsolu(page.next!) as Map<String, dynamic>;
      page = PaginatedResponse.fromJson(json, LienProche.fromJson);
      liens.addAll(page.results);
    }
    return liens;
  }

  /// POST /api/accounts/liens-proches/
  /// RG-24 : le serveur refuse au-delà de 10 proches par titulaire et
  /// renvoie un message de validation (`non_field_errors`) que
  /// [ApiException.message] expose directement — à afficher à
  /// l'utilisateur sans le traiter comme une erreur technique.
  Future<LienProche> creerLienProche({
    required String titulaire,
    required String patient,
    required String lien,
    String droits = 'gestion_complete',
  }) async {
    final json = await _client.post(
      '/api/accounts/liens-proches/',
      body: LienProche.creationBody(
        titulaire: titulaire,
        patient: patient,
        lien: lien,
        droits: droits,
      ),
    ) as Map<String, dynamic>;
    return LienProche.fromJson(json);
  }
}
