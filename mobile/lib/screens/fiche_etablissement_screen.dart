import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/etablissement.dart';
import '../models/praticien.dart';
import '../services/api_client.dart';
import '../services/directory_service.dart';
import '../widgets/badges.dart';
import '../widgets/etats.dart';
import 'choix_creneau_screen.dart';
import 'fiche_praticien_screen.dart';
import 'navigation_guard.dart';

/// P-05 Fiche établissement.
///
/// Reçoit l'[Etablissement] déjà chargé depuis la liste de résultats
/// (P-02) plutôt que de le re-récupérer : il n'existe pas de
/// `GET /api/directory/etablissements/<id>/` côté backend (seule la
/// recherche liste existe — voir `backend/directory/urls.py`), et le
/// serializer de recherche n'inclut d'ailleurs ni services, ni
/// horaires, ni gardes en détail (champs non exposés). Cette fiche
/// affiche donc exactement — et seulement — ce que l'API renvoie
/// réellement : nom, type, secteur, repère, quartier, téléphones,
/// urgences 24h/24, moyens de paiement, statut de vérification. Les
/// photos sont omises (aucun upload de photo n'existe côté serveur).
class FicheEtablissementScreen extends StatefulWidget {
  const FicheEtablissementScreen({super.key, required this.etablissement});

  final Etablissement etablissement;

  @override
  State<FicheEtablissementScreen> createState() => _FicheEtablissementScreenState();
}

class _FicheEtablissementScreenState extends State<FicheEtablissementScreen> {
  bool _chargementPraticiens = true;
  String? _erreurPraticiens;
  List<Praticien> _praticiensIci = [];

  @override
  void initState() {
    super.initState();
    _chargerPraticiens();
  }

  /// Il n'existe pas de paramètre `etablissement` sur
  /// `GET /api/directory/praticiens/` : on récupère donc tous les
  /// praticiens vérifiés et on filtre côté client ceux qui ont un
  /// `Exercice` actif dans cet établissement. Volume de démonstration
  /// faible (une dizaine de praticiens) : acceptable pour ce MVP.
  Future<void> _chargerPraticiens() async {
    setState(() {
      _chargementPraticiens = true;
      _erreurPraticiens = null;
    });
    try {
      final tous = await context.read<DirectoryService>().tousLesPraticiensVerifies();
      setState(() {
        _praticiensIci = tous
            .where((p) => p.exercices.any(
                  (ex) => ex.actif && ex.etablissement == widget.etablissement.id,
                ))
            .toList();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erreurPraticiens = e.message);
    } finally {
      if (mounted) setState(() => _chargementPraticiens = false);
    }
  }

  Future<void> _appeler(String numero) async {
    final uri = Uri(scheme: 'tel', path: numero);
    final succes = await launchUrl(uri);
    if (!succes && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lancer l\'appel vers $numero.')),
      );
    }
  }

  Future<void> _reserver() async {
    if (_praticiensIci.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun praticien réservable en ligne n\'est actuellement '
            'rattaché à cet établissement.',
          ),
        ),
      );
      return;
    }
    final autorise = await exigerConnexionEtProfil(context);
    if (!autorise || !mounted) return;

    if (_praticiensIci.length == 1 && _praticiensIci.first.exercices.length == 1) {
      final praticien = _praticiensIci.first;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChoixCreneauScreen(
            exercice: praticien.exercices.first,
            praticienNom: praticien.nomAffiche,
            etablissementNom: widget.etablissement.nom,
          ),
        ),
      );
      return;
    }
    // Plusieurs praticiens ou plusieurs exercices possibles ici :
    // on laisse l'utilisateur choisir le praticien (puis l'exercice
    // précis sur sa fiche, P-06) plutôt que de deviner.
    _afficherChoixPraticien();
  }

  void _afficherChoixPraticien() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                'Choisir un praticien',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            for (final praticien in _praticiensIci)
              ListTile(
                title: Text(praticien.nomAffiche),
                subtitle: Text(Praticien.libelleProfession(praticien.profession)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FichePraticienScreen(praticien: praticien),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.etablissement;
    return Scaffold(
      appBar: AppBar(title: Text(e.nom)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (e.statutVerification == Etablissement.statutVerifie)
                const BadgeVerifie(),
              BadgeOuvert(ouvert: e.ouvertMaintenant),
              if (e.urgences24h) const BadgeUrgences(),
            ],
          ),
          const SizedBox(height: 16),
          _ligneInfo(
            Icons.local_hospital,
            '${Etablissement.libelleType(e.type)} · ${Etablissement.libelleSecteur(e.secteur)}',
          ),
          if (e.quartier != null) _ligneInfo(Icons.location_city, e.quartier!.nom),
          if (e.repere.isNotEmpty) _ligneInfo(Icons.place, e.repere),
          if (e.listeTelephones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Téléphone(s)', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            ...e.listeTelephones.map(
              (numero) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.call),
                title: Text(numero),
                onTap: () => _appeler(numero),
              ),
            ),
          ],
          if (e.listeMoyensPaiement.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Moyens de paiement', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: e.listeMoyensPaiement
                  .map((code) => Chip(label: Text(Etablissement.libelleMoyenPaiement(code))))
                  .toList(),
            ),
          ],
          const SizedBox(height: 20),
          Text('Praticiens sur place', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_chargementPraticiens)
            const Padding(
              padding: EdgeInsets.all(12),
              child: ChargementCentre(),
            )
          else if (_erreurPraticiens != null)
            EtatErreur(message: _erreurPraticiens!, onReessayer: _chargerPraticiens)
          else if (_praticiensIci.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Aucun praticien listé pour cet établissement.'),
            )
          else
            ..._praticiensIci.map(
              (p) => Card(
                child: ListTile(
                  title: Text(p.nomAffiche),
                  subtitle: Text(Praticien.libelleProfession(p.profession)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FichePraticienScreen(praticien: p),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _reserver,
            child: const Text('Réserver'),
          ),
        ),
      ),
    );
  }

  Widget _ligneInfo(IconData icone, String texte) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(child: Text(texte)),
        ],
      ),
    );
  }
}
