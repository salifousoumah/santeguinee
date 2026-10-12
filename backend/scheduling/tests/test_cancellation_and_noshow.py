"""Tests des règles RG-09 (annulation), RG-11 (acompte après absences) et
RG-12 (bascule automatique en 'absent')."""

import datetime

import pytest
from django.test import override_settings
from django.utils import timezone

from conftest import creer_creneau
from scheduling.models import Creneau, RendezVous
from scheduling.services import (
    annuler_rendez_vous,
    confirmer_rendez_vous,
    flip_noshows,
    requires_deposit,
)

pytestmark = pytest.mark.django_db


class TestAnnulation:
    def test_annulation_gratuite_plus_de_24h_avant(self, patient, exercice, creneau_futur):
        rdv = confirmer_rendez_vous(patient=patient, creneau_id=creneau_futur.id, exercice=exercice)
        rdv = annuler_rendez_vous(rdv, motif="changement de programme")
        assert rdv.statut == RendezVous.ANNULE
        assert rdv.depot_perdu is False
        # Le créneau redevient disponible.
        creneau_futur.refresh_from_db()
        assert creneau_futur.statut == Creneau.LIBRE

    @override_settings(DELAI_ANNULATION_GRATUITE_HEURES=24, MIN_HEURES_AVANT_RESERVATION=0)
    def test_annulation_tardive_perd_le_depot_si_requis(self, patient, exercice):
        creneau = creer_creneau(exercice, debut_dans_heures=2)
        rdv = confirmer_rendez_vous(patient=patient, creneau_id=creneau.id, exercice=exercice)
        rdv.depot_requis = True
        rdv.save(update_fields=["depot_requis"])

        rdv = annuler_rendez_vous(rdv)
        assert rdv.statut == RendezVous.ANNULE
        assert rdv.depot_perdu is True


class TestAcompteApresAbsences:
    @override_settings(MAX_ABSENCES_AVANT_ACOMPTE=3, PERIODE_ABSENCES_MOIS=6)
    def test_pas_d_acompte_sous_le_seuil(self, patient, exercice):
        for i in range(2):
            creneau = creer_creneau(exercice, debut_dans_heures=48 + i * 24)
            rdv = RendezVous.objects.create(
                patient=patient, creneau=creneau, exercice=exercice, statut=RendezVous.ABSENT
            )
        assert requires_deposit(patient) is False

    @override_settings(MAX_ABSENCES_AVANT_ACOMPTE=3, PERIODE_ABSENCES_MOIS=6)
    def test_acompte_exige_apres_trois_absences(self, patient, exercice):
        for i in range(3):
            creneau = creer_creneau(exercice, debut_dans_heures=48 + i * 24)
            RendezVous.objects.create(
                patient=patient, creneau=creneau, exercice=exercice, statut=RendezVous.ABSENT
            )
        assert requires_deposit(patient) is True


class TestBasculeNoShow:
    @override_settings(DELAI_NO_SHOW_MINUTES=30)
    def test_rendez_vous_passe_bascule_en_absent(self, patient, exercice):
        debut = timezone.now() - datetime.timedelta(hours=1)
        creneau = Creneau.objects.create(
            exercice=exercice,
            debut=debut,
            fin=debut + datetime.timedelta(minutes=30),
            statut=Creneau.RESERVE,
        )
        rdv = RendezVous.objects.create(
            patient=patient, creneau=creneau, exercice=exercice, statut=RendezVous.RESERVE
        )

        nb = flip_noshows()

        rdv.refresh_from_db()
        assert nb == 1
        assert rdv.statut == RendezVous.ABSENT

    @override_settings(DELAI_NO_SHOW_MINUTES=30)
    def test_rendez_vous_recent_ne_bascule_pas(self, patient, exercice):
        debut = timezone.now() - datetime.timedelta(minutes=5)
        creneau = Creneau.objects.create(
            exercice=exercice,
            debut=debut,
            fin=debut + datetime.timedelta(minutes=30),
            statut=Creneau.RESERVE,
        )
        rdv = RendezVous.objects.create(
            patient=patient, creneau=creneau, exercice=exercice, statut=RendezVous.RESERVE
        )

        flip_noshows()

        rdv.refresh_from_db()
        assert rdv.statut == RendezVous.RESERVE
