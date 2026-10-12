"""Tests de l'API de recherche de l'annuaire (module M1, US-01 à US-04)."""

import datetime

import pytest
from django.utils import timezone
from rest_framework.test import APIClient

from directory.models import Etablissement, Garde, Horaire, Service, Specialite, Zone
from directory.utils import est_ouvert_maintenant, haversine_km, normaliser_texte, texte_correspond

pytestmark = pytest.mark.django_db


class TestNormalisationTexte:
    def test_normaliser_texte_supprime_les_accents(self):
        assert normaliser_texte("Pédiatrie") == "pediatrie"

    def test_pediatre_correspond_a_pediatrie(self):
        assert texte_correspond("pediatre", "Pédiatrie") is True

    def test_texte_vide_correspond_toujours(self):
        assert texte_correspond("", "Pédiatrie") is True


class TestHaversine:
    def test_distance_nulle_pour_le_meme_point(self):
        assert haversine_km(9.5, -13.6, 9.5, -13.6) == pytest.approx(0, abs=1e-6)

    def test_distance_conakry_vers_kindia_environ_80km(self):
        # Conakry (~9.5370, -13.6785) -> Kindia (~10.0570, -12.8650), ~95km
        distance = haversine_km(9.5370, -13.6785, 10.0570, -12.8650)
        assert 80 < distance < 110


class TestOuvertMaintenant:
    def test_urgences_24h_toujours_ouvert(self, etablissement):
        etablissement.urgences_24h = True
        etablissement.save()
        assert est_ouvert_maintenant(etablissement) is True

    def test_garde_active_rend_ouvert(self, etablissement):
        maintenant = timezone.now()
        Garde.objects.create(
            etablissement=etablissement,
            debut=maintenant - datetime.timedelta(hours=1),
            fin=maintenant + datetime.timedelta(hours=1),
        )
        assert est_ouvert_maintenant(etablissement, maintenant) is True

    def test_horaire_recurrent_couvrant_l_instant(self, etablissement):
        maintenant = timezone.now().replace(hour=10, minute=0, second=0, microsecond=0)
        Horaire.objects.create(
            etablissement=etablissement,
            jour_semaine=maintenant.weekday(),
            heure_debut=datetime.time(8, 0),
            heure_fin=datetime.time(17, 0),
        )
        assert est_ouvert_maintenant(etablissement, maintenant) is True

    def test_hors_horaire_ferme(self, etablissement):
        maintenant = timezone.now().replace(hour=22, minute=0, second=0, microsecond=0)
        Horaire.objects.create(
            etablissement=etablissement,
            jour_semaine=maintenant.weekday(),
            heure_debut=datetime.time(8, 0),
            heure_fin=datetime.time(17, 0),
        )
        assert est_ouvert_maintenant(etablissement, maintenant) is False


class TestApiRecherche:
    def test_recherche_tolere_les_accents_manquants(self, etablissement):
        client = APIClient()
        specialite = Specialite.objects.create(code="PEDIATRIE", libelle="Pédiatrie")
        Service.objects.create(
            etablissement=etablissement, nom="Pédiatrie", specialite=specialite
        )

        reponse = client.get("/api/directory/etablissements/", {"q": "clinique"})
        assert reponse.status_code == 200
        noms = [e["nom"] for e in reponse.json()["results"]]
        assert etablissement.nom in noms

    def test_etablissement_non_verifie_est_masque(self, etablissement, zone_quartier):
        Etablissement.objects.create(
            nom="Clinique Non Vérifiée (Démo)",
            type=Etablissement.CLINIQUE,
            secteur=Etablissement.PRIVE,
            quartier=zone_quartier,
            statut_verification=Etablissement.EN_ATTENTE,
        )
        client = APIClient()
        reponse = client.get("/api/directory/etablissements/")
        noms = [e["nom"] for e in reponse.json()["results"]]
        assert "Clinique Non Vérifiée (Démo)" not in noms
        assert etablissement.nom in noms

    def test_filtre_secteur(self, etablissement):
        client = APIClient()
        reponse = client.get("/api/directory/etablissements/", {"secteur": "public"})
        noms = [e["nom"] for e in reponse.json()["results"]]
        assert etablissement.nom not in noms

    def test_tri_par_distance(self, etablissement, zone_quartier):
        lointain = Etablissement.objects.create(
            nom="Hôpital Lointain (Démo)",
            type=Etablissement.CLINIQUE,
            secteur=Etablissement.PRIVE,
            latitude=11.0,
            longitude=-14.5,
            quartier=zone_quartier,
            statut_verification=Etablissement.VERIFIE,
        )
        client = APIClient()
        reponse = client.get(
            "/api/directory/etablissements/",
            {"lat": etablissement.latitude, "lon": etablissement.longitude},
        )
        resultats = reponse.json()["results"]
        assert resultats[0]["nom"] == etablissement.nom
        assert resultats[0]["distance_km"] < resultats[-1]["distance_km"]
