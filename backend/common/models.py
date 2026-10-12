"""Abstractions partagées entre les apps directory / accounts / scheduling.

Convention du cahier des charges : identifiants UUID partout, horodatage
cree_le / modifie_le, et suppression logique (soft delete) via
supprime_le plutôt qu'un vrai DELETE SQL.
"""

import uuid

from django.db import models
from django.utils import timezone


class BaseModelQuerySet(models.QuerySet):
    def actifs(self):
        """Exclut les enregistrements supprimés (soft delete)."""
        return self.filter(supprime_le__isnull=True)


class BaseModelManager(models.Manager):
    """Manager par défaut : ne renvoie que les lignes non supprimées."""

    def get_queryset(self):
        return BaseModelQuerySet(self.model, using=self._db).filter(
            supprime_le__isnull=True
        )


class BaseModel(models.Model):
    """Modèle de base : UUID PK, horodatage, soft delete.

    objects : uniquement les lignes actives (non supprimées).
    tous_les_objets : toutes les lignes, y compris supprimées.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    cree_le = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True)
    supprime_le = models.DateTimeField(null=True, blank=True)

    objects = BaseModelManager()
    tous_les_objets = models.Manager()

    class Meta:
        abstract = True

    def supprimer(self):
        """Suppression logique (soft delete)."""
        self.supprime_le = timezone.now()
        self.save(update_fields=["supprime_le"])

    @property
    def est_supprime(self):
        return self.supprime_le is not None
