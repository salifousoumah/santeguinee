"""Back-office M3 : administration de l'annuaire.

Pour cette passe MVP, l'admin Django EST le back-office (cf. cahier des
charges module M3) : c'est ici qu'une personne non technique peut
vérifier/valider les établissements et praticiens soumis.
"""

from django.contrib import admin

from .models import (
    Etablissement,
    Exercice,
    Garde,
    Horaire,
    Praticien,
    Service,
    Signalement,
    Specialite,
    Zone,
)


@admin.action(description="Marquer comme vérifié")
def marquer_verifie(modeladmin, request, queryset):
    from django.utils import timezone

    queryset.update(statut_verification="verifie", verifie_le=timezone.now())


@admin.action(description="Marquer comme rejeté")
def marquer_rejete(modeladmin, request, queryset):
    queryset.update(statut_verification="rejete")


@admin.register(Zone)
class ZoneAdmin(admin.ModelAdmin):
    list_display = ("nom", "type", "parent")
    list_filter = ("type",)
    search_fields = ("nom",)


@admin.register(Specialite)
class SpecialiteAdmin(admin.ModelAdmin):
    list_display = ("libelle", "libelle_grand_public", "code")
    search_fields = ("libelle", "libelle_grand_public", "code")


class ServiceInline(admin.TabularInline):
    model = Service
    extra = 0


class ExerciceInline(admin.TabularInline):
    model = Exercice
    extra = 0


@admin.register(Etablissement)
class EtablissementAdmin(admin.ModelAdmin):
    list_display = (
        "nom",
        "type",
        "secteur",
        "quartier",
        "urgences_24h",
        "statut_verification",
        "verifie_le",
    )
    list_filter = ("type", "secteur", "statut_verification", "urgences_24h")
    search_fields = ("nom", "code_officiel", "repere")
    actions = [marquer_verifie, marquer_rejete]
    inlines = [ServiceInline, ExerciceInline]


@admin.register(Service)
class ServiceAdmin(admin.ModelAdmin):
    list_display = ("nom", "etablissement", "specialite", "telephone")
    list_filter = ("specialite",)
    search_fields = ("nom", "etablissement__nom")


@admin.register(Horaire)
class HoraireAdmin(admin.ModelAdmin):
    list_display = ("__str__", "jour_semaine", "heure_debut", "heure_fin", "exceptionnel")
    list_filter = ("jour_semaine",)


@admin.register(Garde)
class GardeAdmin(admin.ModelAdmin):
    list_display = ("etablissement", "service", "debut", "fin")
    list_filter = ("etablissement",)


@admin.register(Praticien)
class PraticienAdmin(admin.ModelAdmin):
    list_display = (
        "nom",
        "prenoms",
        "profession",
        "numero_ordre",
        "statut_verification",
        "verifie_le",
    )
    list_filter = ("profession", "statut_verification")
    search_fields = ("nom", "prenoms", "numero_ordre")
    filter_horizontal = ("specialites",)
    actions = [marquer_verifie, marquer_rejete]
    inlines = [ExerciceInline]


@admin.register(Exercice)
class ExerciceAdmin(admin.ModelAdmin):
    list_display = ("praticien", "etablissement", "service", "tarif_indicatif_gnf", "actif")
    list_filter = ("actif", "etablissement")
    search_fields = ("praticien__nom", "praticien__prenoms", "etablissement__nom")


@admin.register(Signalement)
class SignalementAdmin(admin.ModelAdmin):
    list_display = ("__str__", "statut", "traite_par", "cree_le")
    list_filter = ("statut",)
    search_fields = ("description",)
