"""Tests des règles de gestion RG-06, RG-07 et RG-08 (voir
scheduling/services.py).
"""

import datetime

import pytest
from django.utils import timezone

from accounts.models import Patient
from scheduling.models import Creneau, RendezVous
from scheduling.services import (
    ReglMetierError,
    confirmer_rendez_vous,
    liberer_si_verrou_expire,
    verrouiller_creneau,
)

from conftest import creer_creneau

pytestmark = pytest.mark.django_db


class TestVerrouillageEtDoubleReservation:
    """RG-06 : verrouillage d'un créneau, impossibilité de double réservation."""

    def test_verrouillage_marque_le_creneau_verrouille(self, creneau_futur):
        creneau = verrouiller_creneau(creneau_futur.id)
        assert creneau.statut == Creneau.VERROUILLE
        assert creneau.verrou_expire_le is not None
        assert creneau.verrou_expire_le > timezone.now()

    def test_verrouillage_d_un_creneau_deja_verrouille_echoue(self, creneau_futur):
        verrouiller_creneau(creneau_futur.id)
        with pytest.raises(ReglMetierError):
            verrouiller_creneau(creneau_futur.id)

    def test_verrou_expire_redevient_libre(self, creneau_futur):
        creneau = verrouiller_creneau(creneau_futur.id)
        creneau.verrou_expire_le = timezone.now() - datetime.timedelta(seconds=1)
        creneau.save(update_fields=["verrou_expire_le"])

        creneau = liberer_si_verrou_expire(creneau)
        assert creneau.statut == Creneau.LIBRE
        assert creneau.verrou_expire_le is None

    def test_confirmation_sur_creneau_deja_reserve_echoue(self, patient, exercice, creneau_futur):
        confirmer_rendez_vous(patient=patient, creneau_id=creneau_futur.id, exercice=exercice)

        autre_patient = Patient.objects.create(
            nom="Autre", prenoms="Patient", sexe=Patient.SEXE_HOMME
        )
        with pytest.raises(ReglMetierError):
            confirmer_rendez_vous(
                patient=autre_patient, creneau_id=creneau_futur.id, exercice=exercice
            )

    def test_un_seul_rendez_vous_par_creneau_en_base(self, patient, exercice, creneau_futur):
        """La contrainte OneToOne RendezVous.creneau empêche toute double
        réservation même si la logique applicative était contournée."""
        confirmer_rendez_vous(patient=patient, creneau_id=creneau_futur.id, exercice=exercice)
        assert RendezVous.objects.filter(creneau=creneau_futur).count() == 1

        from django.db import IntegrityError

        autre_patient = Patient.objects.create(
            nom="Autre2", prenoms="Patient", sexe=Patient.SEXE_HOMME
        )
        with pytest.raises(IntegrityError):
            RendezVous.objects.create(
                patient=autre_patient, creneau=creneau_futur, exercice=exercice
            )


class TestQuotaEtChevauchement:
    """RG-07 : max 3 rendez-vous futurs avec le même praticien, pas de
    chevauchement."""

    def test_trois_rendez_vous_futurs_autorises_puis_le_quatrieme_refuse(
        self, patient, exercice
    ):
        for heures in (48, 72, 96):
            creneau = creer_creneau(exercice, debut_dans_heures=heures)
            confirmer_rendez_vous(patient=patient, creneau_id=creneau.id, exercice=exercice)

        quatrieme = creer_creneau(exercice, debut_dans_heures=120)
        with pytest.raises(ReglMetierError):
            confirmer_rendez_vous(patient=patient, creneau_id=quatrieme.id, exercice=exercice)

    def test_rendez_vous_annule_ne_compte_pas_dans_le_quota(self, patient, exercice):
        from scheduling.services import annuler_rendez_vous

        for heures in (48, 72, 96):
            creneau = creer_creneau(exercice, debut_dans_heures=heures)
            rdv = confirmer_rendez_vous(patient=patient, creneau_id=creneau.id, exercice=exercice)

        annuler_rendez_vous(rdv)

        quatrieme = creer_creneau(exercice, debut_dans_heures=120)
        # Ne doit plus lever d'exception puisqu'un des 3 a été annulé.
        confirmer_rendez_vous(patient=patient, creneau_id=quatrieme.id, exercice=exercice)

    def test_chevauchement_refuse(self, patient, exercice):
        debut = timezone.now() + datetime.timedelta(hours=48)
        debut = debut.replace(minute=0, second=0, microsecond=0)
        creneau_a = Creneau.objects.create(
            exercice=exercice, debut=debut, fin=debut + datetime.timedelta(minutes=30)
        )
        confirmer_rendez_vous(patient=patient, creneau_id=creneau_a.id, exercice=exercice)

        # Un deuxième créneau qui chevauche partiellement le premier.
        creneau_b = Creneau.objects.create(
            exercice=exercice,
            debut=debut + datetime.timedelta(minutes=15),
            fin=debut + datetime.timedelta(minutes=45),
        )
        with pytest.raises(ReglMetierError):
            confirmer_rendez_vous(patient=patient, creneau_id=creneau_b.id, exercice=exercice)


class TestDelaiMinimumReservation:
    """RG-08 : réservation impossible moins d'1h avant le créneau."""

    def test_reservation_moins_d_une_heure_avant_refusee(self, patient, exercice):
        creneau = creer_creneau(exercice, debut_dans_heures=0)
        # Forcer un début dans 30 minutes (moins que le délai minimum d'1h).
        creneau.debut = timezone.now() + datetime.timedelta(minutes=30)
        creneau.fin = creneau.debut + datetime.timedelta(minutes=30)
        creneau.save()

        with pytest.raises(ReglMetierError):
            confirmer_rendez_vous(patient=patient, creneau_id=creneau.id, exercice=exercice)

    def test_reservation_plus_d_une_heure_avant_acceptee(self, patient, exercice, creneau_futur):
        rdv = confirmer_rendez_vous(patient=patient, creneau_id=creneau_futur.id, exercice=exercice)
        assert rdv.statut == RendezVous.RESERVE
