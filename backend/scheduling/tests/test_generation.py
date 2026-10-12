"""Tests de RG-05 (génération des créneaux à partir des plages horaires)."""

import datetime

import pytest
from django.utils import timezone

from scheduling.models import Creneau, Indisponibilite, PlageHoraire, TypeConsultation
from scheduling.services import generer_creneaux

pytestmark = pytest.mark.django_db


def _prochain_lundi(aujourd_hui):
    jours_a_ajouter = (7 - aujourd_hui.weekday()) % 7 or 7
    return aujourd_hui + datetime.timedelta(days=jours_a_ajouter)


class TestGenerationCreneaux:
    def test_generation_respecte_la_duree_du_type_consultation(self, exercice):
        type_consultation = TypeConsultation.objects.create(
            exercice=exercice, libelle="Consultation", duree_min=20, tarif_gnf=10000
        )
        plage = PlageHoraire.objects.create(
            exercice=exercice,
            jour_semaine=0,  # lundi
            heure_debut=datetime.time(9, 0),
            heure_fin=datetime.time(10, 0),
        )
        plage.types_autorises.add(type_consultation)

        aujourd_hui = timezone.localdate()
        crees = generer_creneaux(exercice, jours=14, aujourd_hui=aujourd_hui)

        # 1h / 20 min = 3 créneaux par lundi tombant dans la fenêtre de 14 jours.
        lundis_dans_fenetre = sum(
            1
            for offset in range(14)
            if (aujourd_hui + datetime.timedelta(days=offset)).weekday() == 0
        )
        assert len(crees) == 3 * lundis_dans_fenetre
        for creneau in crees:
            duree = creneau.fin - creneau.debut
            assert duree == datetime.timedelta(minutes=20)

    def test_generation_ignore_les_plages_couvertes_par_une_indisponibilite(self, exercice):
        plage = PlageHoraire.objects.create(
            exercice=exercice,
            jour_semaine=0,
            heure_debut=datetime.time(9, 0),
            heure_fin=datetime.time(10, 0),
        )
        aujourd_hui = timezone.localdate()
        lundi = _prochain_lundi(aujourd_hui - datetime.timedelta(days=1))
        debut_indispo = timezone.make_aware(datetime.datetime.combine(lundi, datetime.time(0, 0)))
        Indisponibilite.objects.create(
            praticien=exercice.praticien,
            debut=debut_indispo,
            fin=debut_indispo + datetime.timedelta(days=1),
            motif="Formation",
        )

        generer_creneaux(exercice, jours=14, aujourd_hui=aujourd_hui)

        assert not Creneau.objects.filter(exercice=exercice, debut__date=lundi).exists()

    def test_generation_est_idempotente(self, exercice):
        PlageHoraire.objects.create(
            exercice=exercice,
            jour_semaine=0,
            heure_debut=datetime.time(9, 0),
            heure_fin=datetime.time(10, 0),
        )
        aujourd_hui = timezone.localdate()
        generer_creneaux(exercice, jours=14, aujourd_hui=aujourd_hui)
        total_apres_premiere_generation = Creneau.objects.filter(exercice=exercice).count()

        generer_creneaux(exercice, jours=14, aujourd_hui=aujourd_hui)
        total_apres_deuxieme_generation = Creneau.objects.filter(exercice=exercice).count()

        assert total_apres_premiere_generation == total_apres_deuxieme_generation

    def test_fenetre_est_bornee_entre_14_et_90_jours(self, exercice):
        # Sans TypeConsultation rattaché, la durée par défaut est 30 min
        # (voir generer_creneaux) : on prévoit une plage qui en contient un.
        PlageHoraire.objects.create(
            exercice=exercice,
            jour_semaine=0,
            heure_debut=datetime.time(9, 0),
            heure_fin=datetime.time(9, 30),
        )
        aujourd_hui = timezone.localdate()
        generer_creneaux(exercice, jours=200, aujourd_hui=aujourd_hui)
        dernier = Creneau.objects.filter(exercice=exercice).order_by("-debut").first()
        assert (dernier.debut.date() - aujourd_hui).days <= 90
