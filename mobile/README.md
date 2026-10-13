# SantéGuinée — Application mobile patient (MVP)

Application Flutter consommant l'API backend Django/DRF du dépôt
(voir `../backend/README.md` pour l'API elle-même). Cette passe
reconstruit uniquement le **code source Dart** (`lib/`) — comme pour
le backend, une session précédente avait écrit du code Flutter sans
jamais l'avoir compilé, et ce code a été perdu avant d'être versionné.

**Important, à lire avant toute autre chose : Flutter n'est pas
installé dans l'environnement qui a écrit ce code.** Le code ci-dessous
a été relu attentivement (syntaxe, imports, noms de champs vérifiés un
par un contre les serializers Django réels — voir plus bas), mais il
n'a **jamais été exécuté ni même analysé par `flutter analyze`**. La
première chose qu'un développeur disposant de Flutter doit faire est
de lancer l'étape d'installation ci-dessous et de corriger ce qui ne
compile pas.

## Installation (étape unique, à faire une fois)

Prérequis : **Flutter 3.27 ou supérieur** (Dart ≥ 3.5, inclus avec
Flutter 3.27+).

```bash
cd mobile

# Génère android/, ios/, (web/, etc. si besoin) SANS écraser lib/ ni
# pubspec.yaml, qui existent déjà dans ce dépôt. C'est l'étape que la
# session précédente n'avait jamais pu faire (Flutter absent de son
# environnement aussi).
flutter create .

flutter pub get

# Vérifie qu'il n'y a pas d'erreur de compilation/lint avant de lancer
# l'app pour la première fois :
flutter analyze
```

`mobile/.gitignore` exclut déjà `android/`, `ios/`, `web/`, etc. : ils
resteront non versionnés après `flutter create .`, ce qui est voulu.

## Lancer l'app contre le backend

Le backend doit tourner (voir `../backend/README.md`) :

```bash
cd backend
venv/bin/python manage.py runserver
```

### Émulateur Android (cas le plus courant)

Aucune configuration nécessaire : l'URL par défaut
(`lib/config/api_config.dart`) est `http://10.0.2.2:8000`, l'alias
spécial qui permet à un **émulateur** Android de joindre le
**serveur tournant sur la machine hôte**. `127.0.0.1` ou `localhost`
dans l'émulateur pointeraient vers l'émulateur lui-même, pas vers
votre machine — c'est l'erreur classique à ce stade.

```bash
cd mobile
flutter run
```

### Simulateur iOS

Le simulateur iOS partage le réseau de l'hôte ; `10.0.2.2` n'existe
pas pour lui :

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

### Appareil physique (Android ou iOS) sur le même Wi-Fi

Démarrez le backend en écoutant sur toutes les interfaces, pas
seulement `127.0.0.1` :

```bash
venv/bin/python manage.py runserver 0.0.0.0:8000
```

Puis, avec l'adresse IP locale de la machine qui exécute le backend
(ex. `192.168.1.42`) :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.42:8000
```

### Backend déployé ailleurs

```bash
flutter run --dart-define=API_BASE_URL=https://votre-domaine.example
```

## Architecture

```
lib/
  main.dart                      Point d'entrée, providers, thème.
  config/
    api_config.dart              URL de base (voir ci-dessus).
    specialites_rapides.dart     Raccourcis de spécialités de l'accueil
                                  (codés en dur, voir « Limites connues »).
  models/                        Classes Dart + fromJson, un fichier par
                                  modèle backend (Utilisateur, Patient,
                                  LienProche, Zone, Specialite,
                                  Etablissement, Exercice, Praticien,
                                  Creneau, RendezVous) + PaginatedResponse.
  services/
    api_client.dart              Wrapper http, jeton (shared_preferences),
                                  extraction des messages d'erreur DRF.
    auth_service.dart            Flux de connexion par code SMS (M2).
    directory_service.dart       Recherche annuaire (M1).
    patients_service.dart        Patients + liens-proches (RG-24).
    scheduling_service.dart      Créneaux, verrouillage, confirmation,
                                  mes-rendez-vous, annulation (M4/M5).
    local_cache_service.dart     Cache local d'enrichissement d'affichage
                                  (voir « Limites connues »).
    app_session.dart             État de session global (ChangeNotifier).
  screens/                       Un écran par P-xx du cahier des charges
                                  (voir correspondance ci-dessous),
                                  plus quelques écrans de navigation/glue
                                  qui ne portent pas de numéro P-xx.
  widgets/                       Widgets partagés (cartes de résultat,
                                  badges, états vide/erreur/chargement).
```

### État / gestion d'état

Choix unique et cohérent pour tout le projet : **`provider`**
(`ChangeNotifierProvider` pour `AppSession`, `Provider` pour les
services sans état mutable). Pas de Riverpod, pas de Bloc.

### Réseau

**`http`** (pas `dio`) via `ApiClient` (`lib/services/api_client.dart`),
qui centralise : l'URL de base, l'en-tête
`Authorization: Token <token>`, la persistance du jeton, et la
transformation des réponses d'erreur DRF (`{"detail": "..."}` ou
`{"champ": ["message"]}`) en un message français prêt à afficher.

## Correspondance écrans ↔ cahier des charges

| ID    | Écran                        | Fichier                                      |
|-------|-------------------------------|-----------------------------------------------|
| P-01  | Accueil                       | `screens/accueil_screen.dart`                |
| P-02  | Résultats (liste)             | `screens/resultats_screen.dart`              |
| P-04  | Filtres                       | `screens/filtres_sheet.dart`                 |
| P-05  | Fiche établissement           | `screens/fiche_etablissement_screen.dart`    |
| P-06  | Fiche praticien               | `screens/fiche_praticien_screen.dart`        |
| P-07  | Choix du créneau              | `screens/choix_creneau_screen.dart`          |
| P-08  | Confirmation de réservation   | `screens/confirmation_reservation_screen.dart` |
| P-10  | Rendez-vous confirmé          | `screens/rendez_vous_confirme_screen.dart`   |
| P-11  | Mes rendez-vous               | `screens/mes_rendez_vous_screen.dart`        |
| P-12  | Inscription/connexion         | `screens/connexion_screen.dart` + `screens/creer_profil_screen.dart` |
| P-13  | Mes proches                   | `screens/mes_proches_screen.dart`            |
| —     | Coquille de navigation (bas)  | `screens/navigation_principale_screen.dart`  |
| —     | Onglet « Compte » (login/logout, lien vers P-13) | `screens/compte_screen.dart` |
| —     | Garde de connexion/profil avant réservation | `screens/navigation_guard.dart` |

**P-03 (carte) est volontairement absent de cette passe**, de la même
façon que le backend n'implémente pas PostGIS/GeoDjango (voir
`../backend/README.md`, « Simplifications volontaires »). Aucun plugin
de géolocalisation ou de carte n'a été ajouté ; `lat`/`lon` ne sont
jamais envoyés à la recherche, et `distance_km` reste donc toujours
`null` dans les réponses affichées par cette app.

## Limites connues de l'API (et comment l'app les contourne)

Ces points ont été identifiés en lisant le code backend réel
(`backend/*/models.py`, `serializers.py`, `views.py`, `urls.py`), pas
supposés :

- **Pas d'endpoint de détail** pour les établissements et les
  praticiens (`GET /etablissements/<id>/`, `GET /praticiens/<id>/`
  n'existent pas — seules les listes de recherche existent). Les
  fiches P-05/P-06 réutilisent donc l'objet déjà reçu depuis la liste
  de résultats (P-02) ou l'écran appelant, transmis en argument de
  navigation, plutôt que de le re-récupérer.
- **Pas d'endpoint `/specialites/`** : la liste des spécialités
  n'apparaît que imbriquée dans les résultats de recherche de
  praticiens. Les raccourcis de spécialités de l'accueil
  (`config/specialites_rapides.dart`) sont donc une liste codée en
  dur, qui reproduit exactement les 8 codes créés par
  `backend/directory/management/commands/seed_demo.py`. Une vraie
  liste dynamique nécessiterait un nouvel endpoint côté API.
- **Pas de paramètre `etablissement`** sur
  `GET /api/directory/praticiens/` : pour afficher les praticiens
  d'un établissement (P-05), l'app récupère tous les praticiens
  vérifiés (en suivant la pagination) et filtre côté client ceux
  ayant un `Exercice` actif dans cet établissement
  (`DirectoryService.tousLesPraticiensVerifies`). Acceptable au
  volume de données de démonstration ; à revoir si le catalogue
  grossit beaucoup.
- **Pas d'endpoint listant les `TypeConsultation`** d'un exercice :
  le champ `type_consultation_id` de
  `POST /rendez-vous/confirmer/` est donc toujours omis par l'app
  (il est optionnel côté serializer), et aucun sélecteur de type de
  consultation n'est proposé à l'écran P-08.
- **`RendezVousSerializer` ne renvoie que des identifiants**
  (`patient`, `creneau`, `exercice`, `type_consultation`), jamais les
  objets imbriqués — et il n'existe pas non plus de
  `GET /creneaux/<id>/` de détail. Sans heure de créneau ni nom de
  praticien renvoyés par l'API, l'écran P-11 ne pourrait rien afficher
  d'utile. `services/local_cache_service.dart` retient donc, UNIQUEMENT
  CÔTÉ CLIENT, l'horaire et les noms praticien/établissement au moment
  de la réservation (P-08/P-10). Ce cache ne couvre que les
  rendez-vous pris depuis cet appareil ; un rendez-vous pris par
  téléphone, ou rechargé après une réinstallation de l'app, s'affiche
  avec « Horaire non disponible » plutôt que de planter ou d'inventer
  une donnée. La vraie solution serait d'enrichir
  `RendezVousSerializer` côté backend.
- **Pas d'endpoint « qui suis-je »** (`/me/`) : l'objet `Utilisateur`
  n'est renvoyé qu'une fois, par `POST /auth/verification-code/`.
  `AppSession` le persiste donc lui-même en local
  (`shared_preferences`) pour survivre à un redémarrage de l'app sans
  forcer une reconnexion.
- **Distinction « soi-même » vs « proche »** : le modèle `Patient` ne
  porte aucun indicateur explicite ; l'app déduit le profil
  « titulaire » comme celui qui n'apparaît comme cible (`patient`)
  d'aucun `LienProche` du compte connecté (voir
  `AppSession.patientPrincipal`).

## Ce qui est délibérément hors périmètre de cette passe

- **Carte / géolocalisation (P-03)** — voir plus haut.
- **Dossier médical patient** — hors périmètre backend aussi (module
  M7, phase 3 du cahier des charges).
- **Paiement / acompte réel** — les drapeaux `depot_requis`/
  `depot_perdu` renvoyés par l'API sont affichés à titre informatif
  (P-10/P-11), mais aucune intégration de paiement mobile money n'est
  branchée (ni côté backend).
- **Notifications push** — aucun SDK de notification n'est intégré.
- **Synchronisation hors-ligne** — l'app part du principe d'une
  connectivité disponible ; il n'y a pas de file d'actions en attente
  ni de cache de données pour fonctionner hors-ligne (seul le petit
  cache d'enrichissement d'affichage mentionné plus haut existe).
- **Tests automatisés Flutter** (widget/golden tests) — non écrits
  dans cette passe, faute de pouvoir les exécuter sans Flutter
  installé ; voir la section suivante.

## Ce qui n'a pas pu être vérifié (honnêteté sur l'état du code)

Flutter n'étant pas installé dans l'environnement qui a écrit ce
code :

- **Rien n'a été compilé.** `flutter pub get`, `flutter analyze` et
  `flutter run`/`flutter build` n'ont jamais été exécutés.
- Une relecture manuelle systématique a été faite : équilibre des
  accolades/parenthèses sur chaque fichier, résolution de tous les
  imports relatifs vers des fichiers existants, et surtout
  **comparaison champ par champ de chaque modèle Dart avec le
  serializer Django correspondant** (voir commentaires en tête de
  chaque fichier dans `lib/models/`).
- `pubspec.yaml` et `analysis_options.yaml` ont été validés comme YAML
  syntaxiquement correct (`yaml.safe_load` en Python), mais ceci ne
  garantit pas que les versions de paquets demandées résolvent sans
  conflit — seul `flutter pub get` peut le confirmer.
- Il est tout à fait possible qu'il reste des erreurs de compilation
  (signature d'API Flutter légèrement différente de ce qui est
  attendu, etc.) : la première exécution de `flutter analyze` après
  `flutter create .` doit être traitée comme faisant partie du travail
  restant, pas comme une simple formalité.
