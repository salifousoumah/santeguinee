"""Fixtures partagées entre les suites de tests pytest-django."""

import datetime

import pytest
from django.utils import timezone

from accounts.models import Patient, Utilisateur
from directory.models import Etablissement, Exercice, Praticien, Specialite, Zone
from scheduling.models import Creneau, TypeConsultation


@pytest.fixture
def zone_quartier(db):
    return Zone.objects.create(type=Zone.QUARTIER_DISTRICT, nom="Quartier Test")


@pytest.fixture
def specialite(db):
    return Specialite.objects.create(
        code="MED_GEN", libelle="Médecine générale", libelle_grand_public="médecin généraliste"
    )


@pytest.fixture
def etablissement(db, zone_quartier):
    return Etablissement.objects.create(
        nom="Clinique Test (Démo)",
        type=Etablissement.CLINIQUE,
        secteur=Etablissement.PRIVE,
        latitude=9.5370,
        longitude=-13.6785,
        quartier=zone_quartier,
        statut_verification=Etablissement.VERIFIE,
        verifie_le=timezone.now(),
    )


@pytest.fixture
def praticien(db, specialite):
    praticien = Praticien.objects.create(
        nom="Camara (Démo)",
        prenoms="Test",
        civilite="Dr",
        profession=Praticien.MEDECIN,
        statut_verification=Praticien.VERIFIE,
        verifie_le=timezone.now(),
    )
    praticien.specialites.add(specialite)
    return praticien


@pytest.fixture
def exercice(db, praticien, etablissement):
    return Exercice.objects.create(
        praticien=praticien, etablissement=etablissement, tarif_indicatif_gnf=50000
    )


@pytest.fixture
def type_consultation(db, exercice):
    return TypeConsultation.objects.create(
        exercice=exercice, libelle="Consultation standard", duree_min=30, tarif_gnf=50000
    )


@pytest.fixture
def utilisateur(db):
    return Utilisateur.objects.create_user(telephone="+224620000099")


@pytest.fixture
def patient(db, utilisateur):
    return Patient.objects.create(
        nom="Doumbouya", prenoms="Test", sexe=Patient.SEXE_FEMME, utilisateur=utilisateur
    )


def creer_creneau(exercice, debut_dans_heures=48, statut=Creneau.LIBRE):
    debut = timezone.now() + datetime.timedelta(hours=debut_dans_heures)
    debut = debut.replace(minute=0, second=0, microsecond=0)
    fin = debut + datetime.timedelta(minutes=30)
    return Creneau.objects.create(exercice=exercice, debut=debut, fin=fin, statut=statut)


@pytest.fixture
def creneau_futur(db, exercice):
    """Un créneau libre largement dans le futur (48h), pour éviter toute
    collision avec RG-08 (délai minimum 1h)."""
    return creer_creneau(exercice, debut_dans_heures=48)
