import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/specialites_rapides.dart';
import '../models/rendez_vous.dart';
import '../services/app_session.dart';
import '../services/local_cache_service.dart';
import '../services/scheduling_service.dart';
import 'mes_rendez_vous_screen.dart';
import 'resultats_screen.dart';

class _ProchainRdvInfo {
  final String praticienNom;
  final String etablissementNom;
  final DateTime debut;

  _ProchainRdvInfo({
    required this.praticienNom,
    required this.etablissementNom,
    required this.debut,
  });
}

/// P-01 Accueil — barre de recherche, raccourcis de spécialités,
/// raccourci "urgences et gardes", prochain rendez-vous à venir.
class AccueilScreen extends StatefulWidget {
  const AccueilScreen({super.key});

  @override
  State<AccueilScreen> createState() => _AccueilScreenState();
}

class _AccueilScreenState extends State<AccueilScreen> {
  final _rechercheController = TextEditingController();
  _ProchainRdvInfo? _prochainRdv;
  bool _chargementProchainRdv = false;

  @override
  void initState() {
    super.initState();
    _chargerProchainRdv();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    super.dispose();
  }

  /// Ne montre la carte "prochain rendez-vous" que lorsqu'un horaire
  /// est effectivement connu via le cache local d'enrichissement (voir
  /// LocalCacheService) — pas de date approximative inventée pour un
  /// rendez-vous dont l'heure n'est pas disponible côté API.
  Future<void> _chargerProchainRdv() async {
    final session = context.read<AppSession>();
    if (!session.estConnecte) return;

    setState(() => _chargementProchainRdv = true);
    try {
      final rdvs = await context.read<SchedulingService>().listerMesRendezVous();
      final cache = await context.read<LocalCacheService>().toutRecuperer();
      final maintenant = DateTime.now();

      _ProchainRdvInfo? meilleur;
      for (final rdv in rdvs) {
        if (rdv.statut != RendezVous.reserve &&
            rdv.statut != RendezVous.arrive &&
            rdv.statut != RendezVous.enConsultation) {
          continue;
        }
        final infos = cache[rdv.id];
        if (infos == null || !infos.debut.isAfter(maintenant)) continue;
        if (meilleur == null || infos.debut.isBefore(meilleur.debut)) {
          meilleur = _ProchainRdvInfo(
            praticienNom: infos.praticienNom,
            etablissementNom: infos.etablissementNom,
            debut: infos.debut,
          );
        }
      }
      if (mounted) setState(() => _prochainRdv = meilleur);
    } catch (_) {
      // Non bloquant : l'accueil reste utilisable sans cette carte.
    } finally {
      if (mounted) setState(() => _chargementProchainRdv = false);
    }
  }

  void _lancerRecherche() {
    final texte = _rechercheController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultatsScreen(
          rechercheInitiale: texte.isEmpty ? null : texte,
        ),
      ),
    );
  }

  void _ouvrirSpecialite(SpecialiteRapide specialite) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultatsScreen(
          specialiteInitiale: specialite.code,
          titre: specialite.libelle,
        ),
      ),
    );
  }

  void _ouvrirUrgences() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ResultatsScreen(
          urgences24hInitial: true,
          titre: 'Urgences et gardes',
        ),
      ),
    );
  }

  String _capitaliser(String texte) {
    if (texte.isEmpty) return texte;
    return texte[0].toUpperCase() + texte.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SantéGuinée')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Trouvez un établissement ou un praticien',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _rechercheController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nom, spécialité, quartier...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
              ),
              onSubmitted: (_) => _lancerRecherche(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _lancerRecherche,
                child: const Text('Rechercher'),
              ),
            ),
            const SizedBox(height: 24),
            if (_chargementProchainRdv)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
            if (_prochainRdv != null) _carteProchainRdv(_prochainRdv!),
            Text('Spécialités', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: specialitesRapides
                  .map((specialite) => _carteSpecialite(specialite))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: Icon(Icons.emergency, color: Colors.red.shade700),
                title: const Text('Urgences et gardes'),
                subtitle: const Text('Établissements ouverts 24h/24'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _ouvrirUrgences,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteSpecialite(SpecialiteRapide specialite) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _ouvrirSpecialite(specialite),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(specialite.icone, style: const TextStyle(fontSize: 22)),
            const SizedBox(height: 4),
            Text(
              specialite.libelle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _carteProchainRdv(_ProchainRdvInfo info) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          leading: Icon(
            Icons.event_available,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          title: Text(
            'Prochain rendez-vous : ${info.praticienNom}',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          subtitle: Text(
            '${info.etablissementNom} — '
            '${_capitaliser(DateFormat("EEEE d MMMM 'à' HH:mm", 'fr_FR').format(info.debut))}',
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
          ),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MesRendezVousScreen()),
          ),
        ),
      ),
    );
  }
}
