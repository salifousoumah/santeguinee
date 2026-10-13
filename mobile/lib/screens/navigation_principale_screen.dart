import 'package:flutter/material.dart';

import 'accueil_screen.dart';
import 'compte_screen.dart';
import 'mes_rendez_vous_screen.dart';

/// Coquille de navigation principale (barre de navigation du bas) :
/// Accueil (P-01), Mes rendez-vous (P-11), Compte. Pas un écran
/// numéroté du cahier des charges en soi, juste l'assemblage des
/// écrans ci-dessus.
class NavigationPrincipaleScreen extends StatefulWidget {
  const NavigationPrincipaleScreen({super.key});

  @override
  State<NavigationPrincipaleScreen> createState() =>
      _NavigationPrincipaleScreenState();
}

class _NavigationPrincipaleScreenState extends State<NavigationPrincipaleScreen> {
  int _index = 0;

  static const _ecrans = [
    AccueilScreen(),
    MesRendezVousScreen(),
    CompteScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _ecrans),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (valeur) => setState(() => _index = valeur),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Accueil'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event), label: 'Mes RDV'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Compte'),
        ],
      ),
    );
  }
}
