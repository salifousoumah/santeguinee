import 'package:flutter/material.dart';

import '../models/praticien.dart';
import 'badges.dart';

/// Carte de résultat pour un praticien (P-02 Résultats).
class PraticienCard extends StatelessWidget {
  const PraticienCard({
    super.key,
    required this.praticien,
    required this.onTap,
  });

  final Praticien praticien;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = praticien;
    final lieux = p.exercices
        .where((ex) => ex.actif)
        .map((ex) => ex.etablissementNom)
        .where((nom) => nom.isNotEmpty)
        .toSet()
        .join(' · ');

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
              Text(
                p.nomAffiche,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                Praticien.libelleProfession(p.profession),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (p.specialites.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  p.specialites.map((s) => s.libelleAffiche).join(', '),
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (lieux.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  lieux,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              if (p.statutVerification == Praticien.statutVerifie)
                const BadgeVerifie(),
            ],
          ),
        ),
      ),
    );
  }
}
