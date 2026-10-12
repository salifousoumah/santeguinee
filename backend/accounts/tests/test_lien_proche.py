"""Tests de RG-24 : un numéro = un compte, max 10 proches par titulaire."""

import pytest
from django.core.exceptions import ValidationError

from accounts.models import LienProche, Patient, Utilisateur

pytestmark = pytest.mark.django_db


@pytest.fixture
def titulaire(utilisateur):
    return Patient.objects.create(
        nom="Titulaire", prenoms="Test", sexe=Patient.SEXE_FEMME, utilisateur=utilisateur
    )


class TestMaxProches:
    def test_dix_proches_autorises(self, titulaire):
        for i in range(10):
            proche = Patient.objects.create(
                nom=f"Proche{i}", prenoms="Test", sexe=Patient.SEXE_HOMME
            )
            LienProche.objects.create(titulaire=titulaire, patient=proche, lien=LienProche.ENFANT)

        assert LienProche.objects.filter(titulaire=titulaire).count() == 10

    def test_onzieme_proche_refuse(self, titulaire):
        for i in range(10):
            proche = Patient.objects.create(
                nom=f"Proche{i}", prenoms="Test", sexe=Patient.SEXE_HOMME
            )
            LienProche.objects.create(titulaire=titulaire, patient=proche, lien=LienProche.ENFANT)

        onzieme = Patient.objects.create(nom="Proche10", prenoms="Test", sexe=Patient.SEXE_HOMME)
        with pytest.raises(ValidationError):
            LienProche.objects.create(titulaire=titulaire, patient=onzieme, lien=LienProche.AUTRE)

    def test_titulaire_ne_peut_pas_etre_son_propre_proche(self, titulaire):
        with pytest.raises(ValidationError):
            LienProche.objects.create(titulaire=titulaire, patient=titulaire, lien=LienProche.AUTRE)


class TestUnTelephoneUnCompte:
    def test_telephone_unique_sur_utilisateur(self):
        Utilisateur.objects.create_user(telephone="+224620000111")
        with pytest.raises(Exception):
            Utilisateur.objects.create_user(telephone="+224620000111")
