"""Modèles du module de prise de rendez-vous.

Les règles de gestion (RG-05 à RG-12, RG-24) sont centralisées dans
scheduling/services.py pour que les tests puissent les exercer
directement, en plus de la validation au niveau modèle.
"""

import uuid

from django.conf import settings
from django.core.exceptions import ValidationError
from django.db import models
from django.utils import timezone

from directory.models import Exercice, Praticien


class TypeConsultation(models.Model):
    """Type de consultation proposé pour un Exercice (durée, tarif, ...)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    exercice = models.ForeignKey(
        Exercice, on_delete=models.CASCADE, related_name="types_consultation"
    )
    libelle = models.CharField(max_length=150)
    duree_min = models.PositiveIntegerField(help_text="Durée en minutes")
    tarif_gnf = models.PositiveIntegerField(null=True, blank=True)
    reservable_en_ligne = models.BooleanField(default=True)
    acompte_gnf = models.PositiveIntegerField(default=0, blank=True)

    class Meta:
        verbose_name = "Type de consultation"
        verbose_name_plural = "Types de consultation"

    def __str__(self):
        return f"{self.libelle} ({self.duree_min} min)"


class PlageHoraire(models.Model):
    """Gabarit hebdomadaire récurrent de disponibilité d'un Exercice.

    Sert de base à la génération des Creneau concrets (RG-05, voir
    scheduling/services.py::generer_creneaux).
    """

    LUNDI, MARDI, MERCREDI, JEUDI, VENDREDI, SAMEDI, DIMANCHE = range(7)
    JOUR_CHOICES = [
        (LUNDI, "Lundi"),
        (MARDI, "Mardi"),
        (MERCREDI, "Mercredi"),
        (JEUDI, "Jeudi"),
        (VENDREDI, "Vendredi"),
        (SAMEDI, "Samedi"),
        (DIMANCHE, "Dimanche"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    exercice = models.ForeignKey(
        Exercice, on_delete=models.CASCADE, related_name="plages_horaires"
    )
    jour_semaine = models.PositiveSmallIntegerField(choices=JOUR_CHOICES)
    heure_debut = models.TimeField()
    heure_fin = models.TimeField()
    types_autorises = models.ManyToManyField(TypeConsultation, related_name="plages_horaires")
    part_en_ligne = models.PositiveSmallIntegerField(
        default=100, help_text="Pourcentage de créneaux proposés en ligne (0-100)"
    )
    valide_du = models.DateField(null=True, blank=True)
    valide_au = models.DateField(null=True, blank=True)

    class Meta:
        verbose_name = "Plage horaire"
        verbose_name_plural = "Plages horaires"

    def __str__(self):
        return f"{self.exercice} - {self.get_jour_semaine_display()} {self.heure_debut}-{self.heure_fin}"


class Indisponibilite(models.Model):
    """Absence déclarée par un praticien (congé, formation, imprévu...)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    praticien = models.ForeignKey(
        Praticien, on_delete=models.CASCADE, related_name="indisponibilites"
    )
    debut = models.DateTimeField()
    fin = models.DateTimeField()
    motif = models.CharField(max_length=255, blank=True)

    class Meta:
        verbose_name = "Indisponibilité"
        verbose_name_plural = "Indisponibilités"

    def __str__(self):
        return f"{self.praticien} indisponible {self.debut:%Y-%m-%d %H:%M} -> {self.fin:%Y-%m-%d %H:%M}"


class Creneau(models.Model):
    """Créneau concret, généré à partir d'une PlageHoraire (RG-05).

    RG-06 : la sélection d'un créneau le verrouille 5 minutes
    (`verrou_expire_le`) ; sans confirmation il doit repasser `libre`
    (voir scheduling.services.liberer_verrous_expires) ; un créneau ne
    peut jamais être réservé deux fois (contrainte OneToOne côté
    RendezVous + transition de statut contrôlée ci-dessous).
    """

    LIBRE = "libre"
    VERROUILLE = "verrouille"
    RESERVE = "reserve"
    BLOQUE = "bloque"
    STATUT_CHOICES = [
        (LIBRE, "Libre"),
        (VERROUILLE, "Verrouillé"),
        (RESERVE, "Réservé"),
        (BLOQUE, "Bloqué"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    exercice = models.ForeignKey(
        Exercice, on_delete=models.CASCADE, related_name="creneaux"
    )
    debut = models.DateTimeField()
    fin = models.DateTimeField()
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default=LIBRE)
    verrou_expire_le = models.DateTimeField(null=True, blank=True)
    en_ligne = models.BooleanField(default=True)

    class Meta:
        verbose_name = "Créneau"
        verbose_name_plural = "Créneaux"
        ordering = ["debut"]
        indexes = [models.Index(fields=["exercice", "debut"])]
        constraints = [
            models.UniqueConstraint(
                fields=["exercice", "debut"], name="creneau_unique_par_exercice_debut"
            )
        ]

    def __str__(self):
        return f"{self.exercice} {self.debut:%Y-%m-%d %H:%M} ({self.statut})"

    def verrou_actif(self):
        return (
            self.statut == self.VERROUILLE
            and self.verrou_expire_le is not None
            and self.verrou_expire_le > timezone.now()
        )


class RendezVous(models.Model):
    """Rendez-vous confirmé, lié de façon unique à un Creneau (RG-06).

    `creneau` est un OneToOneField : la base de données elle-même
    interdit qu'un même créneau porte deux rendez-vous (double
    réservation), en plus des contrôles applicatifs de
    scheduling.services.
    """

    RESERVE = "reserve"
    ARRIVE = "arrive"
    EN_CONSULTATION = "en_consultation"
    TERMINE = "termine"
    ABSENT = "absent"
    ANNULE = "annule"
    STATUT_CHOICES = [
        (RESERVE, "Réservé"),
        (ARRIVE, "Arrivé"),
        (EN_CONSULTATION, "En consultation"),
        (TERMINE, "Terminé"),
        (ABSENT, "Absent"),
        (ANNULE, "Annulé"),
    ]

    APPLICATION = "application"
    TELEPHONE = "telephone"
    SANS_RENDEZ_VOUS = "sans_rendez_vous"
    CANAL_CHOICES = [
        (APPLICATION, "Application"),
        (TELEPHONE, "Téléphone"),
        (SANS_RENDEZ_VOUS, "Sans rendez-vous"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "accounts.Patient", on_delete=models.CASCADE, related_name="rendez_vous"
    )
    creneau = models.OneToOneField(
        Creneau, on_delete=models.PROTECT, related_name="rendez_vous"
    )
    exercice = models.ForeignKey(
        Exercice, on_delete=models.CASCADE, related_name="rendez_vous"
    )
    type_consultation = models.ForeignKey(
        TypeConsultation, on_delete=models.SET_NULL, null=True, blank=True
    )
    motif = models.CharField(max_length=255, blank=True)
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default=RESERVE)
    canal = models.CharField(max_length=20, choices=CANAL_CHOICES, default=APPLICATION)
    annule_par = models.ForeignKey(
        "accounts.Utilisateur",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="rendez_vous_annules",
    )
    motif_annulation = models.TextField(blank=True, null=True)
    # RG-09 : si l'annulation a lieu trop tard, un éventuel acompte est
    # perdu. Pas d'intégration paiement réelle (phase 2) : simple drapeau.
    depot_requis = models.BooleanField(default=False)
    depot_perdu = models.BooleanField(default=False)
    paiement_id = models.CharField(
        max_length=100, null=True, blank=True, help_text="Placeholder phase 2 (paiement)"
    )
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Rendez-vous"
        verbose_name_plural = "Rendez-vous"
        ordering = ["-cree_le"]

    def __str__(self):
        return f"RDV {self.patient} - {self.creneau} ({self.statut})"


class ListeAttente(models.Model):
    """Liste d'attente lorsqu'aucun créneau ne convient immédiatement."""

    EN_ATTENTE = "en_attente"
    NOTIFIE = "notifie"
    ANNULE = "annule"
    STATUT_CHOICES = [
        (EN_ATTENTE, "En attente"),
        (NOTIFIE, "Notifié"),
        (ANNULE, "Annulé"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    patient = models.ForeignKey(
        "accounts.Patient", on_delete=models.CASCADE, related_name="listes_attente"
    )
    exercice = models.ForeignKey(
        Exercice, on_delete=models.CASCADE, related_name="listes_attente"
    )
    date_souhaitee = models.DateField()
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default=EN_ATTENTE)
    notifie_le = models.DateTimeField(null=True, blank=True)
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Liste d'attente"
        verbose_name_plural = "Listes d'attente"

    def __str__(self):
        return f"{self.patient} - {self.exercice} ({self.date_souhaitee})"
