"""Modèles de l'annuaire des établissements de santé et praticiens.

Simplification volontaire (voir README) : les coordonnées GPS sont de
simples flottants (latitude/longitude) et la recherche géographique se
fait par calcul de distance Haversine en Python/SQL plutôt que via
PostGIS/GeoDjango, pour rester portable sans dépendances système
lourdes (GDAL, etc.).
"""

import uuid

from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models

from common.models import BaseModel


class Zone(models.Model):
    """Hiérarchie administrative guinéenne : région > préfecture >
    commune/sous-préfecture > quartier/district.

    Le contour géographique (polygone) est hors périmètre MVP ; seule la
    hiérarchie (parent) est modélisée.
    """

    REGION = "region"
    PREFECTURE = "prefecture"
    COMMUNE_SOUS_PREFECTURE = "commune_sous_prefecture"
    QUARTIER_DISTRICT = "quartier_district"
    TYPE_CHOICES = [
        (REGION, "Région"),
        (PREFECTURE, "Préfecture"),
        (COMMUNE_SOUS_PREFECTURE, "Commune / Sous-préfecture"),
        (QUARTIER_DISTRICT, "Quartier / District"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    type = models.CharField(max_length=30, choices=TYPE_CHOICES)
    nom = models.CharField(max_length=150)
    parent = models.ForeignKey(
        "self", on_delete=models.CASCADE, null=True, blank=True, related_name="enfants"
    )

    class Meta:
        verbose_name = "Zone"
        verbose_name_plural = "Zones"
        ordering = ["type", "nom"]

    def __str__(self):
        return f"{self.nom} ({self.get_type_display()})"


class Specialite(models.Model):
    """Spécialité médicale, avec un libellé grand public plus simple."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    code = models.CharField(max_length=30, unique=True)
    libelle = models.CharField(max_length=150)
    libelle_grand_public = models.CharField(
        max_length=150,
        blank=True,
        help_text="Ex : 'médecin des enfants' pour Pédiatrie",
    )
    icone = models.CharField(max_length=50, blank=True)

    class Meta:
        verbose_name = "Spécialité"
        verbose_name_plural = "Spécialités"
        ordering = ["libelle"]

    def __str__(self):
        return self.libelle


class Etablissement(BaseModel):
    """Établissement de santé (hôpital, centre de santé, pharmacie, ...)."""

    CHU = "CHU"
    HOPITAL_REGIONAL = "hopital_regional"
    HOPITAL_PREFECTORAL = "hopital_prefectoral"
    CENTRE_SANTE = "centre_sante"
    POSTE_SANTE = "poste_sante"
    CLINIQUE = "clinique"
    CABINET = "cabinet"
    LABORATOIRE = "laboratoire"
    PHARMACIE = "pharmacie"
    TYPE_CHOICES = [
        (CHU, "CHU"),
        (HOPITAL_REGIONAL, "Hôpital régional"),
        (HOPITAL_PREFECTORAL, "Hôpital préfectoral"),
        (CENTRE_SANTE, "Centre de santé"),
        (POSTE_SANTE, "Poste de santé"),
        (CLINIQUE, "Clinique"),
        (CABINET, "Cabinet"),
        (LABORATOIRE, "Laboratoire"),
        (PHARMACIE, "Pharmacie"),
    ]

    PUBLIC = "public"
    PRIVE = "prive"
    CONFESSIONNEL = "confessionnel"
    ONG = "ong"
    SECTEUR_CHOICES = [
        (PUBLIC, "Public"),
        (PRIVE, "Privé"),
        (CONFESSIONNEL, "Confessionnel"),
        (ONG, "ONG"),
    ]

    EN_ATTENTE = "en_attente"
    VERIFIE = "verifie"
    REJETE = "rejete"
    STATUT_VERIFICATION_CHOICES = [
        (EN_ATTENTE, "En attente"),
        (VERIFIE, "Vérifié"),
        (REJETE, "Rejeté"),
    ]

    MOYEN_ESPECES = "especes"
    MOYEN_MOBILE_MONEY = "mobile_money"
    MOYEN_CARTE = "carte"
    MOYEN_ASSURANCE = "assurance"
    MOYENS_PAIEMENT_CHOICES = [
        (MOYEN_ESPECES, "Espèces"),
        (MOYEN_MOBILE_MONEY, "Mobile money"),
        (MOYEN_CARTE, "Carte bancaire"),
        (MOYEN_ASSURANCE, "Assurance"),
    ]

    nom = models.CharField(max_length=200)
    type = models.CharField(max_length=30, choices=TYPE_CHOICES)
    secteur = models.CharField(max_length=20, choices=SECTEUR_CHOICES)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    repere = models.TextField(
        blank=True, help_text="Description du repère / point de localisation"
    )
    quartier = models.ForeignKey(
        Zone, on_delete=models.SET_NULL, null=True, blank=True, related_name="etablissements"
    )
    telephones = models.CharField(
        max_length=255, blank=True, help_text="Numéros séparés par des virgules"
    )
    urgences_24h = models.BooleanField(default=False)
    moyens_paiement = models.CharField(
        max_length=255,
        blank=True,
        help_text="Liste de codes séparés par des virgules, ex : especes,mobile_money",
    )
    photos = models.TextField(
        blank=True, help_text="URLs de photos séparées par des retours à la ligne"
    )
    statut_verification = models.CharField(
        max_length=20, choices=STATUT_VERIFICATION_CHOICES, default=EN_ATTENTE
    )
    verifie_le = models.DateTimeField(null=True, blank=True)
    code_officiel = models.CharField(
        max_length=50, blank=True, help_text="Code ministère de la santé"
    )

    class Meta:
        verbose_name = "Établissement"
        verbose_name_plural = "Établissements"
        ordering = ["nom"]

    def __str__(self):
        return self.nom

    def liste_moyens_paiement(self):
        return [m for m in self.moyens_paiement.split(",") if m]

    def liste_telephones(self):
        return [t.strip() for t in self.telephones.split(",") if t.strip()]


class Service(models.Model):
    """Service / unité fonctionnelle au sein d'un établissement."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    etablissement = models.ForeignKey(
        Etablissement, on_delete=models.CASCADE, related_name="services"
    )
    nom = models.CharField(max_length=150)
    specialite = models.ForeignKey(
        Specialite, on_delete=models.SET_NULL, null=True, blank=True, related_name="services"
    )
    telephone = models.CharField(max_length=20, blank=True)
    etage_ou_batiment = models.CharField(max_length=100, blank=True)

    class Meta:
        verbose_name = "Service"
        verbose_name_plural = "Services"

    def __str__(self):
        return f"{self.nom} ({self.etablissement.nom})"


class Horaire(models.Model):
    """Horaire d'ouverture, rattaché soit à un établissement, soit à un
    service (l'un des deux, pas les deux).

    `exceptionnel` permet de modéliser une fermeture ou un horaire
    ponctuel pour une date donnée, en plus du planning hebdomadaire.
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
    etablissement = models.ForeignKey(
        Etablissement,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="horaires",
    )
    service = models.ForeignKey(
        Service, on_delete=models.CASCADE, null=True, blank=True, related_name="horaires"
    )
    jour_semaine = models.PositiveSmallIntegerField(
        choices=JOUR_CHOICES, validators=[MinValueValidator(0), MaxValueValidator(6)]
    )
    heure_debut = models.TimeField()
    heure_fin = models.TimeField()
    exceptionnel = models.DateField(
        null=True, blank=True, help_text="Date précise si cet horaire est une exception ponctuelle"
    )

    class Meta:
        verbose_name = "Horaire"
        verbose_name_plural = "Horaires"
        constraints = [
            models.CheckConstraint(
                condition=(
                    models.Q(etablissement__isnull=False, service__isnull=True)
                    | models.Q(etablissement__isnull=True, service__isnull=False)
                ),
                name="horaire_cible_unique",
            )
        ]

    def __str__(self):
        cible = self.etablissement or self.service
        return f"{cible} - {self.get_jour_semaine_display()} {self.heure_debut}-{self.heure_fin}"


class Garde(models.Model):
    """Période de garde (service d'urgence actif en continu, de nuit, etc.)."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    etablissement = models.ForeignKey(
        Etablissement, on_delete=models.CASCADE, related_name="gardes"
    )
    service = models.ForeignKey(
        Service, on_delete=models.CASCADE, null=True, blank=True, related_name="gardes"
    )
    debut = models.DateTimeField()
    fin = models.DateTimeField()

    class Meta:
        verbose_name = "Garde"
        verbose_name_plural = "Gardes"

    def __str__(self):
        return f"Garde {self.etablissement.nom} {self.debut:%Y-%m-%d %H:%M} -> {self.fin:%Y-%m-%d %H:%M}"


class Praticien(BaseModel):
    """Professionnel de santé (indépendant de l'établissement, voir Exercice)."""

    MEDECIN = "medecin"
    SAGE_FEMME = "sage_femme"
    DENTISTE = "dentiste"
    INFIRMIER = "infirmier"
    KINESITHERAPEUTE = "kinesitherapeute"
    PROFESSION_CHOICES = [
        (MEDECIN, "Médecin"),
        (SAGE_FEMME, "Sage-femme"),
        (DENTISTE, "Dentiste"),
        (INFIRMIER, "Infirmier"),
        (KINESITHERAPEUTE, "Kinésithérapeute"),
    ]

    EN_ATTENTE = Etablissement.EN_ATTENTE
    VERIFIE = Etablissement.VERIFIE
    REJETE = Etablissement.REJETE
    STATUT_VERIFICATION_CHOICES = Etablissement.STATUT_VERIFICATION_CHOICES

    nom = models.CharField(max_length=100)
    prenoms = models.CharField(max_length=150)
    civilite = models.CharField(max_length=10, blank=True, help_text="Dr, M., Mme, ...")
    profession = models.CharField(max_length=30, choices=PROFESSION_CHOICES)
    numero_ordre = models.CharField(max_length=50, blank=True)
    langues = models.CharField(
        max_length=255, blank=True, help_text="Langues parlées, séparées par des virgules"
    )
    presentation = models.TextField(blank=True)
    statut_verification = models.CharField(
        max_length=20, choices=STATUT_VERIFICATION_CHOICES, default=EN_ATTENTE
    )
    verifie_le = models.DateTimeField(null=True, blank=True)
    specialites = models.ManyToManyField(Specialite, related_name="praticiens", blank=True)

    class Meta:
        verbose_name = "Praticien"
        verbose_name_plural = "Praticiens"
        ordering = ["nom", "prenoms"]

    def __str__(self):
        return f"{self.civilite} {self.nom} {self.prenoms}".strip()

    def liste_langues(self):
        return [l.strip() for l in self.langues.split(",") if l.strip()]


class Exercice(models.Model):
    """Lien d'exercice d'un praticien dans un établissement (et service).

    Un même praticien peut avoir plusieurs Exercice (plusieurs lieux).
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    praticien = models.ForeignKey(
        Praticien, on_delete=models.CASCADE, related_name="exercices"
    )
    etablissement = models.ForeignKey(
        Etablissement, on_delete=models.CASCADE, related_name="exercices"
    )
    service = models.ForeignKey(
        Service, on_delete=models.SET_NULL, null=True, blank=True, related_name="exercices"
    )
    tarif_indicatif_gnf = models.PositiveIntegerField(
        null=True, blank=True, help_text="Tarif indicatif en francs guinéens (GNF, pas de sous-unité)"
    )
    actif = models.BooleanField(default=True)

    class Meta:
        verbose_name = "Exercice"
        verbose_name_plural = "Exercices"
        unique_together = ("praticien", "etablissement", "service")

    def __str__(self):
        return f"{self.praticien} @ {self.etablissement}"


class Signalement(models.Model):
    """Signalement d'une correction par un utilisateur (fiche établissement
    ou praticien)."""

    NOUVEAU = "nouveau"
    TRAITE = "traite"
    REJETE = "rejete"
    STATUT_CHOICES = [
        (NOUVEAU, "Nouveau"),
        (TRAITE, "Traité"),
        (REJETE, "Rejeté"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    etablissement = models.ForeignKey(
        Etablissement,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="signalements",
    )
    praticien = models.ForeignKey(
        Praticien,
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="signalements",
    )
    description = models.TextField()
    statut = models.CharField(max_length=20, choices=STATUT_CHOICES, default=NOUVEAU)
    traite_par = models.ForeignKey(
        "accounts.Utilisateur",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="signalements_traites",
    )
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Signalement"
        verbose_name_plural = "Signalements"
        constraints = [
            models.CheckConstraint(
                condition=(
                    models.Q(etablissement__isnull=False, praticien__isnull=True)
                    | models.Q(etablissement__isnull=True, praticien__isnull=False)
                ),
                name="signalement_cible_unique",
            )
        ]

    def __str__(self):
        cible = self.etablissement or self.praticien
        return f"Signalement {cible} ({self.get_statut_display()})"
