import 'package:flutter/material.dart';

import '../models/etablissement.dart';
import 'badges.dart';

/// Carte de résultat pour un établissement (P-02 Résultats).
class EtablissementCard extends StatelessWidget {
  const EtablissementCard({
    super.key,
    required this.etablissement,
    required this.onTap,
  });

  final Etablissement etablissement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final e = etablissement;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      e.nom,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (e.distanceKm != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${e.distanceKm!.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${Etablissement.libelleType(e.type)} · ${Etablissement.libelleSecteur(e.secteur)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (e.quartier != null) ...[
                const SizedBox(height: 2),
                Text(
                  e.quartier!.nom,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (e.statutVerification == Etablissement.statutVerifie)
                    const BadgeVerifie(),
                  BadgeOuvert(ouvert: e.ouvertMaintenant),
                  if (e.urgences24h) const BadgeUrgences(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
