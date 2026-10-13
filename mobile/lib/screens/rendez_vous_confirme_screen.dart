import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/rendez_vous.dart';
import 'mes_rendez_vous_screen.dart';

/// P-10 Rendez-vous confirmé — simple écran de confirmation après une
/// réservation réussie (`POST /rendez-vous/confirmer/` → 201).
class RendezVousConfirmeScreen extends StatelessWidget {
  const RendezVousConfirmeScreen({
    super.key,
    required this.rendezVous,
    required this.praticienNom,
    required this.etablissementNom,
    required this.debut,
  });

  final RendezVous rendezVous;
  final String praticienNom;
  final String etablissementNom;
  final DateTime debut;

  String _capitaliser(String texte) {
    if (texte.isEmpty) return texte;
    return texte[0].toUpperCase() + texte.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 84,
              ),
              const SizedBox(height: 20),
              Text(
                'Rendez-vous confirmé',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(praticienNom,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(etablissementNom,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        _capitaliser(
                          DateFormat("EEEE d MMMM yyyy 'à' HH:mm", 'fr_FR').format(debut),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (rendezVous.depotRequis) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Un acompte est requis pour ce rendez-vous (suite à '
                          'des absences précédentes).',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MesRendezVousScreen()),
                  );
                },
                child: const Text('Voir mes rendez-vous'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
