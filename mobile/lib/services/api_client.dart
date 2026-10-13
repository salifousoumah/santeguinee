import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Erreur levée pour toute réponse API non 2xx, ou en cas d'échec
/// réseau. `message` est toujours un texte français prêt à être
/// affiché directement à l'utilisateur (ex. dans un SnackBar).
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Client HTTP minimal pour l'API SantéGuinée : gère l'URL de base,
/// l'en-tête `Authorization: Token <token>`, la persistance du jeton
/// (via `shared_preferences`) et une extraction cohérente des messages
/// d'erreur renvoyés par DRF, qu'ils arrivent sous la forme
/// `{"detail": "..."}` (erreurs métier / permissions) ou sous la forme
/// `{"champ": ["message"]}` (erreurs de validation de serializer).
class ApiClient {
  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;
  String? _token;

  static const String _tokenPrefKey = 'santeguinee_auth_token';

  String? get token => _token;

  bool get estAuthentifie => _token != null && _token!.isNotEmpty;

  /// À appeler une fois au démarrage de l'app pour recharger un jeton
  /// précédemment enregistré (connexion persistante entre sessions).
  Future<void> chargerJetonSauvegarde() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenPrefKey);
    } catch (_) {
      // Stockage indisponible (ex. tests) : on continue sans jeton.
      _token = null;
    }
  }

  Future<void> definirJeton(String? token) async {
    _token = token;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null || token.isEmpty) {
        await prefs.remove(_tokenPrefKey);
      } else {
        await prefs.setString(_tokenPrefKey, token);
      }
    } catch (_) {
      // Pas bloquant : le jeton reste au moins valide pour la session en cours.
    }
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final nettoye = <String, String>{};
    query?.forEach((cle, valeur) {
      if (valeur != null && valeur.isNotEmpty) {
        nettoye[cle] = valeur;
      }
    });
    return Uri.parse('${ApiConfig.baseUrl}$path')
        .replace(queryParameters: nettoye.isEmpty ? null : nettoye);
  }

  Map<String, String> _headers({bool withAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (withAuth && _token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Token $_token';
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, String?>? query,
    bool auth = true,
  }) {
    return _envoyer(() => _httpClient
        .get(_uri(path, query), headers: _headers(withAuth: auth))
        .timeout(ApiConfig.timeout));
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _envoyer(() => _httpClient
        .post(
          _uri(path),
          headers: _headers(withAuth: auth),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(ApiConfig.timeout));
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _envoyer(() => _httpClient
        .patch(
          _uri(path),
          headers: _headers(withAuth: auth),
          body: jsonEncode(body ?? <String, dynamic>{}),
        )
        .timeout(ApiConfig.timeout));
  }

  Future<dynamic> delete(String path, {bool auth = true}) {
    return _envoyer(() => _httpClient
        .delete(_uri(path), headers: _headers(withAuth: auth))
        .timeout(ApiConfig.timeout));
  }

  /// Comme [get], mais pour une URL déjà complète — utile pour suivre
  /// les liens `next`/`previous` d'une réponse paginée DRF, qui sont
  /// renvoyés en URL absolue (ex.
  /// `http://10.0.2.2:8000/api/directory/etablissements/?page=2`).
  Future<dynamic> getAbsolu(String url, {bool auth = true}) {
    return _envoyer(() => _httpClient
        .get(Uri.parse(url), headers: _headers(withAuth: auth))
        .timeout(ApiConfig.timeout));
  }

  Future<dynamic> _envoyer(
    Future<http.Response> Function() requete,
  ) async {
    http.Response reponse;
    try {
      reponse = await requete();
    } on TimeoutException {
      throw ApiException(
        'Le serveur ne répond pas. Vérifiez votre connexion et l\'adresse '
        'de l\'API (voir mobile/README.md).',
      );
    } on SocketException {
      throw ApiException(
        'Impossible de contacter le serveur. Vérifiez votre connexion '
        'internet et l\'adresse de l\'API configurée.',
      );
    } on HttpException catch (e) {
      throw ApiException('Erreur réseau : ${e.message}');
    } on FormatException {
      throw ApiException('Réponse du serveur invalide.');
    }
    return _traiter(reponse);
  }

  dynamic _traiter(http.Response reponse) {
    final statut = reponse.statusCode;
    dynamic decode;
    if (reponse.body.isNotEmpty) {
      try {
        decode = jsonDecode(reponse.body);
      } catch (_) {
        decode = null;
      }
    }

    if (statut >= 200 && statut < 300) {
      return decode;
    }

    throw ApiException(_extraireMessage(decode, statut), statusCode: statut);
  }

  String _extraireMessage(dynamic decode, int statut) {
    if (decode is Map<String, dynamic>) {
      final detail = decode['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      final nonFieldErrors = decode['non_field_errors'];
      if (nonFieldErrors is List && nonFieldErrors.isNotEmpty) {
        return nonFieldErrors.first.toString();
      }
      for (final entree in decode.entries) {
        final valeur = entree.value;
        if (valeur is List && valeur.isNotEmpty) {
          return valeur.first.toString();
        }
        if (valeur is String && valeur.isNotEmpty) {
          return valeur;
        }
      }
    }
    if (decode is List && decode.isNotEmpty) {
      return decode.first.toString();
    }
    switch (statut) {
      case 401:
        return 'Session expirée, veuillez vous reconnecter.';
      case 403:
        return 'Action non autorisée.';
      case 404:
        return 'Ressource introuvable.';
      case 409:
        return 'Ce créneau n\'est plus disponible.';
      default:
        return 'Une erreur est survenue (code $statut).';
    }
  }
}
