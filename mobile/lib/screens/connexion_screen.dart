import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';
import '../services/app_session.dart';
import '../services/auth_service.dart';
import 'creer_profil_screen.dart';

/// P-12 Inscription/connexion — étape 1 (téléphone) et étape 2 (code
/// SMS à 6 chiffres), conformément au flux
/// `POST /auth/demande-code/` puis `POST /auth/verification-code/`.
///
/// Se termine en poussant [CreerProfilScreen] si l'utilisateur n'a
/// encore aucun profil patient (premier lancement), puis se dépile
/// avec `true` en cas de succès complet, ou `false`/`null` si
/// l'utilisateur a abandonné en route — à utiliser avec
/// `Navigator.push<bool>(...)`.
class ConnexionScreen extends StatefulWidget {
  const ConnexionScreen({super.key});

  @override
  State<ConnexionScreen> createState() => _ConnexionScreenState();
}

enum _EtapeConnexion { telephone, code }

class _ConnexionScreenState extends State<ConnexionScreen> {
  final _formKeyTelephone = GlobalKey<FormState>();
  final _formKeyCode = GlobalKey<FormState>();
  final _telephoneController = TextEditingController(text: '+224');
  final _codeController = TextEditingController();

  _EtapeConnexion _etape = _EtapeConnexion.telephone;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _telephoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  String get _telephone => _telephoneController.text.trim();

  Future<void> _demanderCode() async {
    if (!_formKeyTelephone.currentState!.validate()) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await context.read<AuthService>().demanderCode(_telephone);
      if (!mounted) return;
      setState(() {
        _etape = _EtapeConnexion.code;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  Future<void> _verifierCode() async {
    if (!_formKeyCode.currentState!.validate()) return;
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      final resultat = await context
          .read<AuthService>()
          .verifierCode(_telephone, _codeController.text.trim());
      if (!mounted) return;
      final session = context.read<AppSession>();
      await session.ouvrirSession(resultat.utilisateur, resultat.token);
      if (!mounted) return;

      var succesComplet = true;
      if (!session.possedeProfilPatient) {
        final resultatProfil = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const CreerProfilScreen()),
        );
        succesComplet = resultatProfil == true;
      }
      if (!mounted) return;
      Navigator.of(context).pop(succesComplet);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _erreur = e.message);
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connexion'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _etape == _EtapeConnexion.telephone
              ? _formulaireTelephone()
              : _formulaireCode(),
        ),
      ),
    );
  }

  Widget _formulaireTelephone() {
    return Form(
      key: _formKeyTelephone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entrez votre numéro de téléphone',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Un code à 6 chiffres vous sera envoyé par SMS pour '
            'confirmer votre identité.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _telephoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: '+224XXXXXXXXX',
              border: OutlineInputBorder(),
            ),
            validator: (valeur) {
              final v = valeur?.trim() ?? '';
              if (!RegExp(r'^\+?[0-9]{8,15}$').hasMatch(v)) {
                return 'Numéro invalide (ex. +224XXXXXXXXX).';
              }
              return null;
            },
          ),
          if (_erreur != null) _messageErreur(),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _enCours ? null : _demanderCode,
            child: _enCours
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Recevoir le code'),
          ),
        ],
      ),
    );
  }

  Widget _formulaireCode() {
    return Form(
      key: _formKeyCode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Entrez le code reçu par SMS',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text('Code envoyé au $_telephone.'),
          const SizedBox(height: 20),
          TextFormField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Code à 6 chiffres',
              border: OutlineInputBorder(),
            ),
            validator: (valeur) {
              final v = valeur?.trim() ?? '';
              if (v.length != 6 || int.tryParse(v) == null) {
                return 'Le code doit contenir 6 chiffres.';
              }
              return null;
            },
          ),
          if (_erreur != null) _messageErreur(),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _enCours ? null : _verifierCode,
            child: _enCours
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmer'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _enCours
                ? null
                : () => setState(() {
                      _etape = _EtapeConnexion.telephone;
                      _erreur = null;
                    }),
            child: const Text('Changer de numéro'),
          ),
        ],
      ),
    );
  }

  Widget _messageErreur() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        _erreur!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}
