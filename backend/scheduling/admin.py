from django.contrib import admin

from .models import (
    Creneau,
    Indisponibilite,
    ListeAttente,
    PlageHoraire,
    RendezVous,
    TypeConsultation,
)


@admin.register(TypeConsultation)
class TypeConsultationAdmin(admin.ModelAdmin):
    list_display = ("libelle", "exercice", "duree_min", "tarif_gnf", "reservable_en_ligne")
    list_filter = ("reservable_en_ligne",)


@admin.register(PlageHoraire)
class PlageHoraireAdmin(admin.ModelAdmin):
    list_display = ("exercice", "jour_semaine", "heure_debut", "heure_fin", "part_en_ligne")
    list_filter = ("jour_semaine",)


@admin.register(Indisponibilite)
class IndisponibiliteAdmin(admin.ModelAdmin):
    list_display = ("praticien", "debut", "fin", "motif")
    search_fields = ("praticien__nom", "praticien__prenoms")


@admin.register(Creneau)
class CreneauAdmin(admin.ModelAdmin):
    list_display = ("exercice", "debut", "fin", "statut", "en_ligne", "verrou_expire_le")
    list_filter = ("statut", "en_ligne")
    search_fields = ("exercice__praticien__nom", "exercice__etablissement__nom")


@admin.register(RendezVous)
class RendezVousAdmin(admin.ModelAdmin):
    list_display = ("patient", "exercice", "creneau", "statut", "canal", "cree_le")
    list_filter = ("statut", "canal")
    search_fields = ("patient__nom", "patient__prenoms", "patient__numero_sante")


@admin.register(ListeAttente)
class ListeAttenteAdmin(admin.ModelAdmin):
    list_display = ("patient", "exercice", "date_souhaitee", "statut")
    list_filter = ("statut",)
