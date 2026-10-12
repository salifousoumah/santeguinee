from rest_framework.routers import DefaultRouter

from django.urls import include, path

from .views import (
    AnnulerRendezVousView,
    ConfirmerRendezVousView,
    CreneauListView,
    ListeAttenteViewSet,
    MesRendezVousView,
    VerrouillerCreneauView,
)

app_name = "scheduling"

router = DefaultRouter()
router.register("listes-attente", ListeAttenteViewSet, basename="liste-attente")

urlpatterns = [
    path("creneaux/", CreneauListView.as_view(), name="creneaux-list"),
    path(
        "creneaux/<uuid:creneau_id>/verrouiller/",
        VerrouillerCreneauView.as_view(),
        name="creneau-verrouiller",
    ),
    path("rendez-vous/confirmer/", ConfirmerRendezVousView.as_view(), name="rdv-confirmer"),
    path("rendez-vous/mes-rendez-vous/", MesRendezVousView.as_view(), name="rdv-mes-rdv"),
    path(
        "rendez-vous/<uuid:rdv_id>/annuler/",
        AnnulerRendezVousView.as_view(),
        name="rdv-annuler",
    ),
    path("", include(router.urls)),
]
