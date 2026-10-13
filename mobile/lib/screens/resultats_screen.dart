import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/etablissement.dart';
import '../models/praticien.dart';
import '../services/api_client.dart';
import '../services/directory_service.dart';
import '../widgets/etablissement_card.dart';
import '../widgets/etats.dart';
import '../widgets/praticien_card.dart';
import 'fiche_etablissement_screen.dart';
import 'fiche_praticien_screen.dart';
import 'filtres_sheet.dart';

/// P-02 Résultats (liste) — établissements et praticiens, avec une
/// recherche texte partagée et des filtres (P-04) appliqués à la
/// recherche d'établissements.
///
/// Note (voir mobile/README.md) : pas de tri par distance utilisable
/// ici en pratique — aucun plugin de géolocalisation n'est ajouté pour
/// ce MVP (dépendances volontairement minimales), donc `lat`/`lon` ne
/// sont jamais envoyés et `distance_km` reste toujours `null` côté
/// réponse. P-03 (carte) est entièrement différé, voir README.
class ResultatsScreen extends StatefulWidget {
  const ResultatsScreen({
    super.key,
    this.rechercheInitiale,
    this.specialiteInitiale,
    this.urgences24hInitial,
    this.titre = 'Résultats',
  });

  final String? rechercheInitiale;
  final String? specialiteInitiale;
  final bool? urgences24hInitial;
  final String titre;

  @override
  State<ResultatsScreen> createState() => _ResultatsScreenState();
}

class _ResultatsScreenState extends State<ResultatsScreen>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _rechercheController =
      TextEditingController(text: widget.rechercheInitiale ?? '');
  late TabController _tabController;
  late FiltresResultats _filtres;

  bool _chargementEtab = false;
  String? _erreurEtab;
  List<Etablissement> _etablissements = [];
  String? _urlSuivanteEtab;

  bool _chargementPrat = false;
  String? _erreurPrat;
  List<Praticien> _praticiens = [];
  String? _urlSuivantePrat;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filtres = FiltresResultats(urgences24h: widget.urgences24hInitial);
    _rechercherEtablissements();
    _rechercherPraticiens();
  }

  @override
  void dispose() {
    _rechercheController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  String? get _q =>
      _rechercheController.text.trim().isEmpty ? null : _rechercheController.text.trim();

  Future<void> _rechercherEtablissements() async {
    setState(() {
      _chargementEtab = true;
      _erreurEtab = null;
    });
    try {
      final page = await context.read<DirectoryService>().rechercherEtablissements(
            q: _q,
            specialite: widget.specialiteInitiale,
            secteur: _filtres.secteur,
            ouvertMaintenant: _filtres.ouvertMaintenant,
            urgences24h: _filtres.urgences24h,
          );
      setState(() {
        _etablissements = page.results;
        _urlSuivanteEtab = page.next;
      });
    } on ApiException catch (e) {
      setState(() => _erreurEtab = e.message);
    } finally {
      if (mounted) setState(() => _chargementEtab = false);
    }
  }

  Future<void> _chargerPlusEtablissements() async {
    if (_urlSuivanteEtab == null) return;
    setState(() => _chargementEtab = true);
    try {
      final page = await context
          .read<DirectoryService>()
          .pageSuivanteEtablissements(_urlSuivanteEtab!);
      setState(() {
        _etablissements = [..._etablissements, ...page.results];
        _urlSuivanteEtab = page.next;
      });
    } on ApiException catch (e) {
      setState(() => _erreurEtab = e.message);
    } finally {
      if (mounted) setState(() => _chargementEtab = false);
    }
  }

  Future<void> _rechercherPraticiens() async {
    setState(() {
      _chargementPrat = true;
      _erreurPrat = null;
    });
    try {
      final page = await context.read<DirectoryService>().rechercherPraticiens(
            q: _q,
            specialite: widget.specialiteInitiale,
          );
      setState(() {
        _praticiens = page.results;
        _urlSuivantePrat = page.next;
      });
    } on ApiException catch (e) {
      setState(() => _erreurPrat = e.message);
    } finally {
      if (mounted) setState(() => _chargementPrat = false);
    }
  }

  Future<void> _chargerPlusPraticiens() async {
    if (_urlSuivantePrat == null) return;
    setState(() => _chargementPrat = true);
    try {
      final page = await context
          .read<DirectoryService>()
          .pageSuivantePraticiens(_urlSuivantePrat!);
      setState(() {
        _praticiens = [..._praticiens, ...page.results];
        _urlSuivantePrat = page.next;
      });
    } on ApiException catch (e) {
      setState(() => _erreurPrat = e.message);
    } finally {
      if (mounted) setState(() => _chargementPrat = false);
    }
  }

  void _relancerRecherche() {
    _rechercherEtablissements();
    _rechercherPraticiens();
  }

  Future<void> _ouvrirFiltres() async {
    final resultat = await afficherFiltresSheet(context, _filtres);
    if (resultat != null) {
      setState(() => _filtres = resultat);
      _rechercherEtablissements();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titre),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Établissements'),
            Tab(text: 'Praticiens'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _rechercheController,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Rechercher (nom, spécialité...)',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _relancerRecherche(),
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: !_filtres.estVide,
                  child: IconButton.filledTonal(
                    onPressed: _ouvrirFiltres,
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filtres',
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _listeEtablissements(),
                _listePraticiens(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _listeEtablissements() {
    if (_chargementEtab && _etablissements.isEmpty) {
      return const ChargementCentre();
    }
    if (_erreurEtab != null && _etablissements.isEmpty) {
      return EtatErreur(message: _erreurEtab!, onReessayer: _rechercherEtablissements);
    }
    if (_etablissements.isEmpty) {
      return const EtatVide(message: 'Aucun établissement trouvé.');
    }
    return RefreshIndicator(
      onRefresh: _rechercherEtablissements,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: _etablissements.length + (_urlSuivanteEtab != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _etablissements.length) {
            return _boutonChargerPlus(_chargementEtab, _chargerPlusEtablissements);
          }
          final etablissement = _etablissements[index];
          return EtablissementCard(
            etablissement: etablissement,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FicheEtablissementScreen(etablissement: etablissement),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _listePraticiens() {
    if (_chargementPrat && _praticiens.isEmpty) {
      return const ChargementCentre();
    }
    if (_erreurPrat != null && _praticiens.isEmpty) {
      return EtatErreur(message: _erreurPrat!, onReessayer: _rechercherPraticiens);
    }
    if (_praticiens.isEmpty) {
      return const EtatVide(message: 'Aucun praticien trouvé.');
    }
    return RefreshIndicator(
      onRefresh: _rechercherPraticiens,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: _praticiens.length + (_urlSuivantePrat != null ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _praticiens.length) {
            return _boutonChargerPlus(_chargementPrat, _chargerPlusPraticiens);
          }
          final praticien = _praticiens[index];
          return PraticienCard(
            praticien: praticien,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FichePraticienScreen(praticien: praticien),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _boutonChargerPlus(bool chargement, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: chargement
            ? const CircularProgressIndicator()
            : OutlinedButton(onPressed: onPressed, child: const Text('Charger plus')),
      ),
    );
  }
}
