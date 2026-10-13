import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../models/rendez_vous.dart';
import '../services/api_client.dart';
import '../services/app_session.dart';
import '../services/directory_service.dart';
import '../services/local_cache_service.dart';
import '../services/scheduling_service.dart';
import '../widgets/etats.dart';
import 'connexion_screen.dart';

/// Informations d'affichage résolues pour un [RendezVous] (voir
/// [LocalCacheService] pour la justification de cet enrichissement
/// côté client).
class _RdvAffichage {
  final RendezVous rdv;
  final String patientNom;
  final String praticienNom;
  final String etablissementNom;
  final DateTime? debut;

  _RdvAffichage({
    required this.rdv,
    required this.patientNom,
    required this.praticienNom,
    required this.etablissementNom,
    required this.debut,
  });
}

/// P-11 Mes rendez-vous — à venir / passés, avec action d'annulation.
/// `GET /api/scheduling/rendez-vous/mes-rendez-vous/` +
/// `POST /rendez-vous/<id>/annuler/`.
class MesRendezVousScreen extends StatefulWidget {
  const MesRendezVousScreen({super.key});

  @override
  State<MesRendezVousScreen> createState() => _MesRendezVousScreenState();
}

class _MesRendezVousScreenState extends State<MesRendezVousScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(length: 2, vsync: this);
  bool _chargement = true;
  String? _erreur;
  List<_RdvAffichage> _rendezVous = [];

  @override
  void initState() {
    super.initState();
    if (context.read<AppSession>().estConnecte) {
      _charger();
    } else {
      _chargement = false;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final session = context.read<AppSession>();
      final schedulingService = context.read<SchedulingService>();
      final directoryService = context.read<DirectoryService>();
      final cacheService = context.read<LocalCacheService>();

      final rendezVousBruts = await schedulingService.listerMesRendezVous();
      final praticiens = await directoryService.tousLesPraticiensVerifies();
      final cache = await cacheService.toutRecuperer();

      // exercice_id -> (nom praticien, nom établissement), construit à
      // partir des praticiens (seule source où `Exercice` apparaît,
      // voir DirectoryService.tousLesPraticiensVerifies).
      final exerciceVersNoms = <String, (String, String)>{};
      for (final praticien in praticiens) {
        for (final exercice in praticien.exercices) {
          exerciceVersNoms[exercice.id] =
              (praticien.nomAffiche, exercice.etablissementNom);
        }
      }

      final resultats = rendezVousBruts.map((rdv) {
        Patient? patient;
        for (final p in session.patients) {
          if (p.id == rdv.patient) {
            patient = p;
            break;
          }
        }
        final infosCache = cache[rdv.id];
        final infosExercice = exerciceVersNoms[rdv.exercice];
        return _RdvAffichage(
          rdv: rdv,
          patientNom: patient?.nomComplet ?? 'Patient',
          praticienNom: infosCache?.praticienNom ?? infosExercice?.$1 ?? 'Praticien',
          etablissementNom:
              infosCache?.etablissementNom ?? infosExercice?.$2 ?? 'Établissement',
          debut: infosCache?.debut,
        );
      }).toList();

      setState(() => _rendezVous = resultats);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _annuler(_RdvAffichage item) async {
    final motifController = TextEditingController();
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: TextField(
          controller: motifController,
          decoration: const InputDecoration(
            labelText: 'Motif (optionnel)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Annuler le rendez-vous'),
          ),
        ],
      ),
    );
    if (confirme != true) return;

    try {
      await context
          .read<SchedulingService>()
          .annulerRendezVous(item.rdv.id, motif: motifController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rendez-vous annulé.')),
      );
      _charger();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        bottom: session.estConnecte
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'À venir'),
                  Tab(text: 'Passés'),
                ],
              )
            : null,
      ),
      body: !session.estConnecte ? _invitationConnexion() : _corps(),
    );
  }

  Widget _invitationConnexion() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Connectez-vous pour voir vos rendez-vous.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final connecte = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const ConnexionScreen()),
                );
                if (connecte == true) _charger();
              },
              child: const Text('Se connecter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corps() {
    if (_chargement) return const ChargementCentre();
    if (_erreur != null) {
      return EtatErreur(message: _erreur!, onReessayer: _charger);
    }

    final maintenant = DateTime.now();
    final aVenir = _rendezVous.where((r) {
      if (r.rdv.estPasse) return false;
      if (r.debut == null) return true;
      return r.debut!.isAfter(maintenant);
    }).toList()
      ..sort((a, b) => (a.debut ?? DateTime(9999)).compareTo(b.debut ?? DateTime(9999)));

    final passes = _rendezVous.where((r) {
      if (r.rdv.estPasse) return true;
      if (r.debut == null) return false;
      return !r.debut!.isAfter(maintenant);
    }).toList()
      ..sort((a, b) => b.rdv.creeLe.compareTo(a.rdv.creeLe));

    return TabBarView(
      controller: _tabController,
      children: [
        _liste(aVenir, peutAnnuler: true),
        _liste(passes, peutAnnuler: false),
      ],
    );
  }

  Widget _liste(List<_RdvAffichage> items, {required bool peutAnnuler}) {
    if (items.isEmpty) {
      return const EtatVide(
        message: 'Aucun rendez-vous ici pour le moment.',
        icone: Icons.event_note,
      );
    }
    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        itemBuilder: (context, index) => _carte(items[index], peutAnnuler: peutAnnuler),
      ),
    );
  }

  Widget _carte(_RdvAffichage item, {required bool peutAnnuler}) {
    final rdv = item.rdv;
    final libelleDate = item.debut != null
        ? _capitaliser(
            DateFormat("EEEE d MMMM yyyy 'à' HH:mm", 'fr_FR').format(item.debut!),
          )
        : 'Horaire non disponible';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.praticienNom,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _badgeStatut(rdv.statut),
              ],
            ),
            Text(item.etablissementNom, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(libelleDate, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              'Patient : ${item.patientNom}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (rdv.motif.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Motif : ${rdv.motif}', style: Theme.of(context).textTheme.bodySmall),
            ],
            if (rdv.depotPerdu) ...[
              const SizedBox(height: 4),
              Text(
                'Acompte perdu (annulation tardive).',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
              ),
            ],
            if (peutAnnuler && rdv.statut == RendezVous.reserve) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _annuler(item),
                  child: const Text('Annuler'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _badgeStatut(String statut) {
    Color couleur;
    switch (statut) {
      case RendezVous.annule:
      case RendezVous.absent:
        couleur = Colors.red;
        break;
      case RendezVous.termine:
        couleur = Colors.grey;
        break;
      default:
        couleur = Colors.green;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: couleur.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        RendezVous.libelleStatut(statut),
        style: TextStyle(color: couleur, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _capitaliser(String texte) {
    if (texte.isEmpty) return texte;
    return texte[0].toUpperCase() + texte.substring(1);
  }
}
