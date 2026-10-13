import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/creneau.dart';
import '../models/exercice.dart';
import '../services/api_client.dart';
import '../services/scheduling_service.dart';
import '../widgets/etats.dart';
import 'confirmation_reservation_screen.dart';
import 'navigation_guard.dart';

/// P-07 Choix du créneau — créneaux libres d'un [Exercice], groupés
/// par jour. `GET /api/scheduling/creneaux/?exercice=<uuid>&statut=libre`.
class ChoixCreneauScreen extends StatefulWidget {
  const ChoixCreneauScreen({
    super.key,
    required this.exercice,
    required this.praticienNom,
    required this.etablissementNom,
  });

  final Exercice exercice;
  final String praticienNom;
  final String etablissementNom;

  @override
  State<ChoixCreneauScreen> createState() => _ChoixCreneauScreenState();
}

class _ChoixCreneauScreenState extends State<ChoixCreneauScreen> {
  bool _chargement = true;
  String? _erreur;
  List<Creneau> _creneaux = [];

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() {
      _chargement = true;
      _erreur = null;
    });
    try {
      final creneaux =
          await context.read<SchedulingService>().listerCreneauxLibres(widget.exercice.id);
      setState(() => _creneaux = creneaux);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _chargement = false);
    }
  }

  Future<void> _choisir(Creneau creneau) async {
    final autorise = await exigerConnexionEtProfil(context);
    if (!autorise || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmationReservationScreen(
          exercice: widget.exercice,
          creneau: creneau,
          praticienNom: widget.praticienNom,
          etablissementNom: widget.etablissementNom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choisir un créneau'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.praticienNom,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  widget.etablissementNom,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Expanded(child: _corps()),
        ],
      ),
    );
  }

  Widget _corps() {
    if (_chargement) return const ChargementCentre();
    if (_erreur != null) {
      return EtatErreur(message: _erreur!, onReessayer: _charger);
    }
    if (_creneaux.isEmpty) {
      return const EtatVide(
        message: 'Aucun créneau libre dans les prochains jours.',
        icone: Icons.event_busy,
      );
    }

    final parJour = <String, List<Creneau>>{};
    for (final creneau in _creneaux) {
      final cle = DateFormat('yyyy-MM-dd').format(creneau.debut);
      parJour.putIfAbsent(cle, () => []).add(creneau);
    }
    final cles = parJour.keys.toList()..sort();

    return RefreshIndicator(
      onRefresh: _charger,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: cles.length,
        itemBuilder: (context, index) {
          final cle = cles[index];
          final creneauxDuJour = parJour[cle]!;
          final libelleJour = _capitaliser(
            DateFormat('EEEE d MMMM', 'fr_FR').format(creneauxDuJour.first.debut),
          );
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelleJour, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: creneauxDuJour
                      .map(
                        (c) => OutlinedButton(
                          onPressed: () => _choisir(c),
                          child: Text(DateFormat('HH:mm').format(c.debut)),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _capitaliser(String texte) {
    if (texte.isEmpty) return texte;
    return texte[0].toUpperCase() + texte.substring(1);
  }
}
