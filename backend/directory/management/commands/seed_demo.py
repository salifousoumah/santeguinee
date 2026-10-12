"""Commande de gestion : crée des données de démonstration FICTIVES
pour Conakry.

Exigence de sécurité (pas seulement une convention de style) : tous
les noms d'établissements et de praticiens créés ici portent le
suffixe/préfixe "(Démo)" afin de ne jamais être confondus avec de
vraies informations sur de vrais hôpitaux/praticiens de Conakry. Cette
convention était déjà appliquée par la session précédente et doit être
conservée pour tout nouveau jeu de données de démonstration.

Usage :
    python manage.py seed_demo [--reset]
"""

import datetime

from django.core.management.base import BaseCommand
from django.db import transaction
from django.utils import timezone

from accounts.models import Patient
from directory.models import (
    Etablissement,
    Exercice,
    Horaire,
    Praticien,
    Service,
    Specialite,
    Zone,
)
from scheduling.models import PlageHoraire, TypeConsultation
from scheduling.services import generer_creneaux


class Command(BaseCommand):
    help = "Crée un jeu de données de démonstration fictif (Conakry) pour l'annuaire et la prise de RDV."

    def add_arguments(self, parser):
        parser.add_argument(
            "--reset",
            action="store_true",
            help="Supprime les anciennes données de démonstration avant d'en recréer.",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        if options["reset"]:
            self._nettoyer()

        zones = self._creer_zones()
        specialites = self._creer_specialites()
        etablissements = self._creer_etablissements(zones)
        praticiens = self._creer_praticiens(specialites)
        exercices = self._creer_exercices(praticiens, etablissements)
        self._creer_plages_et_generer_creneaux(exercices)
        self._creer_patients_demo(zones)

        self.stdout.write(
            self.style.SUCCESS(
                "Jeu de données de démonstration créé : "
                f"{len(zones)} zones, {len(specialites)} spécialités, "
                f"{len(etablissements)} établissements, {len(praticiens)} praticiens."
            )
        )

    def _nettoyer(self):
        Etablissement.tous_les_objets.filter(nom__icontains="(Démo)").delete()
        Praticien.tous_les_objets.filter(nom__icontains="(Démo)").delete()
        Patient.objects.filter(nom__icontains="(Démo)").delete()

    def _creer_zones(self):
        conakry, _ = Zone.objects.get_or_create(
            type=Zone.COMMUNE_SOUS_PREFECTURE, nom="Conakry", parent=None
        )
        noms_communes = ["Kaloum", "Dixinn", "Matam", "Matoto", "Ratoma"]
        zones = {"Conakry": conakry}
        for nom in noms_communes:
            commune, _ = Zone.objects.get_or_create(
                type=Zone.COMMUNE_SOUS_PREFECTURE, nom=nom, parent=conakry
            )
            zones[nom] = commune
            for quartier_nom in [f"{nom} Centre", f"{nom} Nord"]:
                quartier, _ = Zone.objects.get_or_create(
                    type=Zone.QUARTIER_DISTRICT, nom=quartier_nom, parent=commune
                )
                zones[quartier_nom] = quartier
        return zones

    def _creer_specialites(self):
        data = [
            ("MED_GEN", "Médecine générale", "médecin généraliste", "stethoscope"),
            ("PEDIATRIE", "Pédiatrie", "médecin des enfants", "baby"),
            ("GYNECO", "Gynécologie-obstétrique", "médecin des femmes / grossesse", "heart"),
            ("CARDIO", "Cardiologie", "médecin du cœur", "heart-pulse"),
            ("DENTAIRE", "Chirurgie dentaire", "dentiste", "tooth"),
            ("DERMATO", "Dermatologie", "médecin de la peau", "hand"),
            ("OPHTALMO", "Ophtalmologie", "médecin des yeux", "eye"),
            ("LABO", "Analyses de laboratoire", "laboratoire d'analyses", "flask"),
        ]
        specialites = {}
        for code, libelle, grand_public, icone in data:
            specialite, _ = Specialite.objects.get_or_create(
                code=code,
                defaults={
                    "libelle": libelle,
                    "libelle_grand_public": grand_public,
                    "icone": icone,
                },
            )
            specialites[code] = specialite
        return specialites

    def _creer_etablissements(self, zones):
        data = [
            (
                "Hôpital National Donka (Démo)",
                Etablissement.CHU,
                Etablissement.PUBLIC,
                9.5370,
                -13.6785,
                "Kaloum Centre",
                True,
            ),
            (
                "Clinique Pasteur (Démo)",
                Etablissement.CLINIQUE,
                Etablissement.PRIVE,
                9.5450,
                -13.6600,
                "Dixinn Centre",
                True,
            ),
            (
                "Centre de Santé de Matam (Démo)",
                Etablissement.CENTRE_SANTE,
                Etablissement.PUBLIC,
                9.5200,
                -13.6700,
                "Matam Centre",
                False,
            ),
            (
                "Cabinet Médical Ratoma (Démo)",
                Etablissement.CABINET,
                Etablissement.PRIVE,
                9.5800,
                -13.6450,
                "Ratoma Centre",
                False,
            ),
            (
                "Polyclinique Les Palmiers (Démo)",
                Etablissement.CLINIQUE,
                Etablissement.PRIVE,
                9.5600,
                -13.6300,
                "Matoto Centre",
                True,
            ),
            (
                "Pharmacie Nongo (Démo)",
                Etablissement.PHARMACIE,
                Etablissement.PRIVE,
                9.5900,
                -13.6200,
                "Ratoma Nord",
                False,
            ),
            (
                "Poste de Santé Boulbinet (Démo)",
                Etablissement.POSTE_SANTE,
                Etablissement.CONFESSIONNEL,
                9.5100,
                -13.6900,
                "Kaloum Centre",
                False,
            ),
            (
                "Laboratoire BioGuinée (Démo)",
                Etablissement.LABORATOIRE,
                Etablissement.PRIVE,
                9.5350,
                -13.6550,
                "Dixinn Nord",
                False,
            ),
        ]
        etablissements = []
        for nom, type_, secteur, lat, lon, quartier_nom, urgences in data:
            etab, _ = Etablissement.objects.get_or_create(
                nom=nom,
                defaults={
                    "type": type_,
                    "secteur": secteur,
                    "latitude": lat,
                    "longitude": lon,
                    "quartier": zones.get(quartier_nom),
                    "telephones": "+224600000001,+224600000002",
                    "urgences_24h": urgences,
                    "moyens_paiement": "especes,mobile_money",
                    "statut_verification": Etablissement.VERIFIE,
                    "verifie_le": timezone.now(),
                },
            )
            etablissements.append(etab)
            # Un service générique "Consultations externes" par établissement
            Service.objects.get_or_create(
                etablissement=etab,
                nom="Consultations externes",
                defaults={"telephone": "+224600000003"},
            )
            # Horaires standards lundi-vendredi 08:00-17:00, samedi 08:00-13:00
            for jour in range(5):
                Horaire.objects.get_or_create(
                    etablissement=etab,
                    jour_semaine=jour,
                    heure_debut=datetime.time(8, 0),
                    heure_fin=datetime.time(17, 0),
                )
            Horaire.objects.get_or_create(
                etablissement=etab,
                jour_semaine=5,
                heure_debut=datetime.time(8, 0),
                heure_fin=datetime.time(13, 0),
            )
        return etablissements

    def _creer_praticiens(self, specialites):
        data = [
            ("Camara (Démo)", "Mamadou", "Dr", Praticien.MEDECIN, ["MED_GEN"]),
            ("Diallo (Démo)", "Fatoumata", "Dr", Praticien.MEDECIN, ["PEDIATRIE"]),
            ("Bah (Démo)", "Aissatou", "Dr", Praticien.MEDECIN, ["GYNECO"]),
            ("Keita (Démo)", "Sékou", "Dr", Praticien.MEDECIN, ["CARDIO"]),
            ("Touré (Démo)", "Mariam", "Dr", Praticien.DENTISTE, ["DENTAIRE"]),
            ("Condé (Démo)", "Ibrahima", "Dr", Praticien.MEDECIN, ["DERMATO"]),
            ("Soumah (Démo)", "Aminata", "Dr", Praticien.MEDECIN, ["OPHTALMO"]),
            ("Barry (Démo)", "Hadja", "Mme", Praticien.SAGE_FEMME, ["GYNECO"]),
            ("Sylla (Démo)", "Ousmane", "M.", Praticien.INFIRMIER, ["MED_GEN"]),
            ("Cissé (Démo)", "Kadiatou", "Dr", Praticien.MEDECIN, ["LABO"]),
        ]
        praticiens = []
        for nom, prenoms, civilite, profession, codes_specialites in data:
            praticien, _ = Praticien.objects.get_or_create(
                nom=nom,
                prenoms=prenoms,
                defaults={
                    "civilite": civilite,
                    "profession": profession,
                    "numero_ordre": f"GN-{len(praticiens) + 1:04d}",
                    "langues": "français,soussou",
                    "presentation": "Praticien fictif de démonstration.",
                    "statut_verification": Praticien.VERIFIE,
                    "verifie_le": timezone.now(),
                },
            )
            praticien.specialites.set(
                [specialites[code] for code in codes_specialites]
            )
            praticiens.append(praticien)
        return praticiens

    def _creer_exercices(self, praticiens, etablissements):
        exercices = []
        for i, praticien in enumerate(praticiens):
            etab = etablissements[i % len(etablissements)]
            exercice, _ = Exercice.objects.get_or_create(
                praticien=praticien,
                etablissement=etab,
                service=None,
                defaults={"tarif_indicatif_gnf": 50000 + (i * 5000), "actif": True},
            )
            exercices.append(exercice)
            # Certains praticiens exercent dans un deuxième établissement
            if i % 3 == 0:
                etab2 = etablissements[(i + 2) % len(etablissements)]
                exercice2, _ = Exercice.objects.get_or_create(
                    praticien=praticien,
                    etablissement=etab2,
                    service=None,
                    defaults={"tarif_indicatif_gnf": 60000, "actif": True},
                )
                exercices.append(exercice2)
        return exercices

    def _creer_plages_et_generer_creneaux(self, exercices):
        for exercice in exercices:
            type_consult, _ = TypeConsultation.objects.get_or_create(
                exercice=exercice,
                libelle="Consultation standard",
                defaults={
                    "duree_min": 30,
                    "tarif_gnf": exercice.tarif_indicatif_gnf or 50000,
                    "reservable_en_ligne": True,
                    "acompte_gnf": 0,
                },
            )
            for jour in [0, 1, 2, 3, 4]:  # Lundi à vendredi
                plage, _ = PlageHoraire.objects.get_or_create(
                    exercice=exercice,
                    jour_semaine=jour,
                    heure_debut=datetime.time(9, 0),
                    heure_fin=datetime.time(12, 0),
                    defaults={"part_en_ligne": 80},
                )
                plage.types_autorises.add(type_consult)
            generer_creneaux(exercice, jours=14)

    def _creer_patients_demo(self, zones):
        data = [
            ("Doumbouya (Démo)", "Aissata", Patient.SEXE_FEMME, "+224620000001"),
            ("Fofana (Démo)", "Lamine", Patient.SEXE_HOMME, "+224620000002"),
            ("Kourouma (Démo)", "Nana", Patient.SEXE_FEMME, "+224620000003"),
        ]
        patients = []
        for nom, prenoms, sexe, telephone in data:
            patient, _ = Patient.objects.get_or_create(
                nom=nom,
                prenoms=prenoms,
                defaults={
                    "sexe": sexe,
                    "telephone": telephone,
                    "quartier": zones.get("Kaloum Centre"),
                },
            )
            patients.append(patient)
        return patients
