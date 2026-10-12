from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import CodeSMS, LienProche, Patient, Role, Utilisateur


@admin.register(Utilisateur)
class UtilisateurAdmin(UserAdmin):
    model = Utilisateur
    list_display = ("telephone", "email", "statut", "is_staff", "derniere_connexion")
    list_filter = ("statut", "is_staff")
    search_fields = ("telephone", "email")
    ordering = ("telephone",)
    fieldsets = (
        (None, {"fields": ("telephone", "password")}),
        ("Informations", {"fields": ("email", "langue", "statut", "derniere_connexion")}),
        (
            "Permissions",
            {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")},
        ),
    )
    add_fieldsets = (
        (None, {"fields": ("telephone", "password1", "password2")}),
    )


@admin.register(Role)
class RoleAdmin(admin.ModelAdmin):
    list_display = ("utilisateur", "role", "etablissement")
    list_filter = ("role",)
    search_fields = ("utilisateur__telephone",)


@admin.register(Patient)
class PatientAdmin(admin.ModelAdmin):
    list_display = ("numero_sante", "nom", "prenoms", "sexe", "telephone", "quartier")
    search_fields = ("numero_sante", "nom", "prenoms", "telephone")
    list_filter = ("sexe", "quartier")


@admin.register(LienProche)
class LienProcheAdmin(admin.ModelAdmin):
    list_display = ("titulaire", "patient", "lien")
    list_filter = ("lien",)


@admin.register(CodeSMS)
class CodeSMSAdmin(admin.ModelAdmin):
    list_display = ("telephone", "expires_at", "attempts", "consumed", "cree_le")
    list_filter = ("consumed",)
    search_fields = ("telephone",)
