import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/creneau.dart';
import '../models/exercice.dart';
import '../models/patient.dart';
import '../services/api_client.dart';
import '../services/app_session.dart';
import '../services/local_cache_service.dart';
import '../services/scheduling_service.dart';
import 'rendez_vous_confirme_screen.dart';

/// P-08 Confirmation de réservation.
///
/// Déroulement conforme à RG-06 : verrouille d'abord le créneau
/// (`POST /creneaux/<id>/verrouiller/`, 5 minutes), puis confirme
/// (`POST /rendez-vous/confirmer/`). Si le verrou échoue (créneau pris
/// entre-temps par quelqu'un d'autre) ou si la confirmation échoue
/// ensuite (RG-07 quota/chevauchement, RG-08 délai minimum, ou le
/// verrou a expiré faute d'avoir confirmé à temps), le message
/// d'erreur renvoyé par l'API est affiché tel quel à l'utilisateur.
class ConfirmationReservationScreen extends StatefulWidget {
  const ConfirmationReservationScreen({
    super.key,
    required this.exercice,
    required this.creneau,
    required this.praticienNom,
    required this.etablissementNom,
  });

  final Exercice exercice;
  final Creneau creneau;
  final String praticienNom;
  final String etablissementNom;

  @override
  State<ConfirmationReservationScreen> createState() =>
      _ConfirmationReservationScreenState();
}

class _ConfirmationReservationScreenState
    extends State<ConfirmationReservationScreen> {
  final _motifController = TextEditingController();
  String? _patientIdChoisi;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _patientIdChoisi ??= context.read<AppSession>().patientPrincipal?.id;
  }

  Future<void> _confirmer() async {
    final patientId = _patientIdChoisi;
    if (patientId == null) {
      setState(() => _erreur = 'Veuillez choisir un patient.');
      return;
    }
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    final schedulingService = context.read<SchedulingService>();
    try {
      await schedulingService.verrouillerCreneau(widget.creneau.id);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _erreur = e.message;
          _enCours = false;
        });
      }
      return;
    }

    try {
      final rdv = await schedulingService.confirmerRendezVous(
        patientId: patientId,
        creneauId: widget.creneau.id,
        exerciceId: widget.exercice.id,
        motif: _motifController.text.trim(),
      );

      await context.read<LocalCacheService>().enregistrer(
            rdv.id,
            InfosRendezVousCache(
              debut: widget.creneau.debut,
              fin: widget.creneau.fin,
              praticienNom: widget.praticienNom,
              etablissementNom: widget.etablissementNom,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => RendezVousConfirmeScreen(
            rendezVous: rdv,
            praticienNom: widget.praticienNom,
            etablissementNom: widget.etablissementNom,
            debut: widget.creneau.debut,
          ),
        ),
      );
    } on ApiException catch (e) {
      setState(() {
        _erreur = e.message;
        _enCours = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();
    final patientsDisponibles = <Patient>[
      if (session.patientPrincipal != null) session.patientPrincipal!,
      ...session.proches,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Confirmer le rendez-vous')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.praticienNom,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(widget.etablissementNom,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        _capitaliser(
                          DateFormat("EEEE d MMMM yyyy 'à' HH:mm", 'fr_FR')
                              .format(widget.creneau.debut),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Pour qui est ce rendez-vous ?',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              if (patientsDisponibles.isEmpty)
                const Text('Aucun profil patient disponible.')
              else
                DropdownButtonFormField<String>(
                  value: _patientIdChoisi,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: patientsDisponibles
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.nomComplet),
                        ),
                      )
                      .toList(),
                  onChanged: (valeur) => setState(() => _patientIdChoisi = valeur),
                ),
              const SizedBox(height: 20),
              Text('Motif (optionnel)', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _motifController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Ex. consultation de suivi, douleur...',
                ),
              ),
              if (_erreur != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _erreur!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _enCours ? null : _confirmer,
                child: _enCours
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirmer le rendez-vous'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _capitaliser(String texte) {
    if (texte.isEmpty) return texte;
    return texte[0].toUpperCase() + texte.substring(1);
  }
}
