import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_session.dart';
import 'connexion_screen.dart';
import 'mes_proches_screen.dart';

/// Écran "Compte" (onglet de la navigation principale) : état de
/// connexion, accès à P-13 (Mes proches), déconnexion. Ne correspond
/// pas à un écran numéroté du cahier des charges — c'est la pièce de
/// navigation qui relie P-12 et P-13 au reste de l'app.
class CompteScreen extends StatelessWidget {
  const CompteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!session.estConnecte) ...[
              const SizedBox(height: 24),
              const Icon(Icons.account_circle, size: 72, color: Colors.grey),
              const SizedBox(height: 12),
              const Text(
                'Vous n\'êtes pas connecté.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConnexionScreen()),
                ),
                child: const Text('Se connecter'),
              ),
            ] else ...[
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(session.utilisateur!.telephone),
                  subtitle: session.patientPrincipal != null
                      ? Text(session.patientPrincipal!.nomComplet)
                      : const Text('Profil patient non créé'),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: const Text('Mes proches'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MesProchesScreen()),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.read<AppSession>().deconnexion(),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
