"""Modèles du module comptes / authentification.

Spécificité du cahier des charges : l'identifiant de connexion est le
numéro de téléphone (pas un email ni un username). Les patients se
connectent via code SMS à usage unique (voir accounts/sms.py) ; les
comptes professionnels (praticien, secrétaire, admin) peuvent en plus
définir un mot de passe.
"""

import random
import uuid

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.models import PermissionsMixin
from django.core.exceptions import ValidationError
from django.core.validators import RegexValidator
from django.db import models
from django.utils import timezone

TELEPHONE_REGEX = RegexValidator(
    regex=r"^\+?[0-9]{8,15}$",
    message="Numéro de téléphone invalide (format attendu : +224XXXXXXXXX ou international).",
)


class UtilisateurManager(BaseUserManager):
    """Manager pour le modèle Utilisateur, identifié par `telephone`."""

    use_in_migrations = True

    def _normaliser_telephone(self, telephone):
        if not telephone:
            raise ValueError("Le numéro de téléphone est obligatoire.")
        return telephone.strip().replace(" ", "")

    def create_user(self, telephone, password=None, **extra_fields):
        telephone = self._normaliser_telephone(telephone)
        extra_fields.setdefault("is_active", True)
        utilisateur = self.model(telephone=telephone, **extra_fields)
        if password:
            utilisateur.set_password(password)
        else:
            utilisateur.set_unusable_password()
        utilisateur.save(using=self._db)
        return utilisateur

    def create_superuser(self, telephone, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        if not password:
            raise ValueError("Un superutilisateur doit avoir un mot de passe.")
        return self.create_user(telephone, password, **extra_fields)


class Utilisateur(AbstractBaseUser, PermissionsMixin):
    """Compte de connexion à la plateforme, identifié par numéro de téléphone.

    RG-24 : un numéro de téléphone = un seul compte (contrainte unique
    sur `telephone`).

    Note d'implémentation : le champ hérité `password` (fourni par
    AbstractBaseUser) EST le champ "hash_mot_de_passe" du cahier des
    charges : Django n'y stocke jamais le mot de passe en clair, toujours
    son hash (PBKDF2 par défaut). On le garde sous son nom standard pour
    rester compatible avec tout le framework d'authentification Django
    (set_password/check_password, formulaires admin, etc.) et on expose
    un alias `hash_mot_de_passe` ci-dessous pour matcher le vocabulaire
    du cahier des charges.
    """

    STATUT_ACTIF = "actif"
    STATUT_SUSPENDU = "suspendu"
    STATUT_CHOICES = [
        (STATUT_ACTIF, "Actif"),
        (STATUT_SUSPENDU, "Suspendu"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    telephone = models.CharField(
        max_length=20, unique=True, validators=[TELEPHONE_REGEX]
    )
    email = models.EmailField(blank=True, null=True)
    langue = models.CharField(max_length=5, default="fr")
    statut = models.CharField(
        max_length=10, choices=STATUT_CHOICES, default=STATUT_ACTIF
    )
    derniere_connexion = models.DateTimeField(null=True, blank=True)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)

    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    supprime_le = models.DateTimeField(null=True, blank=True)

    objects = UtilisateurManager()

    USERNAME_FIELD = "telephone"
    REQUIRED_FIELDS = []

    class Meta:
        verbose_name = "Utilisateur"
        verbose_name_plural = "Utilisateurs"

    def __str__(self):
        return self.telephone

    @property
    def hash_mot_de_passe(self):
        """Alias explicite vers le champ `password` (voir docstring classe)."""
        return self.password


class Role(models.Model):
    """Association utilisateur <-> rôle (éventuellement lié à un établissement)."""

    PATIENT = "patient"
    PRATICIEN = "praticien"
    SECRETAIRE = "secretaire"
    ADMIN_ETABLISSEMENT = "admin_etablissement"
    ADMIN_PLATEFORME = "admin_plateforme"
    ROLE_CHOICES = [
        (PATIENT, "Patient"),
        (PRATICIEN, "Praticien"),
        (SECRETAIRE, "Secrétaire"),
        (ADMIN_ETABLISSEMENT, "Administrateur d'établissement"),
        (ADMIN_PLATEFORME, "Administrateur plateforme"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    utilisateur = models.ForeignKey(
        Utilisateur, on_delete=models.CASCADE, related_name="roles"
    )
    role = models.CharField(max_length=30, choices=ROLE_CHOICES)
    etablissement = models.ForeignKey(
        "directory.Etablissement",
        on_delete=models.CASCADE,
        null=True,
        blank=True,
        related_name="roles",
    )
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("utilisateur", "role", "etablissement")

    def __str__(self):
        cible = f" @ {self.etablissement}" if self.etablissement_id else ""
        return f"{self.utilisateur} - {self.get_role_display()}{cible}"


def generer_numero_sante():
    """Génère un identifiant patient lisible, p.ex. SG-2026-ABC123."""
    annee = timezone.now().year
    suffixe = uuid.uuid4().hex[:6].upper()
    return f"SG-{annee}-{suffixe}"


class Patient(models.Model):
    """Dossier patient minimal (identité + contact), hors dossier médical.

    Le module dossier médical (section 6.4 / M7 du cahier des charges)
    est explicitement hors périmètre de cette passe.
    """

    SEXE_HOMME = "M"
    SEXE_FEMME = "F"
    SEXE_CHOICES = [(SEXE_HOMME, "Homme"), (SEXE_FEMME, "Femme")]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    numero_sante = models.CharField(
        max_length=20, unique=True, default=generer_numero_sante, editable=False
    )
    nom = models.CharField(max_length=100)
    prenoms = models.CharField(max_length=150)
    sexe = models.CharField(max_length=1, choices=SEXE_CHOICES)
    date_naissance = models.DateField(null=True, blank=True)
    telephone = models.CharField(
        max_length=20, blank=True, validators=[TELEPHONE_REGEX]
    )
    quartier = models.ForeignKey(
        "directory.Zone", on_delete=models.SET_NULL, null=True, blank=True
    )
    # Nul lorsque ce Patient est un "proche" géré par un titulaire sans
    # compte de connexion propre.
    utilisateur = models.ForeignKey(
        Utilisateur,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="patients",
    )
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    supprime_le = models.DateTimeField(null=True, blank=True)

    class Meta:
        verbose_name = "Patient"
        verbose_name_plural = "Patients"

    def __str__(self):
        return f"{self.nom} {self.prenoms} ({self.numero_sante})"


class LienProche(models.Model):
    """Lien de gestion d'un patient "proche" par un titulaire.

    RG-24 : un titulaire peut gérer au maximum
    `settings.MAX_PROCHES_PAR_TITULAIRE` proches (10 par défaut).
    """

    ENFANT = "enfant"
    PARENT = "parent"
    CONJOINT = "conjoint"
    AUTRE = "autre"
    LIEN_CHOICES = [
        (ENFANT, "Enfant"),
        (PARENT, "Parent"),
        (CONJOINT, "Conjoint"),
        (AUTRE, "Autre"),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    titulaire = models.ForeignKey(
        Patient, on_delete=models.CASCADE, related_name="proches_geres"
    )
    patient = models.ForeignKey(
        Patient, on_delete=models.CASCADE, related_name="geres_par"
    )
    lien = models.CharField(max_length=20, choices=LIEN_CHOICES)
    droits = models.CharField(
        max_length=255,
        default="gestion_complete",
        help_text="Ex : gestion_complete, prise_rdv_uniquement",
    )
    cree_le = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("titulaire", "patient")
        verbose_name = "Lien proche"
        verbose_name_plural = "Liens proches"

    def clean(self):
        if self.titulaire_id == self.patient_id:
            raise ValidationError("Un titulaire ne peut pas être son propre proche.")
        # RG-24 : max MAX_PROCHES_PAR_TITULAIRE proches par titulaire.
        from django.conf import settings

        max_proches = getattr(settings, "MAX_PROCHES_PAR_TITULAIRE", 10)
        qs = LienProche.objects.filter(titulaire=self.titulaire)
        if self.pk:
            qs = qs.exclude(pk=self.pk)
        if qs.count() >= max_proches:
            raise ValidationError(
                f"RG-24 : un titulaire ne peut pas gérer plus de {max_proches} proches."
            )

    def save(self, *args, **kwargs):
        self.full_clean()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.titulaire} -> {self.patient} ({self.lien})"


def _generer_code_six_chiffres():
    return f"{random.randint(0, 999999):06d}"


class CodeSMS(models.Model):
    """Code de connexion à usage unique envoyé par SMS.

    Règles implémentées (cf. user stories patient M1/M2) :
    - validité `settings.SMS_CODE_EXPIRY_MINUTES` minutes (5 par défaut)
    - `settings.SMS_CODE_MAX_ATTEMPTS` tentatives maximum (3 par défaut)
    - usage unique (consumed=True après vérification réussie)
    - jamais stocké en clair : seul le hash du code est conservé.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    telephone = models.CharField(max_length=20, validators=[TELEPHONE_REGEX])
    code_hash = models.CharField(max_length=128)
    cree_le = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    consumed = models.BooleanField(default=False)

    class Meta:
        verbose_name = "Code SMS"
        verbose_name_plural = "Codes SMS"
        indexes = [models.Index(fields=["telephone", "consumed"])]

    def __str__(self):
        etat = "utilisé" if self.consumed else "actif"
        return f"Code SMS pour {self.telephone} ({etat})"

    @classmethod
    def generer(cls, telephone, duree_minutes):
        code = _generer_code_six_chiffres()
        instance = cls.objects.create(
            telephone=telephone,
            code_hash=make_password(code),
            expires_at=timezone.now() + timezone.timedelta(minutes=duree_minutes),
        )
        return instance, code

    def est_expire(self):
        return timezone.now() >= self.expires_at

    def verifier(self, code, max_attempts):
        """Retourne True si `code` correspond, sans dépasser max_attempts.

        Incrémente systématiquement le compteur de tentatives et marque
        le code comme consommé en cas de succès ou de dépassement du
        nombre d'essais.
        """
        if self.consumed or self.est_expire() or self.attempts >= max_attempts:
            return False
        self.attempts += 1
        valide = check_password(code, self.code_hash)
        if valide:
            self.consumed = True
        self.save(update_fields=["attempts", "consumed"])
        return valide
