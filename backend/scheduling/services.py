"""Fonctions de service portant les règles de gestion (RG-xx) du module
prise de rendez-vous. Mises ici (et non seulement dans les serializers)
pour que les tests puissent les exercer directement.
"""

import datetime

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from .models import Creneau, Indisponibilite, PlageHoraire, RendezVous


class ReglMetierError(Exception):
    """Erreur levée quand une règle de gestion (RG-xx) est violée."""


def generer_creneaux(exercice, jours=None, aujourd_hui=None):
    """RG-05 : génère les Creneau concrets à partir des PlageHoraire d'un
    Exercice, sur une fenêtre glissante de `jours` jours (défaut
    settings.SLOT_GENERATION_WINDOW_DAYS, paramétrable 14-90).

    Les créneaux se découpent selon la durée du premier TypeConsultation
    autorisé par la plage (ou 30 min par défaut s'il n'y en a aucun).
    Toute plage temporelle chevauchée par une Indisponibilite du
    praticien est ignorée.

    Retourne la liste des Creneau créés (les créneaux déjà existants à
    la même date/heure ne sont pas dupliqués, grâce à la contrainte
    unique (exercice, debut)).
    """
    jours = jours or getattr(settings, "SLOT_GENERATION_WINDOW_DAYS", 60)
    jours = max(14, min(90, jours))
    aujourd_hui = aujourd_hui or timezone.localdate()

    indisponibilites = list(
        Indisponibilite.objects.filter(praticien=exercice.praticien)
    )

    def chevauche_indisponibilite(debut_dt, fin_dt):
        for indispo in indisponibilites:
            if debut_dt < indispo.fin and fin_dt > indispo.debut:
                return True
        return False

    crees = []
    plages = PlageHoraire.objects.filter(exercice=exercice).prefetch_related(
        "types_autorises"
    )
    for plage in plages:
        type_defaut = plage.types_autorises.first()
        duree = datetime.timedelta(minutes=type_defaut.duree_min if type_defaut else 30)

        for offset in range(jours):
            date_jour = aujourd_hui + datetime.timedelta(days=offset)
            if date_jour.weekday() != plage.jour_semaine:
                continue
            if plage.valide_du and date_jour < plage.valide_du:
                continue
            if plage.valide_au and date_jour > plage.valide_au:
                continue

            courant = datetime.datetime.combine(date_jour, plage.heure_debut)
            fin_plage = datetime.datetime.combine(date_jour, plage.heure_fin)
            courant = timezone.make_aware(courant) if timezone.is_naive(courant) else courant
            fin_plage = timezone.make_aware(fin_plage) if timezone.is_naive(fin_plage) else fin_plage

            while courant + duree <= fin_plage:
                fin_creneau = courant + duree
                deja_passe = courant <= timezone.now()
                if not deja_passe and not chevauche_indisponibilite(courant, fin_creneau):
                    creneau, cree = Creneau.objects.get_or_create(
                        exercice=exercice,
                        debut=courant,
                        defaults={"fin": fin_creneau, "statut": Creneau.LIBRE},
                    )
                    if cree:
                        crees.append(creneau)
                courant = fin_creneau

    return crees


@transaction.atomic
def verrouiller_creneau(creneau_id):
    """RG-06 : verrouille un créneau libre pendant
    settings.SLOT_LOCK_MINUTES minutes. Lève ReglMetierError si le
    créneau n'est pas disponible (déjà verrouillé/réservé/bloqué).
    """
    creneau = Creneau.objects.select_for_update().get(pk=creneau_id)
    liberer_si_verrou_expire(creneau)

    if creneau.statut != Creneau.LIBRE:
        raise ReglMetierError("Ce créneau n'est plus disponible.")

    creneau.statut = Creneau.VERROUILLE
    creneau.verrou_expire_le = timezone.now() + datetime.timedelta(
        minutes=settings.SLOT_LOCK_MINUTES
    )
    creneau.save(update_fields=["statut", "verrou_expire_le"])
    return creneau


def liberer_si_verrou_expire(creneau):
    """RG-06 : si le verrou a expiré sans confirmation, le créneau
    redevient `libre`."""
    if (
        creneau.statut == Creneau.VERROUILLE
        and creneau.verrou_expire_le is not None
        and creneau.verrou_expire_le <= timezone.now()
    ):
        creneau.statut = Creneau.LIBRE
        creneau.verrou_expire_le = None
        creneau.save(update_fields=["statut", "verrou_expire_le"])
    return creneau


def liberer_verrous_expires():
    """À exécuter périodiquement (ou avant toute lecture de disponibilité) :
    repasse en `libre` tous les créneaux dont le verrou a expiré."""
    expires = Creneau.objects.filter(
        statut=Creneau.VERROUILLE, verrou_expire_le__lte=timezone.now()
    )
    return expires.update(statut=Creneau.LIBRE, verrou_expire_le=None)


def requires_deposit(patient):
    """RG-11 : un patient marqué "absent" au moins
    settings.MAX_ABSENCES_AVANT_ACOMPTE fois sur les
    settings.PERIODE_ABSENCES_MOIS derniers mois doit payer un acompte
    pour toute nouvelle réservation en ligne.

    Ne déclenche aucun paiement réel (hors périmètre MVP) : renvoie un
    simple booléen que l'appelant peut utiliser pour afficher/exiger un
    acompte.
    """
    depuis = timezone.now() - datetime.timedelta(
        days=30 * settings.PERIODE_ABSENCES_MOIS
    )
    nb_absences = RendezVous.objects.filter(
        patient=patient, statut=RendezVous.ABSENT, cree_le__gte=depuis
    ).count()
    return nb_absences >= settings.MAX_ABSENCES_AVANT_ACOMPTE


def _verifier_delai_minimum(creneau, maintenant):
    """RG-08 : réservation possible seulement si le créneau démarre au
    moins settings.MIN_HEURES_AVANT_RESERVATION heures dans le futur."""
    delai_minimum = datetime.timedelta(hours=settings.MIN_HEURES_AVANT_RESERVATION)
    if creneau.debut - maintenant < delai_minimum:
        raise ReglMetierError(
            f"RG-08 : la réservation doit se faire au moins "
            f"{settings.MIN_HEURES_AVANT_RESERVATION}h avant le créneau."
        )


def _verifier_quota_futur(patient, exercice, maintenant):
    """RG-07 : pas plus de settings.MAX_FUTURE_RDV_PAR_PRATICIEN rendez-vous
    futurs avec le même praticien (via l'exercice -> praticien)."""
    praticien = exercice.praticien
    nb_futurs = RendezVous.objects.filter(
        patient=patient,
        exercice__praticien=praticien,
        creneau__debut__gte=maintenant,
    ).exclude(statut=RendezVous.ANNULE).count()
    if nb_futurs >= settings.MAX_FUTURE_RDV_PAR_PRATICIEN:
        raise ReglMetierError(
            f"RG-07 : vous avez déjà {settings.MAX_FUTURE_RDV_PAR_PRATICIEN} "
            "rendez-vous futurs avec ce praticien."
        )


def _verifier_chevauchement(patient, creneau):
    """RG-07 : un patient ne peut pas avoir deux rendez-vous dont les
    créneaux se chevauchent dans le temps."""
    existants = RendezVous.objects.filter(patient=patient).exclude(
        statut=RendezVous.ANNULE
    ).select_related("creneau")
    for rdv in existants:
        autre = rdv.creneau
        if creneau.debut < autre.fin and creneau.fin > autre.debut:
            raise ReglMetierError(
                "RG-07 : ce rendez-vous chevauche un autre rendez-vous existant."
            )


@transaction.atomic
def confirmer_rendez_vous(
    patient, creneau_id, exercice, type_consultation=None, motif="", canal=RendezVous.APPLICATION
):
    """Confirme un rendez-vous sur un créneau préalablement verrouillé
    (ou libre, pour une réservation directe par téléphone/secrétariat).

    Applique RG-06 (pas de double réservation), RG-07 (quota + pas de
    chevauchement) et RG-08 (délai minimum).
    """
    creneau = Creneau.objects.select_for_update().get(pk=creneau_id)
    liberer_si_verrou_expire(creneau)
    maintenant = timezone.now()

    if creneau.statut not in (Creneau.LIBRE, Creneau.VERROUILLE):
        raise ReglMetierError("RG-06 : ce créneau est déjà réservé ou indisponible.")
    if creneau.statut == Creneau.VERROUILLE and not creneau.verrou_actif():
        raise ReglMetierError("Le verrou sur ce créneau a expiré.")

    _verifier_delai_minimum(creneau, maintenant)
    _verifier_quota_futur(patient, exercice, maintenant)
    _verifier_chevauchement(patient, creneau)

    depot_requis = requires_deposit(patient)

    rdv = RendezVous.objects.create(
        patient=patient,
        creneau=creneau,
        exercice=exercice,
        type_consultation=type_consultation,
        motif=motif,
        canal=canal,
        depot_requis=depot_requis,
    )
    creneau.statut = Creneau.RESERVE
    creneau.verrou_expire_le = None
    creneau.save(update_fields=["statut", "verrou_expire_le"])
    return rdv


@transaction.atomic
def annuler_rendez_vous(rendez_vous, utilisateur=None, motif=""):
    """RG-09 : annulation gratuite jusqu'à
    settings.DELAI_ANNULATION_GRATUITE_HEURES heures avant le créneau ;
    au-delà, un éventuel acompte est considéré comme perdu (simple
    drapeau, pas de prélèvement réel - paiement = phase 2)."""
    maintenant = timezone.now()
    delai = datetime.timedelta(hours=settings.DELAI_ANNULATION_GRATUITE_HEURES)
    trop_tard = (rendez_vous.creneau.debut - maintenant) < delai

    rendez_vous.statut = RendezVous.ANNULE
    rendez_vous.annule_par = utilisateur
    rendez_vous.motif_annulation = motif
    if trop_tard and rendez_vous.depot_requis:
        rendez_vous.depot_perdu = True
    rendez_vous.save()

    creneau = rendez_vous.creneau
    creneau.statut = Creneau.LIBRE
    creneau.verrou_expire_le = None
    creneau.save(update_fields=["statut", "verrou_expire_le"])
    return rendez_vous


def flip_noshows(maintenant=None):
    """RG-12 : tout rendez-vous "réservé" dont le créneau a débuté depuis
    plus de settings.DELAI_NO_SHOW_MINUTES minutes sans passage en
    "arrivé" bascule automatiquement en "absent".

    Destiné à être appelé par la commande de gestion `flip_noshows`
    (cf. scheduling/management/commands/flip_noshows.py), elle-même
    prévue pour être planifiée via cron (voir README).
    """
    maintenant = maintenant or timezone.now()
    seuil = maintenant - datetime.timedelta(minutes=settings.DELAI_NO_SHOW_MINUTES)
    a_basculer = RendezVous.objects.filter(
        statut=RendezVous.RESERVE, creneau__debut__lte=seuil
    )
    return a_basculer.update(statut=RendezVous.ABSENT)
