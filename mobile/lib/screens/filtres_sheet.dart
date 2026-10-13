import 'package:flutter/material.dart';

import '../models/etablissement.dart';

/// Filtres appliqués à la recherche d'établissements (P-04).
///
/// Note (voir mobile/README.md) : la carte (P-03) est volontairement
/// hors périmètre de cette passe — comme le backend, qui n'utilise pas
/// PostGIS/GeoDjango — donc aucun filtre géographique (rayon, zone sur
/// carte) n'est proposé ici, seulement ceux déjà supportés par
/// `GET /api/directory/etablissements/` : secteur, ouvert_maintenant,
/// urgences_24h.
class FiltresResultats {
  final String? secteur;
  final bool? ouvertMaintenant;
  final bool? urgences24h;

  const FiltresResultats({
    this.secteur,
    this.ouvertMaintenant,
    this.urgences24h,
  });

  bool get estVide =>
      secteur == null && ouvertMaintenant == null && urgences24h == null;

  FiltresResultats copyWith({
    String? Function()? secteur,
    bool? Function()? ouvertMaintenant,
    bool? Function()? urgences24h,
  }) {
    return FiltresResultats(
      secteur: secteur != null ? secteur() : this.secteur,
      ouvertMaintenant:
          ouvertMaintenant != null ? ouvertMaintenant() : this.ouvertMaintenant,
      urgences24h: urgences24h != null ? urgences24h() : this.urgences24h,
    );
  }
}

/// Ouvre la feuille de filtres (P-04) et retourne les filtres choisis,
/// ou `null` si l'utilisateur a fermé la feuille sans valider.
Future<FiltresResultats?> afficherFiltresSheet(
  BuildContext context,
  FiltresResultats actuels,
) {
  return showModalBottomSheet<FiltresResultats>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _FiltresSheetContenu(initial: actuels),
  );
}

class _FiltresSheetContenu extends StatefulWidget {
  const _FiltresSheetContenu({required this.initial});

  final FiltresResultats initial;

  @override
  State<_FiltresSheetContenu> createState() => _FiltresSheetContenuState();
}

class _FiltresSheetContenuState extends State<_FiltresSheetContenu> {
  late String? _secteur = widget.initial.secteur;
  late bool _ouvertMaintenant = widget.initial.ouvertMaintenant ?? false;
  late bool _urgences24h = widget.initial.urgences24h ?? false;

  static const _secteurs = [
    (null, 'Tous'),
    (Etablissement.secteurPublic, 'Public'),
    (Etablissement.secteurPrive, 'Privé'),
    (Etablissement.secteurConfessionnel, 'Confessionnel'),
    (Etablissement.secteurOng, 'ONG'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtres', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Secteur', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _secteurs.map((entree) {
                final (valeur, libelle) = entree;
                return ChoiceChip(
                  label: Text(libelle),
                  selected: _secteur == valeur,
                  onSelected: (_) => setState(() => _secteur = valeur),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ouvert maintenant'),
              value: _ouvertMaintenant,
              onChanged: (v) => setState(() => _ouvertMaintenant = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Urgences 24h/24'),
              value: _urgences24h,
              onChanged: (v) => setState(() => _urgences24h = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _secteur = null;
                        _ouvertMaintenant = false;
                        _urgences24h = false;
                      });
                    },
                    child: const Text('Réinitialiser'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        FiltresResultats(
                          secteur: _secteur,
                          ouvertMaintenant: _ouvertMaintenant ? true : null,
                          urgences24h: _urgences24h ? true : null,
                        ),
                      );
                    },
                    child: const Text('Appliquer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
