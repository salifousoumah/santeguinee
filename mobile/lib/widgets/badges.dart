import 'package:flutter/material.dart';

/// Petit badge "Vérifié" (fiche établissement/praticien dont le
/// `statut_verification` est `verifie`). Dans cette app, seules des
/// fiches vérifiées sont jamais renvoyées par la recherche (le backend
/// les filtre déjà), mais le badge reste utile pour la confiance de
/// l'utilisateur.
class BadgeVerifie extends StatelessWidget {
  const BadgeVerifie({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: scheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            'Vérifié',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge "Ouvert maintenant" / "Fermé" pour un établissement.
class BadgeOuvert extends StatelessWidget {
  const BadgeOuvert({super.key, required this.ouvert});

  final bool ouvert;

  @override
  Widget build(BuildContext context) {
    final couleurFond = ouvert ? Colors.green.shade100 : Colors.grey.shade300;
    final couleurTexte = ouvert ? Colors.green.shade800 : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleurFond,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        ouvert ? 'Ouvert maintenant' : 'Fermé',
        style: TextStyle(
          fontSize: 12,
          color: couleurTexte,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Badge "Urgences 24h/24".
class BadgeUrgences extends StatelessWidget {
  const BadgeUrgences({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emergency, size: 14, color: Colors.red.shade700),
          const SizedBox(width: 4),
          Text(
            'Urgences 24h/24',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
