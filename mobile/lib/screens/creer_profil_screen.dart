import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/patient.dart';
import '../services/api_client.dart';
import '../services/app_session.dart';
import '../services/patients_service.dart';

/// P-12 (suite) — formulaire de création du profil patient du
/// titulaire du compte, affiché après une première connexion réussie
/// si aucun profil patient n'existe encore.
///
/// `POST /api/accounts/patients/` {nom, prenoms, sexe, date_naissance?}.
/// Se dépile avec `true` en cas de succès.
class CreerProfilScreen extends StatefulWidget {
  const CreerProfilScreen({super.key});

  @override
  State<CreerProfilScreen> createState() => _CreerProfilScreenState();
}

class _CreerProfilScreenState extends State<CreerProfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomsController = TextEditingController();
  String _sexe = Patient.sexeFemme;
  DateTime? _dateNaissance;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _nomController.dispose();
    _prenomsController.dispose();
    super.dispose();
  }

  Future<void> _choisirDateNaissance() async {
    final maintenant = DateTime.now();
    final choisie = await showDatePicker(
      context: context,
      initialDate: DateTime(maintenant.year - 30),
      firstDate: DateTime(maintenant.year - 110),
      lastDate: maintenant,
      helpText: 'Date de naissance',
    );
    if (choisie != null) {
      setState(() => _dateNaissance = choisie);
    }
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await context.read<PatientsService>().creerPatient(
            nom: _nomController.text.trim(),
            prenoms: _prenomsController.text.trim(),
            sexe: _sexe,
            dateNaissance: _dateNaissance == null
                ? null
                : DateFormat('yyyy-MM-dd').format(_dateNaissance!),
          );
      if (!mounted) return;
      await context.read<AppSession>().rafraichirPatients();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Votre profil patient')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ces informations permettent de créer votre dossier '
                  'patient minimal (identité), nécessaire pour réserver '
                  'un rendez-vous.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _nomController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _prenomsController,
                  decoration: const InputDecoration(
                    labelText: 'Prénoms',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Champ requis.' : null,
                ),
                const SizedBox(height: 16),
                Text('Sexe', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: Patient.sexeFemme,
                      label: Text('Femme'),
                    ),
                    ButtonSegment(
                      value: Patient.sexeHomme,
                      label: Text('Homme'),
                    ),
                  ],
                  selected: {_sexe},
                  onSelectionChanged: (selection) {
                    setState(() => _sexe = selection.first);
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _choisirDateNaissance,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _dateNaissance == null
                        ? 'Date de naissance (optionnel)'
                        : DateFormat('dd/MM/yyyy').format(_dateNaissance!),
                  ),
                ),
                if (_erreur != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _erreur!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _enCours ? null : _enregistrer,
                  child: _enCours
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Créer mon profil'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
