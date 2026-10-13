import 'package:flutter/material.dart';

import '../models/exercice.dart';
import '../models/praticien.dart';
import '../widgets/badges.dart';
import 'choix_creneau_screen.dart';
import 'navigation_guard.dart';

/// P-06 Fiche praticien.
///
/// Reçoit le [Praticien] déjà chargé depuis la liste de résultats
/// (P-02) ou la fiche établissement (P-05) : il n'existe pas de
/// `GET /api/directory/praticiens/<id>/` côté backend (voir
/// `backend/directory/urls.py` — liste de recherche uniquement).
class FichePraticienScreen extends StatelessWidget {
  const FichePraticienScreen({super.key, required this.praticien});

  final Praticien praticien;

  Future<void> _choisirCreneau(BuildContext context, Exercice exercice) async {
    final autorise = await exigerConnexionEtProfil(context);
    if (!autorise || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChoixCreneauScreen(
          exercice: exercice,
          praticienNom: praticien.nomAffiche,
          etablissementNom: exercice.etablissementNom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = praticien;
    final exercicesActifs = p.exercices.where((ex) => ex.actif).toList();

    return Scaffold(
      appBar: AppBar(title: Text(p.nomAffiche)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (p.statutVerification == Praticien.statutVerifie)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: BadgeVerifie(),
            ),
          Text(
            Praticien.libelleProfession(p.profession),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (p.numeroOrdre.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('N° d\'ordre : ${p.numeroOrdre}',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          if (p.specialites.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.specialites
                  .map((s) => Chip(label: Text(s.libelleAffiche)))
                  .toList(),
            ),
          ],
          if (p.listeLangues.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Langues parlées : ${p.listeLangues.join(', ')}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (p.presentation.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(p.presentation),
          ],
          const SizedBox(height: 20),
          Text('Lieux d\'exercice', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (exercicesActifs.isEmpty)
            const Text('Aucun lieu d\'exercice réservable en ligne pour le moment.')
          else
            ...exercicesActifs.map(
              (exercice) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercice.etablissementNom,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        exercice.tarifIndicatifGnf != null
                            ? 'Tarif indicatif : ${exercice.tarifIndicatifGnf} GNF'
                            : 'Tarif indicatif non renseigné',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: () => _choisirCreneau(context, exercice),
                          child: const Text('Choisir un créneau'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
