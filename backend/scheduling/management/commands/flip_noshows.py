"""Commande de gestion : bascule automatiquement en "absent" les
rendez-vous réservés dont le créneau a débuté depuis plus de
settings.DELAI_NO_SHOW_MINUTES minutes sans passage en "arrivé" (RG-12).

Cette commande est prévue pour être exécutée périodiquement (par
exemple toutes les 10 minutes) via une tâche planifiée du système
d'exploitation. Dans ce sandbox, aucun scheduler n'est configuré ; en
production on l'ajouterait par exemple à la crontab du conteneur
applicatif :

    */10 * * * * cd /app/backend && venv/bin/python manage.py flip_noshows

ou, en environnement Docker/Kubernetes, via un CronJob dédié exécutant
`python manage.py flip_noshows`.

Usage :
    python manage.py flip_noshows
"""

from django.core.management.base import BaseCommand

from scheduling.services import flip_noshows


class Command(BaseCommand):
    help = 'Bascule en "absent" les rendez-vous non honorés 30 min après leur début (RG-12).'

    def handle(self, *args, **options):
        nb = flip_noshows()
        self.stdout.write(self.style.SUCCESS(f"{nb} rendez-vous basculés en 'absent'."))
