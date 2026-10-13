import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Informations d'affichage pour un rendez-vous, retenues localement
/// au moment de la réservation (P-08/P-10).
///
/// Pourquoi ce cache existe (limite connue de l'API, voir
/// mobile/README.md) : `RendezVousSerializer` (backend) ne renvoie que
/// les IDENTIFIANTS `creneau` et `exercice`, pas leurs objets imbriqués
/// — il n'y a pas non plus d'endpoint `GET /creneaux/<id>/` de détail.
/// Sans ce cache, l'écran "Mes rendez-vous" (P-11) ne pourrait afficher
/// aucune heure ni aucun nom de praticien pour les rendez-vous déjà
/// confirmés. Ce cache est une commodité d'affichage CÔTÉ CLIENT
/// UNIQUEMENT : il n'est jamais synchronisé entre appareils, ne fait
/// pas autorité, et un rendez-vous pris par un autre canal (téléphone)
/// ou sur un autre appareil ne s'y trouvera pas — l'écran doit toujours
/// se dégrader proprement (afficher "Horaire non disponible") dans ce
/// cas plutôt que planter.
class InfosRendezVousCache {
  final DateTime debut;
  final DateTime fin;
  final String praticienNom;
  final String etablissementNom;

  InfosRendezVousCache({
    required this.debut,
    required this.fin,
    required this.praticienNom,
    required this.etablissementNom,
  });

  Map<String, dynamic> toJson() => {
        'debut': debut.toIso8601String(),
        'fin': fin.toIso8601String(),
        'praticien_nom': praticienNom,
        'etablissement_nom': etablissementNom,
      };

  factory InfosRendezVousCache.fromJson(Map<String, dynamic> json) {
    return InfosRendezVousCache(
      debut: DateTime.parse(json['debut'] as String),
      fin: DateTime.parse(json['fin'] as String),
      praticienNom: json['praticien_nom'] as String? ?? '',
      etablissementNom: json['etablissement_nom'] as String? ?? '',
    );
  }
}

class LocalCacheService {
  static const String _prefKey = 'santeguinee_cache_infos_rdv';

  Future<Map<String, InfosRendezVousCache>> _toutCharger() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_prefKey);
      if (brut == null || brut.isEmpty) return {};
      final decode = jsonDecode(brut) as Map<String, dynamic>;
      return decode.map(
        (cle, valeur) => MapEntry(
          cle,
          InfosRendezVousCache.fromJson(valeur as Map<String, dynamic>),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> _toutSauvegarder(
    Map<String, InfosRendezVousCache> infos,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encode = jsonEncode(
        infos.map((cle, valeur) => MapEntry(cle, valeur.toJson())),
      );
      await prefs.setString(_prefKey, encode);
    } catch (_) {
      // Non bloquant : l'enrichissement est une simple commodité d'affichage.
    }
  }

  Future<void> enregistrer(String rendezVousId, InfosRendezVousCache infos) async {
    final tout = await _toutCharger();
    tout[rendezVousId] = infos;
    await _toutSauvegarder(tout);
  }

  Future<InfosRendezVousCache?> recuperer(String rendezVousId) async {
    final tout = await _toutCharger();
    return tout[rendezVousId];
  }

  Future<Map<String, InfosRendezVousCache>> toutRecuperer() async {
    return _toutCharger();
  }
}
