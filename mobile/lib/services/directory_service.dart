import '../models/etablissement.dart';
import '../models/paginated_response.dart';
import '../models/praticien.dart';
import 'api_client.dart';

/// Recherche dans l'annuaire (module M1, aucune authentification
/// requise). Endpoints confirmés dans `backend/directory/urls.py` +
/// `backend/directory/views.py`.
class DirectoryService {
  DirectoryService(this._client);

  final ApiClient _client;

  Future<PaginatedResponse<Etablissement>> rechercherEtablissements({
    String? q,
    String? specialite,
    String? zone,
    String? secteur,
    bool? urgences24h,
    bool? ouvertMaintenant,
    double? lat,
    double? lon,
  }) async {
    final json = await _client.get(
      '/api/directory/etablissements/',
      auth: false,
      query: {
        'q': q,
        'specialite': specialite,
        'zone': zone,
        'secteur': secteur,
        'urgences_24h': urgences24h == null ? null : urgences24h.toString(),
        'ouvert_maintenant':
            ouvertMaintenant == null ? null : ouvertMaintenant.toString(),
        'lat': lat?.toString(),
        'lon': lon?.toString(),
      },
    );
    return PaginatedResponse.fromJson(
      json as Map<String, dynamic>,
      Etablissement.fromJson,
    );
  }

  Future<PaginatedResponse<Etablissement>> pageSuivanteEtablissements(
    String urlSuivante,
  ) async {
    final json = await _client.getAbsolu(urlSuivante, auth: false);
    return PaginatedResponse.fromJson(
      json as Map<String, dynamic>,
      Etablissement.fromJson,
    );
  }

  Future<PaginatedResponse<Praticien>> rechercherPraticiens({
    String? q,
    String? specialite,
    String? profession,
  }) async {
    final json = await _client.get(
      '/api/directory/praticiens/',
      auth: false,
      query: {
        'q': q,
        'specialite': specialite,
        'profession': profession,
      },
    );
    return PaginatedResponse.fromJson(
      json as Map<String, dynamic>,
      Praticien.fromJson,
    );
  }

  Future<PaginatedResponse<Praticien>> pageSuivantePraticiens(
    String urlSuivante,
  ) async {
    final json = await _client.getAbsolu(urlSuivante, auth: false);
    return PaginatedResponse.fromJson(
      json as Map<String, dynamic>,
      Praticien.fromJson,
    );
  }

  /// Récupère TOUS les praticiens vérifiés (en suivant la pagination),
  /// utilisé pour retrouver les praticiens exerçant dans un
  /// établissement donné (P-05), faute d'un paramètre `etablissement`
  /// sur `GET /api/directory/praticiens/` côté serveur. Le volume de
  /// données de démonstration reste faible (quelques dizaines de
  /// praticiens), donc ce balayage complet est acceptable pour ce MVP.
  Future<List<Praticien>> tousLesPraticiensVerifies() async {
    final praticiens = <Praticien>[];
    var page = await rechercherPraticiens();
    praticiens.addAll(page.results);
    while (page.hasNext) {
      page = await pageSuivantePraticiens(page.next!);
      praticiens.addAll(page.results);
    }
    return praticiens;
  }
}
