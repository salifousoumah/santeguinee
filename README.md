# SantéGuinée — Backend (MVP)

SantéGuinée est une plateforme de santé numérique pour la Guinée,
inspirée de Doctolib : annuaire des établissements et praticiens de
santé, puis prise de rendez-vous en ligne, et à terme un dossier
patient. Ce dépôt contient une **reconstruction de l'API backend**
(Django + DRF) à partir du cahier des charges fonctionnel, après la
perte du code d'une session précédente qui n'avait jamais initialisé
de dépôt git. Cette passe couvre uniquement le **backend** (modules
annuaire, comptes/authentification, prise de rendez-vous) ; l'application
mobile Flutter n'est pas reconstruite ici.

## Structure du dépôt

```
santeguinee/
├── backend/            # Projet Django (config) + apps directory, accounts, scheduling
│   ├── config/         # Settings, urls, wsgi/asgi
│   ├── common/         # BaseModel partagé (UUID, soft delete, timestamps)
│   ├── directory/      # Annuaire : établissements, praticiens, spécialités, zones...
│   ├── accounts/       # Comptes, authentification par téléphone/SMS, patients
│   ├── scheduling/     # Plages horaires, créneaux, rendez-vous, règles de gestion
│   └── requirements.txt
└── docker-compose.yml  # PostgreSQL optionnel pour un usage proche de la production
```

## Installation

Prérequis : Python 3.11.

```bash
cd backend
python3.11 -m venv venv
venv/bin/pip install -r requirements.txt

venv/bin/python manage.py migrate
venv/bin/python manage.py seed_demo      # données de démonstration FICTIVES
venv/bin/python manage.py runserver
```

L'API est alors disponible sur `http://127.0.0.1:8000/`. L'admin
Django (back-office, voir plus bas) est sur `/admin/` — créez un
compte avec :

```bash
venv/bin/python manage.py createsuperuser
```

### Port déjà utilisé par un autre projet

Si le port 8000 est déjà pris sur votre machine (un autre projet Django
qui tourne, par exemple), deux options :

```bash
# Ponctuel, n'importe quel port :
venv/bin/python manage.py runserver 8001

# Ou le script fourni, propre à ce projet, qui utilise 8001 par défaut
# (et écoute sur 0.0.0.0, utile pour tester depuis un téléphone sur le
# même réseau Wi-Fi — voir mobile/README.md) :
./run.sh          # -> http://127.0.0.1:8001/
./run.sh 8002      # pour un autre port ponctuellement
```

Si vous changez de port, pensez à le répercuter côté mobile (voir
`mobile/README.md`, variable `API_BASE_URL`).

(le `createsuperuser` demandera un numéro de téléphone, pas un
username : c'est l'identifiant de connexion de toute la plateforme.)

### Base de données

Par défaut, le projet utilise **SQLite** (fichier `backend/db.sqlite3`),
ce qui suffit largement pour le développement et les tests. Pour
utiliser PostgreSQL (`postgres:16`, fourni par `docker-compose.yml` à
la racine) :

```bash
docker compose up -d db
export DATABASE_URL=postgres://santeguinee:santeguinee@localhost:5432/santeguinee
cd backend && venv/bin/python manage.py migrate
```

`DATABASE_URL` non définie => SQLite (comportement par défaut).

## Lancer les tests

```bash
cd backend
venv/bin/python -m pytest -v
```

44 tests passent (pytest-django), couvrant notamment :
- RG-05 : génération des créneaux (fenêtre 14-90 jours, idempotence,
  exclusion des indisponibilités) ;
- RG-06 : verrouillage d'un créneau (5 min), expiration du verrou,
  impossibilité de double réservation (y compris au niveau base de
  données, via la contrainte `OneToOne` de `RendezVous.creneau`) ;
- RG-07 : maximum 3 rendez-vous futurs avec le même praticien, pas de
  chevauchement entre rendez-vous d'un même patient ;
- RG-08 : délai minimum d'1h avant réservation ;
- RG-09 : annulation gratuite jusqu'à 24h avant (drapeau de perte
  d'acompte au-delà) ;
- RG-11 : exigence d'acompte après 3 absences en 6 mois ;
- RG-12 : bascule automatique en "absent" ;
- RG-24 : un numéro de téléphone = un compte, maximum 10 "proches" par
  titulaire ;
- le flux de connexion par code SMS (expiration 5 min, 3 tentatives
  maximum, usage unique) ;
- la recherche dans l'annuaire (tolérance aux accents manquants, tri
  par distance Haversine, masquage des fiches non vérifiées) ;
- un **test d'intégration bout-en-bout** qui pilote l'API réelle (DRF
  `APIClient`) sur tout le parcours : demande de code SMS → vérification
  → création du profil patient → liste des créneaux → verrouillage →
  confirmation du rendez-vous → "mes rendez-vous" → annulation.

Ce même parcours a aussi été vérifié manuellement à la main contre le
serveur de développement réel (`manage.py runserver` + `curl`), pas
seulement via le client de test Django — voir le journal de
vérification dans l'historique de cette reconstruction si besoin.

## Données de démonstration

```bash
venv/bin/python manage.py seed_demo [--reset]
```

Crée des zones (Conakry et ses communes/quartiers), 8 spécialités, 8
établissements, 10 praticiens, leurs exercices, des plages horaires et
génère les créneaux correspondants sur 14 jours.

**Important (exigence de sécurité, pas une simple convention) :** tous
les noms d'établissements et de praticiens créés par cette commande
portent le suffixe `(Démo)`, pour qu'ils ne soient jamais confondus
avec des informations réelles sur de vrais hôpitaux ou praticiens de
Conakry. Toute nouvelle commande de seed doit conserver cette
convention.

## Back-office (module M3)

Pour cette passe MVP, le **Django admin** (`/admin/`) EST le
back-office : une personne non technique peut y consulter et vérifier
les établissements, praticiens et créneaux (recherche, filtres par
statut/type/secteur, actions "Marquer comme vérifié" /
"Marquer comme rejeté"). C'est une simplification volontaire, conforme
à l'approche déjà retenue par la session précédente et validée par le
cahier des charges pour le MVP.

## Aperçu de l'API

Toutes les routes sont préfixées par `/api/`. Authentification par
token DRF (`Authorization: Token <token>`), obtenu via le flux SMS.

### Annuaire (`/api/directory/`)
- `GET /etablissements/?q=&specialite=&zone=&secteur=&urgences_24h=&ouvert_maintenant=&lat=&lon=`
  — recherche d'établissements (uniquement ceux `statut_verification=verifie`).
- `GET /praticiens/?q=&specialite=&profession=` — recherche de praticiens.

### Comptes (`/api/accounts/`)
- `POST /auth/demande-code/` `{telephone}` — envoie un code SMS (loggé en console en dev).
- `POST /auth/verification-code/` `{telephone, code}` — vérifie le code, renvoie `{token, utilisateur}`.
- `GET/POST /patients/` — profil(s) patient de l'utilisateur connecté et de ses proches.
- `GET/POST /liens-proches/` — gestion des liens "proche" (RG-24, max 10).

### Prise de rendez-vous (`/api/scheduling/`)
- `GET /creneaux/?exercice=&statut=libre` — créneaux disponibles pour un exercice.
- `POST /creneaux/<uuid>/verrouiller/` — verrouille un créneau 5 min (RG-06).
- `POST /rendez-vous/confirmer/` `{patient_id, creneau_id, exercice_id, type_consultation_id?, motif?, canal?}`
  — confirme le rendez-vous (RG-06/07/08).
- `GET /rendez-vous/mes-rendez-vous/` — rendez-vous du patient connecté et de ses proches.
- `POST /rendez-vous/<uuid>/annuler/` `{motif?}` — annule (RG-09).
- `GET/POST /listes-attente/` — liste d'attente.

L'API DRF expose aussi une interface navigable (browsable API) sur
chaque endpoint lorsqu'on y accède depuis un navigateur, utile pour
explorer les champs attendus sans documentation OpenAPI formelle.

## Tester le parcours patient complet

`backend/test_parcours_patient.sh` rejoue tout le parcours (demande
de code SMS -> vérification -> création du profil -> recherche d'un
praticien avec des créneaux libres -> verrouillage -> réservation ->
"mes rendez-vous" -> annulation) contre un backend en cours
d'exécution, via `curl`/`jq`. Prérequis : `jq` (`sudo apt install jq`),
backend démarré (`./run.sh` ou `manage.py runserver`) et
`seed_demo` déjà exécuté.

```bash
cd backend
./test_parcours_patient.sh                 # cible http://127.0.0.1:8001/api par défaut
BASE_URL=http://127.0.0.1:8000/api ./test_parcours_patient.sh
```

Chaque appel est automatique sauf un : le script vous demande de
coller le code reçu par SMS, visible dans le terminal où tourne le
serveur (le code n'est jamais stocké en clair côté serveur, donc
impossible à récupérer autrement).

## Commandes de gestion

- `seed_demo [--reset]` — données de démonstration fictives.
- `generer_creneaux [--jours N] [--exercice <uuid>]` — génère les
  créneaux (RG-05) à partir des plages horaires existantes. À planifier
  régulièrement (ex. une fois par jour) pour faire glisser la fenêtre.
- `flip_noshows` — bascule en "absent" les rendez-vous non honorés
  30 min après leur début (RG-12). Prévu pour être exécuté
  périodiquement via une tâche planifiée du système
  d'exploitation — par exemple, en production :
  `*/10 * * * * cd /app/backend && venv/bin/python manage.py flip_noshows`.
  Aucun scheduler n'est configuré dans ce sandbox de développement.

## Simplifications volontaires par rapport au cahier des charges complet

Cette passe est un **MVP backend**, pas une implémentation complète du
cahier des charges. Simplifications assumées :

- **Pas de PostGIS/GeoDjango** : les coordonnées GPS sont de simples
  flottants (latitude/longitude) sur `Etablissement`, et la recherche
  géographique (tri par distance) utilise une formule de **Haversine**
  calculée en Python, plutôt qu'un vrai moteur géospatial. Choix fait
  pour rester portable sans dépendances système lourdes (GDAL, etc.)
  dans un environnement de développement contraint.
- **Pas de fournisseur SMS réel** : `accounts/sms.py::send_code`
  affiche le code dans la console/les logs (`SMS to +224XXXXXXXXX: code
  123456`) au lieu d'appeler un agrégateur SMS. Le point d'intégration
  futur est clairement indiqué dans le code.
- **Pas de paiement réel** (module M8) : les champs/drapeaux liés aux
  acomptes (`depot_requis`, `depot_perdu`, `paiement_id`) existent pour
  documenter l'intention (RG-09, RG-11) mais aucune intégration de
  paiement n'est branchée.
- **Pas de dossier médical patient** (section 6.4 / module M7 du
  cahier des charges) : explicitement phase 3, hors périmètre de cette
  passe.
- **Pas d'application Flutter** dans cette passe : l'API REST est
  documentée ci-dessus pour qu'un futur travail puisse la consommer
  sans redécouvrir son contour.
- **Recherche texte simplifiée** : tolérance aux accents manquants et
  aux légères variantes de terminaison (via normalisation Unicode +
  `difflib`), suffisante pour un volume de données MVP, mais ce n'est
  pas un moteur de recherche plein texte (pas d'Elasticsearch, etc.).
- **Back-office = Django admin** (module M3) : pas d'interface
  dédiée ; l'admin Django fait le travail pour cette taille d'équipe.
- **Pas de scheduler configuré** pour `flip_noshows` /
  `generer_creneaux` : ces commandes existent et sont testées, mais
  leur exécution périodique (cron, CronJob Kubernetes, etc.) reste à
  mettre en place en fonction de l'environnement de déploiement cible.

## Prochaines étapes

- Brancher un vrai agrégateur SMS (Orange Guinée, MTN, etc.) derrière
  `accounts/sms.py`, sans changer son interface.
- Intégrer un vrai moyen de paiement mobile money pour les acomptes
  (module M8).
- Construire le module dossier médical patient (module M7, phase 3).
- Reconstruire l'application mobile Flutter consommant cette API.
- Évaluer PostGIS/GeoDjango si le volume de données ou les besoins de
  recherche géographique avancée (polygones de zones, etc.) le
  justifient.
- Documentation OpenAPI formelle (ex. `drf-spectacular`) en plus de
  la browsable API de DRF.
- Mettre en place un scheduler (cron / Celery beat / CronJob) pour
  `generer_creneaux` et `flip_noshows` en environnement de production.

## Application mobile patient (Flutter)

Le code source de l'application mobile patient consommant cette API
vit dans `mobile/` (voir `mobile/README.md` pour l'installation, la
correspondance avec les écrans du cahier des charges, et les limites
connues de l'API qu'elle a fallu contourner côté client). Comme pour
ce backend lors de sa reconstruction, **Flutter n'était pas installé**
dans l'environnement qui a écrit ce code : il n'a donc jamais été
compilé, et `mobile/README.md` détaille précisément ce qui reste à
vérifier (`flutter create .`, `flutter pub get`, `flutter analyze`)
avant de pouvoir le lancer.
