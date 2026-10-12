"""Utilitaires pour la recherche dans l'annuaire : normalisation de
texte tolérante aux accents, distance Haversine, calcul d'ouverture.

Simplification volontaire (voir README) : pas de moteur de recherche
dédié (Elasticsearch, etc.) ni de PostGIS ; tout est fait en Python
pur, suffisant pour le volume de données d'un MVP.
"""

import math
import unicodedata
from datetime import datetime, timedelta

from django.utils import timezone


def normaliser_texte(texte):
    """Minuscule + suppression des accents, pour une comparaison tolérante.

    Ex : "pédiatrie" et "pediatre" se normalisent tous deux en une
    forme sans accent, ce qui permet un rapprochement simple par
    sous-chaîne ("pediatr" est un préfixe commun).
    """
    if not texte:
        return ""
    texte = texte.strip().lower()
    texte = unicodedata.normalize("NFKD", texte)
    return "".join(c for c in texte if not unicodedata.combining(c))


def texte_correspond(requete, *champs):
    """True si la requête normalisée apparaît dans au moins un des champs
    (eux aussi normalisés)."""
    requete_norm = normaliser_texte(requete)
    if not requete_norm:
        return True
    return any(requete_norm in normaliser_texte(champ) for champ in champs if champ)


EARTH_RADIUS_KM = 6371.0


def haversine_km(lat1, lon1, lat2, lon2):
    """Distance en kilomètres entre deux points GPS (formule de Haversine).

    Choix d'implémentation MVP : évite une dépendance PostGIS/GDAL en
    calculant la distance directement en Python. Suffisant pour trier
    un nombre raisonnable de résultats de recherche.
    """
    if None in (lat1, lon1, lat2, lon2):
        return None
    phi1, phi2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)
    a = (
        math.sin(dphi / 2) ** 2
        + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * math.asin(math.sqrt(a))


def est_ouvert_maintenant(etablissement, maintenant=None):
    """Détermine si un établissement est ouvert à l'instant `maintenant`
    (par défaut : maintenant, en heure de Conakry = UTC/GMT, cf. settings
    TIME_ZONE = "UTC").

    Règles :
    - urgences_24h=True => toujours ouvert.
    - Une Garde active couvrant l'instant => ouvert.
    - Sinon, on regarde les Horaire de l'établissement (ou de ses
      services) pour le jour courant, en tenant compte des horaires
      exceptionnels (fermeture/ouverture ponctuelle) qui priment sur le
      planning hebdomadaire récurrent.
    """
    if etablissement.urgences_24h:
        return True

    maintenant = maintenant or timezone.now()

    gardes_actives = etablissement.gardes.filter(debut__lte=maintenant, fin__gte=maintenant)
    if gardes_actives.exists():
        return True

    jour_semaine = maintenant.weekday()
    date_du_jour = maintenant.date()
    heure_actuelle = maintenant.time()

    horaires = etablissement.horaires.all()

    # Les horaires exceptionnels pour aujourd'hui priment sur le planning
    # récurrent (qu'ils représentent une fermeture ou une ouverture
    # spéciale, selon ce qui a été saisi).
    horaires_exceptionnels = [h for h in horaires if h.exceptionnel == date_du_jour]
    if horaires_exceptionnels:
        return any(h.heure_debut <= heure_actuelle <= h.heure_fin for h in horaires_exceptionnels)

    horaires_recurrents = [
        h for h in horaires if h.exceptionnel is None and h.jour_semaine == jour_semaine
    ]
    return any(h.heure_debut <= heure_actuelle <= h.heure_fin for h in horaires_recurrents)
