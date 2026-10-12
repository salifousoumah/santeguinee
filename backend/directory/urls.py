from django.urls import path

from .views import EtablissementSearchView, PraticienSearchView

app_name = "directory"

urlpatterns = [
    path("etablissements/", EtablissementSearchView.as_view(), name="etablissements-search"),
    path("praticiens/", PraticienSearchView.as_view(), name="praticiens-search"),
]
