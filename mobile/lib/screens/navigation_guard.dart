import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_session.dart';
import 'connexion_screen.dart';
import 'creer_profil_screen.dart';

/// S'assure que l'utilisateur est connecté ET possède un profil
/// patient avant une action qui en a besoin (verrouiller un créneau,
/// réserver, gérer ses proches). Pousse [ConnexionScreen] puis, si
/// besoin, [CreerProfilScreen]. Retourne `true` seulement si les deux
/// conditions sont remplies à la fin (soit déjà, soit après ces
/// écrans), `false` si l'utilisateur a abandonné en route.
Future<bool> exigerConnexionEtProfil(BuildContext context) async {
  final session = context.read<AppSession>();

  if (!session.estConnecte) {
    final resultat = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const ConnexionScreen()),
    );
    if (resultat != true || !session.estConnecte) {
      return false;
    }
  }

  if (!session.possedeProfilPatient) {
    final resultat = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreerProfilScreen()),
    );
    if (resultat != true || !session.possedeProfilPatient) {
      return false;
    }
  }

  return true;
}
