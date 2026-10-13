import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lien_proche.dart';
import '../models/patient.dart';
import '../models/utilisateur.dart';
import 'api_client.dart';
import 'patients_service.dart';

/// État global de session de l'app : utilisateur connecté, jeton,
/// profils patients gérés (soi-même + "proches").
///
/// Limite d'API à connaître : le backend ne propose aucun endpoint
/// "qui suis-je" (`/me/`) — l'objet `Utilisateur` n'est renvoyé qu'une
/// seule fois, par `POST /auth/verification-code/`. Pour survivre à un
/// redémarrage de l'app sans forcer une reconnexion, cette classe
/// persiste donc elle-même ce JSON `Utilisateur` en local
/// (`shared_preferences`), en plus du jeton déjà géré par [ApiClient].
/// Si le jeton a été révoqué côté serveur entre-temps, le premier appel
/// authentifié échouera avec un 401 — c'est aux écrans appelants de
/// rediriger vers la connexion dans ce cas (voir ApiException).
class AppSession extends ChangeNotifier {
  AppSession({
    required ApiClient apiClient,
    required PatientsService patientsService,
  })  : _apiClient = apiClient,
        _patientsService = patientsService;

  static const String _prefUtilisateurKey = 'santeguinee_utilisateur';

  final ApiClient _apiClient;
  final PatientsService _patientsService;

  Utilisateur? _utilisateur;
  List<Patient> _patients = <Patient>[];
  List<LienProche> _liens = <LienProche>[];
  bool _chargementInitialFait = false;
  bool _chargementEnCours = false;

  Utilisateur? get utilisateur => _utilisateur;

  bool get estConnecte => _apiClient.estAuthentifie && _utilisateur != null;

  bool get chargementInitialFait => _chargementInitialFait;

  bool get chargementEnCours => _chargementEnCours;

  List<Patient> get patients => List.unmodifiable(_patients);

  List<LienProche> get liens => List.unmodifiable(_liens);

  /// Le profil patient du titulaire du compte lui-même (par
  /// opposition à ses "proches"). Déterminé en écartant, parmi les
  /// patients gérés, ceux qui apparaissent comme cible (`patient`)
  /// d'un `LienProche` — voir modèle `Patient` pour le détail de cette
  /// règle (le serveur ne distingue pas explicitement "soi-même" d'un
  /// "proche" sur le modèle Patient lui-même).
  Patient? get patientPrincipal {
    if (_patients.isEmpty) return null;
    final procheIds = _liens.map((l) => l.patient).toSet();
    return _patients.firstWhere(
      (p) => !procheIds.contains(p.id),
      orElse: () => _patients.first,
    );
  }

  bool get possedeProfilPatient => patientPrincipal != null;

  List<Patient> get proches {
    final procheIds = _liens.map((l) => l.patient).toSet();
    return _patients.where((p) => procheIds.contains(p.id)).toList();
  }

  /// À appeler une seule fois au démarrage de l'app.
  Future<void> demarrer() async {
    await _apiClient.chargerJetonSauvegarde();
    await _chargerUtilisateurSauvegarde();
    if (_apiClient.estAuthentifie && _utilisateur != null) {
      await rafraichirPatients();
    }
    _chargementInitialFait = true;
    notifyListeners();
  }

  Future<void> _chargerUtilisateurSauvegarde() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final brut = prefs.getString(_prefUtilisateurKey);
      if (brut != null && brut.isNotEmpty) {
        _utilisateur = Utilisateur.fromJson(
          jsonDecode(brut) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      _utilisateur = null;
    }
  }

  Future<void> _sauvegarderUtilisateur(Utilisateur? utilisateur) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (utilisateur == null) {
        await prefs.remove(_prefUtilisateurKey);
      } else {
        await prefs.setString(
          _prefUtilisateurKey,
          jsonEncode({
            'id': utilisateur.id,
            'telephone': utilisateur.telephone,
            'email': utilisateur.email,
            'langue': utilisateur.langue,
            'statut': utilisateur.statut,
            'derniere_connexion': utilisateur.derniereConnexion,
          }),
        );
      }
    } catch (_) {
      // Non bloquant.
    }
  }

  /// Appelé juste après une vérification de code SMS réussie (P-12).
  Future<void> ouvrirSession(Utilisateur utilisateur, String token) async {
    _utilisateur = utilisateur;
    await _apiClient.definirJeton(token);
    await _sauvegarderUtilisateur(utilisateur);
    await rafraichirPatients();
    notifyListeners();
  }

  /// Recharge la liste des patients gérés (soi-même + proches) et des
  /// liens "proches". Appelé après connexion, après création d'un
  /// profil patient (P-12) ou d'un proche (P-13).
  Future<void> rafraichirPatients() async {
    _chargementEnCours = true;
    notifyListeners();
    try {
      final patients = await _patientsService.listerPatients();
      final liens = await _patientsService.listerLiensProches();
      _patients = patients;
      _liens = liens;
    } catch (_) {
      // On conserve les anciennes valeurs ; l'écran appelant affiche
      // son propre message d'erreur pour l'action qu'il a demandée.
    } finally {
      _chargementEnCours = false;
      notifyListeners();
    }
  }

  Future<void> deconnexion() async {
    _utilisateur = null;
    _patients = <Patient>[];
    _liens = <LienProche>[];
    await _apiClient.definirJeton(null);
    await _sauvegarderUtilisateur(null);
    notifyListeners();
  }
}
