import 'package:flutter/material.dart';

/// État de chargement centré, réutilisé sur tous les écrans.
class ChargementCentre extends StatelessWidget {
  const ChargementCentre({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// État vide (liste vide) réutilisé sur tous les écrans de liste.
class EtatVide extends StatelessWidget {
  const EtatVide({
    super.key,
    required this.message,
    this.icone = Icons.search_off,
  });

  final String message;
  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// État d'erreur réseau/API, avec un bouton "Réessayer" optionnel.
class EtatErreur extends StatelessWidget {
  const EtatErreur({
    super.key,
    required this.message,
    this.onReessayer,
  });

  final String message;
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onReessayer != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onReessayer,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
