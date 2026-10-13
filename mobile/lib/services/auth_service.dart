import '../models/utilisateur.dart';
import 'api_client.dart';

/// Résultat d'une vérification de code SMS réussie.
class ResultatConnexion {
  final String token;
  final Utilisateur utilisateur;

  ResultatConnexion({required this.token, required this.utilisateur});
}

/// Flux de connexion par téléphone + code SMS (module M2). Endpoints
/// confirmés dans `backend/accounts/urls.py` + `backend/accounts/views.py`.
class AuthService {
  AuthService(this._client);

  final ApiClient _client;

  /// POST /api/accounts/auth/demande-code/ {telephone}
  /// Déclenche l'envoi du code (en démo : affiché dans les logs du
  /// serveur backend, voir `backend/accounts/sms.py`).
  Future<void> demanderCode(String telephone) async {
    await _client.post(
      '/api/accounts/auth/demande-code/',
      auth: false,
      body: {'telephone': telephone},
    );
  }

  /// POST /api/accounts/auth/verification-code/ {telephone, code}
  /// Renvoie le jeton DRF + l'utilisateur en cas de succès ; lève une
  /// [ApiException] (code invalide/expiré/trop de tentatives) sinon.
  Future<ResultatConnexion> verifierCode(String telephone, String code) async {
    final json = await _client.post(
      '/api/accounts/auth/verification-code/',
      auth: false,
      body: {'telephone': telephone, 'code': code},
    ) as Map<String, dynamic>;
    return ResultatConnexion(
      token: json['token'] as String,
      utilisateur: Utilisateur.fromJson(
        json['utilisateur'] as Map<String, dynamic>,
      ),
    );
  }
}
