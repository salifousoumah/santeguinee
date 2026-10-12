"""Commande de gestion : génère les Creneau concrets à partir des
PlageHoraire existantes (RG-05).

Usage :
    python manage.py generer_creneaux [--jours 60] [--exercice <uuid>]
"""

from django.core.management.base import BaseCommand

from directory.models import Exercice
from scheduling.services import generer_creneaux


class Command(BaseCommand):
    help = "Génère les créneaux (Creneau) à partir des plages horaires (RG-05)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--jours",
            type=int,
            default=None,
            help="Taille de la fenêtre de génération en jours (14-90, défaut settings.SLOT_GENERATION_WINDOW_DAYS).",
        )
        parser.add_argument(
            "--exercice",
            type=str,
            default=None,
            help="UUID d'un Exercice précis ; sinon tous les exercices actifs.",
        )

    def handle(self, *args, **options):
        jours = options["jours"]
        exercice_id = options["exercice"]

        if exercice_id:
            exercices = Exercice.objects.filter(pk=exercice_id)
        else:
            exercices = Exercice.objects.filter(actif=True)

        total = 0
        for exercice in exercices:
            crees = generer_creneaux(exercice, jours=jours)
            total += len(crees)
            if crees:
                self.stdout.write(f"{exercice} : {len(crees)} créneaux créés")

        self.stdout.write(self.style.SUCCESS(f"Terminé : {total} créneaux créés au total."))
