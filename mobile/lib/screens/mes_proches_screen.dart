import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/lien_proche.dart';
import '../models/patient.dart';
import '../services/api_client.dart';
import '../services/app_session.dart';
import '../services/patients_service.dart';
import '../widgets/etats.dart';

/// P-13 Mes proches — liste des `LienProche` (RG-24, max 10 par
/// titulaire) et formulaire d'ajout.
///
/// Ajouter un proche se fait en deux appels, conformément à l'API :
/// 1. `POST /api/accounts/patients/` crée le dossier patient minimal
///    du proche (il devient géré par le compte connecté, comme tout
///    patient créé par ce compte) ;
/// 2. `POST /api/accounts/liens-proches/` {titulaire, patient, lien}
///    formalise la relation. Le serveur refuse au-delà de 10 proches
///    et renvoie un message de validation affiché tel quel.
class MesProchesScreen extends StatefulWidget {
  const MesProchesScreen({super.key});

  @override
  State<MesProchesScreen> createState() => _MesProchesScreenState();
}

class _MesProchesScreenState extends State<MesProchesScreen> {
  Future<void> _ouvrirFormulaireAjout() async {
    final session = context.read<AppSession>();
    final titulaire = session.patientPrincipal;
    if (titulaire == null) return;

    final cree = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FormulaireAjoutProche(titulaireId: titulaire.id),
    );
    if (cree == true) {
      setState(() {});
    }
  }

  Future<void> _rafraichir() async {
    await context.read<AppSession>().rafraichirPatients();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    if (!session.estConnecte) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes proches')),
        body: const EtatVide(
          message: 'Connectez-vous pour gérer vos proches.',
          icone: Icons.lock_outline,
        ),
      );
    }

    final titulaire = session.patientPrincipal;
    if (titulaire == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mes proches')),
        body: const EtatVide(
          message: 'Créez d\'abord votre propre profil patient.',
          icone: Icons.person_add_alt,
        ),
      );
    }

    final proches = session.proches;
    final liensParPatientId = {for (final l in session.liens) l.patient: l};

    return Scaffold(
      appBar: AppBar(title: const Text('Mes proches')),
      body: RefreshIndicator(
        onRefresh: _rafraichir,
        child: proches.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  EtatVide(
                    message: 'Aucun proche enregistré pour le moment.',
                    icone: Icons.group_outlined,
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: proches.length,
                itemBuilder: (context, index) {
                  final proche = proches[index];
                  final lien = liensParPatientId[proche.id];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(proche.nomComplet),
                      subtitle: Text(
                        lien != null
                            ? LienProche.libelleLien(lien.lien)
                            : 'Proche',
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormulaireAjout,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un proche'),
      ),
    );
  }
}

class _FormulaireAjoutProche extends StatefulWidget {
  const _FormulaireAjoutProche({required this.titulaireId});

  final String titulaireId;

  @override
  State<_FormulaireAjoutProche> createState() => _FormulaireAjoutProcheState();
}

class _FormulaireAjoutProcheState extends State<_FormulaireAjoutProche> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _prenomsController = TextEditingController();
  String _sexe = Patient.sexeFemme;
  String _lien = LienProche.enfant;
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
      initialDate: DateTime(maintenant.year - 10),
      firstDate: DateTime(maintenant.year - 110),
      lastDate: maintenant,
      helpText: 'Date de naissance',
    );
    if (choisie != null) setState(() => _dateNaissance = choisie);
  }

  Future<void> _enregistrer() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final patientsService = context.read<PatientsService>();
      final proche = await patientsService.creerPatient(
        nom: _nomController.text.trim(),
        prenoms: _prenomsController.text.trim(),
        sexe: _sexe,
        dateNaissance: _dateNaissance == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_dateNaissance!),
      );
      await patientsService.creerLienProche(
        titulaire: widget.titulaireId,
        patient: proche.id,
        lien: _lien,
      );
      if (!mounted) return;
      await context.read<AppSession>().rafraichirPatients();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      // Inclut le message RG-24 ("un titulaire ne peut pas gérer plus
      // de 10 proches") renvoyé tel quel par le serveur.
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 4,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ajouter un proche', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
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
                    ButtonSegment(value: Patient.sexeFemme, label: Text('Femme')),
                    ButtonSegment(value: Patient.sexeHomme, label: Text('Homme')),
                  ],
                  selected: {_sexe},
                  onSelectionChanged: (s) => setState(() => _sexe = s.first),
                ),
                const SizedBox(height: 16),
                Text('Lien de parenté', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    LienProche.enfant,
                    LienProche.parent,
                    LienProche.conjoint,
                    LienProche.autre,
                  ].map((valeur) {
                    return ChoiceChip(
                      label: Text(LienProche.libelleLien(valeur)),
                      selected: _lien == valeur,
                      onSelected: (_) => setState(() => _lien = valeur),
                    );
                  }).toList(),
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
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _erreur!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _enCours ? null : _enregistrer,
                  child: _enCours
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Ajouter'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
